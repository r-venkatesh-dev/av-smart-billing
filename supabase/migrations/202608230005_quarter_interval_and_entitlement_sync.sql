alter type public.plan_interval add value if not exists 'QUARTER';

comment on type public.plan_interval is
  'Commercial duration used when issuing purchased licenses: WEEK is 7 days, MONTH is 1 calendar month, QUARTER is 3 calendar months, and YEAR is 1 calendar year.';

-- Bring licenses issued before plan entitlements were configured into line
-- with their current plan. Future licenses already copy these values when
-- they are issued.
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
