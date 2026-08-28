create table public.billing_held_bills (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.billing_businesses(id) on delete cascade,
  label text not null check (char_length(label) between 1 and 120),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table public.billing_held_bill_items (
  id uuid primary key default gen_random_uuid(),
  held_bill_id uuid not null references public.billing_held_bills(id) on delete cascade,
  product_id uuid not null references public.billing_products(id) on delete cascade,
  quantity numeric(14,3) not null check (quantity > 0),
  discount_percent numeric(7,4) not null default 0 check (discount_percent between 0 and 100),
  unique (held_bill_id, product_id)
);

create index billing_held_bills_business_created_idx on public.billing_held_bills(business_id, created_at desc);
create index billing_held_bill_items_bill_idx on public.billing_held_bill_items(held_bill_id);

alter table public.billing_held_bills enable row level security;
alter table public.billing_held_bill_items enable row level security;

create policy billing_held_bills_admin_access on public.billing_held_bills for all to authenticated
  using (exists (select 1 from public.billing_businesses business where business.id = business_id and business.created_by = auth.uid()) and public.is_active_admin())
  with check (exists (select 1 from public.billing_businesses business where business.id = business_id and business.created_by = auth.uid()) and created_by = auth.uid() and public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]));

create policy billing_held_bill_items_admin_access on public.billing_held_bill_items for all to authenticated
  using (exists (
    select 1 from public.billing_held_bills held
    join public.billing_businesses business on business.id = held.business_id
    join public.billing_products product on product.id = product_id and product.business_id = held.business_id
    where held.id = held_bill_id and business.created_by = auth.uid()
  ) and public.is_active_admin())
  with check (exists (
    select 1 from public.billing_held_bills held
    join public.billing_businesses business on business.id = held.business_id
    join public.billing_products product on product.id = product_id and product.business_id = held.business_id
    where held.id = held_bill_id and business.created_by = auth.uid()
  ) and public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]));
