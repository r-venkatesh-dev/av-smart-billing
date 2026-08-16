-- Latest mobile cloud copy per customer, entity type, and local UUID.
-- Repeated pushes are idempotent: unchanged hashes are skipped by the API,
-- while changed payloads update the existing cloud row.
create table public.mobile_backup_records (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  entity_type text not null check (entity_type in ('products', 'customers', 'invoices')),
  local_id uuid not null,
  payload jsonb not null,
  content_hash text not null check (content_hash ~ '^[a-f0-9]{64}$'),
  source_license_id uuid not null references public.licenses(id) on delete cascade,
  source_device_id uuid references public.devices(id) on delete set null,
  local_updated_at timestamptz not null,
  cloud_updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (customer_id, entity_type, local_id)
);

create index mobile_backup_records_customer_entity_idx
  on public.mobile_backup_records(customer_id, entity_type, cloud_updated_at desc);

create table public.mobile_backup_runs (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  license_id uuid not null references public.licenses(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  entity_type text not null check (entity_type in ('products', 'customers', 'invoices')),
  received_count integer not null default 0 check (received_count >= 0),
  inserted_count integer not null default 0 check (inserted_count >= 0),
  updated_count integer not null default 0 check (updated_count >= 0),
  unchanged_count integer not null default 0 check (unchanged_count >= 0),
  completed_at timestamptz not null default now()
);

create index mobile_backup_runs_customer_completed_idx
  on public.mobile_backup_runs(customer_id, completed_at desc);

alter table public.mobile_backup_records enable row level security;
alter table public.mobile_backup_runs enable row level security;

revoke all on public.mobile_backup_records, public.mobile_backup_runs from public, anon, authenticated;
grant select, insert, update, delete on public.mobile_backup_records to service_role;
grant select, insert on public.mobile_backup_runs to service_role;

comment on table public.mobile_backup_records is 'Idempotent latest cloud copies of mobile products, customers, and invoices, isolated by licensed customer.';
comment on table public.mobile_backup_runs is 'Mobile cloud-push history and inserted/updated/unchanged counts.';
