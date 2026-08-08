create extension if not exists pgcrypto;

create type public.admin_role as enum ('OWNER', 'ADMIN', 'SUPPORT', 'VIEWER');
create type public.entity_status as enum ('ACTIVE', 'INACTIVE');
create type public.license_status as enum ('ACTIVE', 'EXPIRED', 'SUSPENDED', 'REVOKED');
create type public.device_status as enum ('ACTIVE', 'DEACTIVATED');
create type public.activation_event as enum ('ACTIVATED', 'VALIDATED', 'DEACTIVATED', 'RESET', 'REJECTED');
create type public.plan_interval as enum ('MONTH', 'YEAR');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (char_length(full_name) between 2 and 120),
  role public.admin_role not null default 'VIEWER',
  status public.entity_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  company_name text not null check (char_length(company_name) between 2 and 180),
  contact_person text not null check (char_length(contact_person) between 2 and 120),
  email text not null,
  phone text not null,
  address text not null,
  gstin text,
  status public.entity_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint customers_email_format check (email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'),
  constraint customers_gstin_format check (gstin is null or gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
);

create table public.plans (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (char_length(name) between 2 and 80),
  description text not null default '',
  max_devices integer not null check (max_devices between 1 and 100),
  validation_window_days integer not null default 30 check (validation_window_days between 1 and 365),
  price_in_paise bigint not null default 0 check (price_in_paise >= 0),
  interval public.plan_interval not null default 'YEAR',
  status public.entity_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.licenses (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete restrict,
  plan_id uuid not null references public.plans(id) on delete restrict,
  license_key_hash text not null unique check (char_length(license_key_hash) = 64),
  license_key_hint text not null,
  max_devices integer not null check (max_devices between 1 and 100),
  validation_window_days integer not null check (validation_window_days between 1 and 365),
  status public.license_status not null default 'ACTIVE',
  expires_at timestamptz not null,
  last_validated_at timestamptz,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint licenses_expiry_after_creation check (expires_at > created_at)
);

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  license_id uuid not null references public.licenses(id) on delete cascade,
  fingerprint_hash text not null check (char_length(fingerprint_hash) = 64),
  fingerprint_hint text not null,
  device_name text not null check (char_length(device_name) between 1 and 120),
  status public.device_status not null default 'ACTIVE',
  activated_at timestamptz not null default now(),
  last_validated_at timestamptz not null default now(),
  deactivated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index devices_one_active_fingerprint_per_license
  on public.devices (license_id, fingerprint_hash) where status = 'ACTIVE';

create table public.license_activations (
  id uuid primary key default gen_random_uuid(),
  license_id uuid not null references public.licenses(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  event public.activation_event not null,
  success boolean not null,
  failure_code text,
  ip_address inet,
  user_agent text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  ip_address inet,
  created_at timestamptz not null default now()
);

create index customers_status_idx on public.customers(status);
create index customers_created_at_idx on public.customers(created_at desc);
create index licenses_customer_id_idx on public.licenses(customer_id);
create index licenses_plan_id_idx on public.licenses(plan_id);
create index licenses_status_expiry_idx on public.licenses(status, expires_at);
create index devices_license_status_idx on public.devices(license_id, status);
create index license_activations_license_created_idx on public.license_activations(license_id, created_at desc);
create index audit_logs_entity_idx on public.audit_logs(entity_type, entity_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin new.updated_at = now(); return new; end; $$;

create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger customers_set_updated_at before update on public.customers for each row execute function public.set_updated_at();
create trigger plans_set_updated_at before update on public.plans for each row execute function public.set_updated_at();
create trigger licenses_set_updated_at before update on public.licenses for each row execute function public.set_updated_at();
create trigger devices_set_updated_at before update on public.devices for each row execute function public.set_updated_at();

create or replace function public.is_active_admin(allowed_roles public.admin_role[] default array['OWNER','ADMIN','SUPPORT','VIEWER']::public.admin_role[])
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id = auth.uid() and status = 'ACTIVE' and role = any(allowed_roles));
$$;

alter table public.profiles enable row level security;
alter table public.customers enable row level security;
alter table public.plans enable row level security;
alter table public.licenses enable row level security;
alter table public.devices enable row level security;
alter table public.license_activations enable row level security;
alter table public.audit_logs enable row level security;

create policy profiles_read_self_or_admin on public.profiles for select to authenticated using (id = auth.uid() or public.is_active_admin());
create policy profiles_owner_manage on public.profiles for all to authenticated using (public.is_active_admin(array['OWNER']::public.admin_role[])) with check (public.is_active_admin(array['OWNER']::public.admin_role[]));
create policy customers_admin_read on public.customers for select to authenticated using (public.is_active_admin());
create policy customers_admin_write on public.customers for all to authenticated using (public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[])) with check (public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]));
create policy plans_admin_read on public.plans for select to authenticated using (public.is_active_admin());
create policy plans_owner_admin_write on public.plans for all to authenticated using (public.is_active_admin(array['OWNER','ADMIN']::public.admin_role[])) with check (public.is_active_admin(array['OWNER','ADMIN']::public.admin_role[]));
create policy licenses_admin_read on public.licenses for select to authenticated using (public.is_active_admin());
create policy licenses_owner_admin_write on public.licenses for all to authenticated using (public.is_active_admin(array['OWNER','ADMIN']::public.admin_role[])) with check (public.is_active_admin(array['OWNER','ADMIN']::public.admin_role[]));
create policy devices_admin_read on public.devices for select to authenticated using (public.is_active_admin());
create policy devices_admin_write on public.devices for all to authenticated using (public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[])) with check (public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]));
create policy activations_admin_read on public.license_activations for select to authenticated using (public.is_active_admin());
create policy audit_owner_admin_read on public.audit_logs for select to authenticated using (public.is_active_admin(array['OWNER','ADMIN']::public.admin_role[]));

revoke all on public.profiles, public.customers, public.plans, public.licenses, public.devices, public.license_activations, public.audit_logs from anon;
grant select, insert, update, delete on public.profiles, public.customers, public.plans, public.licenses, public.devices to authenticated;
grant select on public.license_activations, public.audit_logs to authenticated;

insert into public.plans (name, description, max_devices, validation_window_days, price_in_paise)
values ('Basic', 'For a single billing counter', 1, 30, 899900), ('Professional', 'For growing retail businesses', 2, 45, 1499900), ('Business', 'For multi-counter operations', 5, 60, 2499900);
