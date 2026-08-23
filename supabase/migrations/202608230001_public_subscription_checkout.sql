create table public.subscription_orders (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans(id) on delete restrict,
  customer_id uuid references public.customers(id) on delete restrict,
  license_id uuid unique references public.licenses(id) on delete restrict,
  company_name text not null check (char_length(company_name) between 2 and 180),
  contact_person text not null check (char_length(contact_person) between 2 and 120),
  email text not null,
  phone text not null,
  address text not null,
  gstin text,
  plan_name text not null,
  amount_in_paise bigint not null check (amount_in_paise > 0),
  currency text not null default 'INR' check (currency = 'INR'),
  status text not null default 'CREATED' check (status in ('CREATED', 'PAYMENT_PENDING', 'PAYMENT_CAPTURED', 'PAID', 'FAILED', 'CANCELLED')),
  razorpay_order_id text unique,
  latest_razorpay_payment_id text,
  failure_code text,
  failure_description text,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint subscription_orders_email_format check (email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'),
  constraint subscription_orders_gstin_format check (gstin is null or gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
);

create table public.subscription_payment_attempts (
  id uuid primary key default gen_random_uuid(),
  subscription_order_id uuid not null references public.subscription_orders(id) on delete cascade,
  razorpay_order_id text,
  razorpay_payment_id text unique,
  status text not null check (status in ('CREATED', 'AUTHORIZED', 'CAPTURED', 'FAILED', 'CANCELLED')),
  amount_in_paise bigint not null check (amount_in_paise >= 0),
  currency text not null default 'INR',
  error_code text,
  error_description text,
  error_source text,
  error_step text,
  error_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.subscription_webhook_events (
  id uuid primary key default gen_random_uuid(),
  razorpay_event_id text not null unique,
  event_type text not null,
  processed boolean not null default false,
  processing_error text,
  received_at timestamptz not null default now(),
  processed_at timestamptz
);

create index subscription_orders_created_idx on public.subscription_orders(created_at desc);
create index subscription_orders_status_idx on public.subscription_orders(status, created_at desc);
create index subscription_orders_email_idx on public.subscription_orders(lower(email));
create index subscription_payment_order_idx on public.subscription_payment_attempts(subscription_order_id, created_at desc);

create trigger subscription_orders_set_updated_at before update on public.subscription_orders for each row execute function public.set_updated_at();
create trigger subscription_payment_attempts_set_updated_at before update on public.subscription_payment_attempts for each row execute function public.set_updated_at();

alter table public.subscription_orders enable row level security;
alter table public.subscription_payment_attempts enable row level security;
alter table public.subscription_webhook_events enable row level security;

create policy subscription_orders_admin_read on public.subscription_orders for select to authenticated using (public.is_active_admin());
create policy subscription_payment_attempts_admin_read on public.subscription_payment_attempts for select to authenticated using (public.is_active_admin());
create policy subscription_webhook_events_admin_read on public.subscription_webhook_events for select to authenticated using (public.is_active_admin(array['OWNER','ADMIN']::public.admin_role[]));

revoke all on public.subscription_orders, public.subscription_payment_attempts, public.subscription_webhook_events from anon;
grant select on public.subscription_orders, public.subscription_payment_attempts to authenticated;
grant select on public.subscription_webhook_events to authenticated;

create or replace function public.finalize_subscription_purchase(
  p_subscription_order_id uuid,
  p_razorpay_order_id text,
  p_razorpay_payment_id text,
  p_license_key_hash text,
  p_license_key_hint text,
  p_expires_at timestamptz,
  p_created_by uuid
)
returns table (customer_id uuid, license_id uuid, already_completed boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  purchase public.subscription_orders%rowtype;
  selected_plan public.plans%rowtype;
  resolved_customer_id uuid;
  resolved_license_id uuid;
begin
  select * into purchase
  from public.subscription_orders
  where id = p_subscription_order_id
  for update;

  if not found then raise exception 'Subscription order not found'; end if;
  if purchase.razorpay_order_id is distinct from p_razorpay_order_id then raise exception 'Razorpay order mismatch'; end if;

  if purchase.status = 'PAID' then
    return query select purchase.customer_id, purchase.license_id, true;
    return;
  end if;

  if purchase.status not in ('PAYMENT_PENDING', 'PAYMENT_CAPTURED') then
    raise exception 'Subscription order is not payable';
  end if;

  select * into selected_plan from public.plans where id = purchase.plan_id and status = 'ACTIVE';
  if not found then raise exception 'Selected plan is no longer active'; end if;

  -- Serialize purchases for the same email so simultaneous callbacks cannot
  -- create duplicate customer rows.
  perform pg_advisory_xact_lock(hashtextextended(lower(purchase.email), 0));

  select id into resolved_customer_id
  from public.customers
  where lower(email) = lower(purchase.email)
  order by created_at
  limit 1
  for update;

  if resolved_customer_id is null then
    insert into public.customers (company_name, contact_person, email, phone, address, gstin)
    values (purchase.company_name, purchase.contact_person, lower(purchase.email), purchase.phone, purchase.address, purchase.gstin)
    returning id into resolved_customer_id;
  else
    update public.customers
    set company_name = purchase.company_name,
        contact_person = purchase.contact_person,
        phone = purchase.phone,
        address = purchase.address,
        gstin = purchase.gstin,
        status = 'ACTIVE'
    where id = resolved_customer_id;
  end if;

  insert into public.licenses (
    customer_id, plan_id, license_key_hash, license_key_hint,
    max_devices, validation_window_days, status, expires_at, created_by
  ) values (
    resolved_customer_id, purchase.plan_id, p_license_key_hash, p_license_key_hint,
    selected_plan.max_devices, selected_plan.validation_window_days, 'ACTIVE', p_expires_at, p_created_by
  ) returning id into resolved_license_id;

  insert into public.subscription_payment_attempts (
    subscription_order_id, razorpay_order_id, razorpay_payment_id, status, amount_in_paise, currency
  ) values (
    purchase.id, p_razorpay_order_id, p_razorpay_payment_id, 'CAPTURED', purchase.amount_in_paise, purchase.currency
  )
  on conflict (razorpay_payment_id) do update set status = 'CAPTURED', updated_at = now();

  update public.subscription_orders
  set customer_id = resolved_customer_id,
      license_id = resolved_license_id,
      latest_razorpay_payment_id = p_razorpay_payment_id,
      status = 'PAID',
      paid_at = now(),
      failure_code = null,
      failure_description = null
  where id = purchase.id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (p_created_by, 'SUBSCRIPTION_PURCHASE_COMPLETED', 'license', resolved_license_id,
    jsonb_build_object('subscription_order_id', purchase.id, 'razorpay_order_id', p_razorpay_order_id));

  return query select resolved_customer_id, resolved_license_id, false;
end;
$$;

revoke all on function public.finalize_subscription_purchase(uuid, text, text, text, text, timestamptz, uuid) from public, anon, authenticated;
grant execute on function public.finalize_subscription_purchase(uuid, text, text, text, text, timestamptz, uuid) to service_role;
