alter table public.subscription_orders
  drop constraint if exists subscription_orders_amount_in_paise_check;

alter table public.subscription_orders
  add constraint subscription_orders_amount_in_paise_check
  check (amount_in_paise >= 0);

create or replace function public.finalize_free_subscription(
  p_subscription_order_id uuid,
  p_license_key_hash text,
  p_license_key_hint text,
  p_license_key_ciphertext text,
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
  if purchase.amount_in_paise <> 0 then raise exception 'Selected subscription is not free'; end if;
  if purchase.razorpay_order_id is not null or purchase.latest_razorpay_payment_id is not null then
    raise exception 'Free subscription cannot have Razorpay references';
  end if;
  if purchase.status = 'PAID' then
    return query select purchase.customer_id, purchase.license_id, true;
    return;
  end if;
  if purchase.status <> 'CREATED' then raise exception 'Free subscription cannot be completed'; end if;

  select * into selected_plan from public.plans
  where id = purchase.plan_id and status = 'ACTIVE' and price_in_paise = 0;
  if not found then raise exception 'Selected free plan is no longer active'; end if;

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
    customer_id, plan_id, license_key_hash, license_key_hint, license_key_ciphertext,
    max_devices, validation_window_days, allow_online_billing,
    allow_cloud_backup, allow_reports_exports, status, expires_at, created_by
  ) values (
    resolved_customer_id, purchase.plan_id, p_license_key_hash, p_license_key_hint, p_license_key_ciphertext,
    selected_plan.max_devices, selected_plan.validation_window_days,
    selected_plan.allow_online_billing, selected_plan.allow_cloud_backup,
    selected_plan.allow_reports_exports, 'ACTIVE', p_expires_at, p_created_by
  ) returning id into resolved_license_id;

  update public.subscription_orders set customer_id = resolved_customer_id,
    license_id = resolved_license_id, status = 'PAID', paid_at = now(),
    failure_code = null, failure_description = null
  where id = purchase.id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (p_created_by, 'FREE_SUBSCRIPTION_COMPLETED', 'license', resolved_license_id,
    jsonb_build_object('subscription_order_id', purchase.id, 'free_plan', true));

  return query select resolved_customer_id, resolved_license_id, false;
end;
$$;

revoke all on function public.finalize_free_subscription(uuid, text, text, text, timestamptz, uuid) from public, anon, authenticated;
grant execute on function public.finalize_free_subscription(uuid, text, text, text, timestamptz, uuid) to service_role;

notify pgrst, 'reload schema';
