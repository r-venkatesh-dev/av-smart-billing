alter table public.plans
  add column if not exists is_publicly_visible boolean not null default false;

comment on column public.plans.is_publicly_visible is
  'Shows an inactive plan publicly as an unavailable upcoming plan. Active paid plans remain publicly purchasable.';
