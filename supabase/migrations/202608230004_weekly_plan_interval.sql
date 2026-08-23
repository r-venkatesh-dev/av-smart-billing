alter type public.plan_interval add value if not exists 'WEEK' before 'MONTH';

comment on type public.plan_interval is
  'Commercial duration used when issuing purchased licenses: WEEK is 7 days, MONTH is 1 calendar month, and YEAR is 1 calendar year.';
