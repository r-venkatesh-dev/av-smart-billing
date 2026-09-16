-- Migration: 202609160002_plan_entitlement_cascade.sql
-- Description: Synchronize existing licenses when their plan entitlements change,
--              and install a trigger to keep licenses synchronized automatically.

-- 1. Synchronize all existing licenses with their current plan settings
update public.licenses as l
set
  allow_online_billing = p.allow_online_billing,
  allow_cloud_backup = p.allow_cloud_backup,
  allow_reports_exports = p.allow_reports_exports,
  updated_at = now()
from public.plans as p
where p.id = l.plan_id
  and (
    l.allow_online_billing is distinct from p.allow_online_billing
    or l.allow_cloud_backup is distinct from p.allow_cloud_backup
    or l.allow_reports_exports is distinct from p.allow_reports_exports
  );

-- 2. Trigger function to automatically propagate plan entitlement updates to active licenses
create or replace function public.sync_plan_entitlements_to_licenses()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (
    old.allow_online_billing is distinct from new.allow_online_billing
    or old.allow_cloud_backup is distinct from new.allow_cloud_backup
    or old.allow_reports_exports is distinct from new.allow_reports_exports
  ) then
    update public.licenses
    set
      allow_online_billing = new.allow_online_billing,
      allow_cloud_backup = new.allow_cloud_backup,
      allow_reports_exports = new.allow_reports_exports,
      updated_at = now()
    where plan_id = new.id;
  end if;
  return new;
end;
$$;

-- 3. Attach trigger to public.plans
drop trigger if exists trg_sync_plan_entitlements on public.plans;
create trigger trg_sync_plan_entitlements
after update on public.plans
for each row
execute function public.sync_plan_entitlements_to_licenses();
