-- Repair migration for environments where the Quarterly application code was
-- deployed before the plan_interval enum change was applied.
alter type public.plan_interval add value if not exists 'QUARTER';

update public.licenses as license
set allow_online_billing = plan.allow_online_billing,
    allow_cloud_backup = plan.allow_cloud_backup,
    updated_at = now()
from public.plans as plan
where plan.id = license.plan_id
  and (
    license.allow_online_billing is distinct from plan.allow_online_billing
    or license.allow_cloud_backup is distinct from plan.allow_cloud_backup
  );

notify pgrst, 'reload schema';
