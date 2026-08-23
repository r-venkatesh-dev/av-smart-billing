alter table public.plans
  add column features text[] not null default '{}'::text[];

alter table public.plans
  add constraint plans_features_limit
  check (cardinality(features) <= 20 and array_position(features, null) is null);

comment on column public.plans.features is
  'Optional ordered selling-point labels displayed on admin and public plan cards.';

