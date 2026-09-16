-- Migration: 202609160001_mobile_app_version_management.sql
-- Description: Create app_versions table for managing mobile app updates

create table if not exists public.app_versions (
  id uuid primary key default gen_random_uuid(),
  platform text not null check (platform in ('android', 'ios')),
  latest_version text not null,          -- e.g. '1.0.0'
  latest_build_number integer not null,  -- e.g. 2, 3, 4
  min_required_build integer not null default 1, -- builds below this are force-updated
  release_notes text,
  update_url text not null,              -- Play Store URL or direct APK download link
  is_active boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

-- Fast lookup index for active platform releases
create index if not exists idx_app_versions_platform_active 
  on public.app_versions (platform, is_active, latest_build_number desc);

-- Enable Row Level Security
alter table public.app_versions enable row level security;

-- Public read access so devices can check version without requiring user authentication
create policy "Allow public read active app versions"
  on public.app_versions for select
  using (is_active = true);

-- Insert current initial release row
insert into public.app_versions (
  platform,
  latest_version,
  latest_build_number,
  min_required_build,
  release_notes,
  update_url,
  is_active
) values (
  'android',
  '1.0.0',
  2,
  1,
  'Initial production release with offline-first billing, barcode scanner, and Bluetooth printing.',
  'https://play.google.com/store/apps/details?id=in.avsmartbilling.mobile',
  true
) on conflict do nothing;
