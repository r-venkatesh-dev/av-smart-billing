create or replace function public.activate_license(
  p_license_key_hash text,
  p_fingerprint_hash text,
  p_fingerprint_hint text,
  p_device_name text,
  p_ip_address inet default null,
  p_user_agent text default null
) returns table (
  license_id uuid, device_id uuid, customer_name text, plan_name text,
  expires_at timestamptz, validation_window_days integer, max_devices integer
)
language plpgsql security definer set search_path = '' as $$
declare
  v_license public.licenses;
  v_customer public.customers;
  v_plan public.plans;
  v_device public.devices;
  v_active_count integer;
begin
  select * into v_license from public.licenses where license_key_hash = p_license_key_hash for update;
  if not found then raise exception using message = 'Invalid license key', errcode = 'P0001'; end if;

  select * into v_customer from public.customers where id = v_license.customer_id;
  select * into v_plan from public.plans where id = v_license.plan_id;

  if v_license.expires_at <= now() and v_license.status = 'ACTIVE' then
    update public.licenses set status = 'EXPIRED' where id = v_license.id;
    v_license.status := 'EXPIRED';
  end if;
  if v_customer.status <> 'ACTIVE' then
    insert into public.license_activations (license_id, event, success, failure_code, ip_address, user_agent) values (v_license.id, 'REJECTED', false, 'CUSTOMER_INACTIVE', p_ip_address, p_user_agent);
    raise exception using message = 'Customer account is inactive', errcode = 'P0001';
  end if;
  if v_plan.status <> 'ACTIVE' then
    insert into public.license_activations (license_id, event, success, failure_code, ip_address, user_agent) values (v_license.id, 'REJECTED', false, 'PLAN_INACTIVE', p_ip_address, p_user_agent);
    raise exception using message = 'License plan is inactive', errcode = 'P0001';
  end if;
  if v_license.status <> 'ACTIVE' then
    insert into public.license_activations (license_id, event, success, failure_code, ip_address, user_agent) values (v_license.id, 'REJECTED', false, 'LICENSE_' || v_license.status::text, p_ip_address, p_user_agent);
    raise exception using message = 'License is ' || lower(v_license.status::text), errcode = 'P0001';
  end if;

  select * into v_device from public.devices d where d.license_id = v_license.id and d.fingerprint_hash = p_fingerprint_hash and d.status = 'ACTIVE' limit 1 for update;
  if found then
    update public.devices set device_name = p_device_name, last_validated_at = now() where id = v_device.id returning * into v_device;
  else
    select count(*) into v_active_count from public.devices d where d.license_id = v_license.id and d.status = 'ACTIVE';
    if v_active_count >= v_license.max_devices then
      insert into public.license_activations (license_id, event, success, failure_code, ip_address, user_agent, metadata) values (v_license.id, 'REJECTED', false, 'DEVICE_LIMIT_REACHED', p_ip_address, p_user_agent, jsonb_build_object('device_name', p_device_name));
      raise exception using message = 'Device limit reached. Ask the administrator to deactivate an old device.', errcode = 'P0001';
    end if;
    select * into v_device from public.devices d where d.license_id = v_license.id and d.fingerprint_hash = p_fingerprint_hash and d.status = 'DEACTIVATED' order by d.created_at desc limit 1 for update;
    if found then
      update public.devices set status = 'ACTIVE', device_name = p_device_name, fingerprint_hint = p_fingerprint_hint, activated_at = now(), last_validated_at = now(), deactivated_at = null where id = v_device.id returning * into v_device;
    else
      insert into public.devices (license_id, fingerprint_hash, fingerprint_hint, device_name) values (v_license.id, p_fingerprint_hash, p_fingerprint_hint, p_device_name) returning * into v_device;
    end if;
  end if;

  update public.licenses set last_validated_at = now() where id = v_license.id;
  insert into public.license_activations (license_id, device_id, event, success, ip_address, user_agent, metadata) values (v_license.id, v_device.id, 'ACTIVATED', true, p_ip_address, p_user_agent, jsonb_build_object('device_name', p_device_name));
  return query select v_license.id, v_device.id, v_customer.company_name, v_plan.name, v_license.expires_at, v_license.validation_window_days, v_license.max_devices;
end; $$;

create or replace function public.validate_license(
  p_device_id uuid,
  p_fingerprint_hash text,
  p_ip_address inet default null,
  p_user_agent text default null
) returns table (
  license_id uuid, device_id uuid, customer_name text, plan_name text,
  expires_at timestamptz, validation_window_days integer, max_devices integer
)
language plpgsql security definer set search_path = '' as $$
declare
  v_device public.devices;
  v_license public.licenses;
  v_customer public.customers;
  v_plan public.plans;
begin
  select * into v_device from public.devices where id = p_device_id for update;
  if not found or v_device.fingerprint_hash <> p_fingerprint_hash then raise exception using message = 'Device validation failed', errcode = 'P0001'; end if;
  select * into v_license from public.licenses where id = v_device.license_id for update;
  select * into v_customer from public.customers where id = v_license.customer_id;
  select * into v_plan from public.plans where id = v_license.plan_id;
  if v_license.expires_at <= now() and v_license.status = 'ACTIVE' then update public.licenses set status = 'EXPIRED' where id = v_license.id; v_license.status := 'EXPIRED'; end if;
  if v_device.status <> 'ACTIVE' or v_license.status <> 'ACTIVE' or v_customer.status <> 'ACTIVE' or v_plan.status <> 'ACTIVE' then
    insert into public.license_activations (license_id, device_id, event, success, failure_code, ip_address, user_agent) values (v_license.id, v_device.id, 'REJECTED', false, 'VALIDATION_BLOCKED', p_ip_address, p_user_agent);
    raise exception using message = 'License or device is no longer active', errcode = 'P0001';
  end if;
  update public.devices set last_validated_at = now() where id = v_device.id;
  update public.licenses set last_validated_at = now() where id = v_license.id;
  insert into public.license_activations (license_id, device_id, event, success, ip_address, user_agent) values (v_license.id, v_device.id, 'VALIDATED', true, p_ip_address, p_user_agent);
  return query select v_license.id, v_device.id, v_customer.company_name, v_plan.name, v_license.expires_at, v_license.validation_window_days, v_license.max_devices;
end; $$;

revoke all on function public.activate_license(text, text, text, text, inet, text) from public, anon, authenticated;
revoke all on function public.validate_license(uuid, text, inet, text) from public, anon, authenticated;
grant execute on function public.activate_license(text, text, text, text, inet, text) to service_role;
grant execute on function public.validate_license(uuid, text, inet, text) to service_role;
