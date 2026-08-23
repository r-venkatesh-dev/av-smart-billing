alter table public.plans
  add column if not exists allow_online_billing boolean not null default true,
  add column if not exists allow_cloud_backup boolean not null default true;

alter table public.licenses
  add column if not exists allow_online_billing boolean not null default true,
  add column if not exists allow_cloud_backup boolean not null default true;

comment on column public.plans.allow_online_billing is
  'Whether licenses issued from this plan may use server-backed online billing.';
comment on column public.plans.allow_cloud_backup is
  'Whether licenses issued from this plan may upload or restore cloud backups.';
comment on column public.licenses.allow_online_billing is
  'Snapshot of the online billing entitlement when this license was issued.';
comment on column public.licenses.allow_cloud_backup is
  'Snapshot of the cloud backup entitlement when this license was issued.';

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
  select * into purchase from public.subscription_orders
  where id = p_subscription_order_id for update;

  if not found then raise exception 'Subscription order not found'; end if;
  if purchase.razorpay_order_id is distinct from p_razorpay_order_id then raise exception 'Razorpay order mismatch'; end if;
  if purchase.status = 'PAID' then
    return query select purchase.customer_id, purchase.license_id, true;
    return;
  end if;
  if purchase.status not in ('PAYMENT_PENDING', 'PAYMENT_CAPTURED') then raise exception 'Subscription order is not payable'; end if;

  select * into selected_plan from public.plans where id = purchase.plan_id and status = 'ACTIVE';
  if not found then raise exception 'Selected plan is no longer active'; end if;

  perform pg_advisory_xact_lock(hashtextextended(lower(purchase.email), 0));
  select id into resolved_customer_id from public.customers
  where lower(email) = lower(purchase.email) order by created_at limit 1 for update;

  if resolved_customer_id is null then
    insert into public.customers (company_name, contact_person, email, phone, address, gstin)
    values (purchase.company_name, purchase.contact_person, lower(purchase.email), purchase.phone, purchase.address, purchase.gstin)
    returning id into resolved_customer_id;
  else
    update public.customers set company_name = purchase.company_name,
      contact_person = purchase.contact_person, phone = purchase.phone,
      address = purchase.address, gstin = purchase.gstin, status = 'ACTIVE'
    where id = resolved_customer_id;
  end if;

  insert into public.licenses (
    customer_id, plan_id, license_key_hash, license_key_hint,
    max_devices, validation_window_days, allow_online_billing,
    allow_cloud_backup, status, expires_at, created_by
  ) values (
    resolved_customer_id, purchase.plan_id, p_license_key_hash, p_license_key_hint,
    selected_plan.max_devices, selected_plan.validation_window_days,
    selected_plan.allow_online_billing, selected_plan.allow_cloud_backup,
    'ACTIVE', p_expires_at, p_created_by
  ) returning id into resolved_license_id;

  insert into public.subscription_payment_attempts (
    subscription_order_id, razorpay_order_id, razorpay_payment_id, status, amount_in_paise, currency
  ) values (
    purchase.id, p_razorpay_order_id, p_razorpay_payment_id, 'CAPTURED', purchase.amount_in_paise, purchase.currency
  ) on conflict (razorpay_payment_id) do update set status = 'CAPTURED', updated_at = now();

  update public.subscription_orders set customer_id = resolved_customer_id,
    license_id = resolved_license_id, latest_razorpay_payment_id = p_razorpay_payment_id,
    status = 'PAID', paid_at = now(), failure_code = null, failure_description = null
  where id = purchase.id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (p_created_by, 'SUBSCRIPTION_PURCHASE_COMPLETED', 'license', resolved_license_id,
    jsonb_build_object('subscription_order_id', purchase.id, 'razorpay_order_id', p_razorpay_order_id));

  return query select resolved_customer_id, resolved_license_id, false;
end;
$$;

revoke all on function public.finalize_subscription_purchase(uuid, text, text, text, text, timestamptz, uuid) from public, anon, authenticated;
grant execute on function public.finalize_subscription_purchase(uuid, text, text, text, text, timestamptz, uuid) to service_role;
