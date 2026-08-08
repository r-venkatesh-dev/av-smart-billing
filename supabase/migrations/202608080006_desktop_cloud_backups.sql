create table public.billing_backups (
  id uuid primary key default gen_random_uuid(),
  license_id uuid not null unique references public.licenses(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  device_name text not null check (char_length(device_name) between 1 and 120),
  app_version text not null check (char_length(app_version) between 1 and 40),
  envelope jsonb not null,
  record_counts jsonb not null default '{}'::jsonb,
  backed_up_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint billing_backups_envelope_shape check (
    envelope->>'algorithm' = 'AES-256-GCM+GZIP'
    and envelope ? 'iv'
    and envelope ? 'tag'
    and envelope ? 'ciphertext'
  )
);

create index billing_backups_backed_up_idx on public.billing_backups(backed_up_at desc);
alter table public.billing_backups enable row level security;

revoke all on public.billing_backups from public, anon, authenticated;
grant select, insert, update, delete on public.billing_backups to service_role;

comment on table public.billing_backups is 'Opaque client-encrypted SQLite snapshots used only for explicit desktop backup and restore.';
