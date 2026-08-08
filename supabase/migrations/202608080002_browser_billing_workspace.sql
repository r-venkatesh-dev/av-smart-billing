create type public.billing_invoice_status as enum ('DRAFT', 'DUE', 'PARTIALLY_PAID', 'PAID', 'CANCELLED');
create type public.billing_payment_method as enum ('CASH', 'CARD', 'UPI', 'BANK_TRANSFER', 'OTHER');

create table public.platform_settings (
  singleton boolean primary key default true check (singleton),
  default_validation_window_days integer not null default 30 check (default_validation_window_days between 1 and 365),
  expiry_warning_days integer not null default 30 check (expiry_warning_days between 1 and 365),
  license_issuer text not null default 'https://licenses.your-domain.example',
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint platform_settings_issuer_url check (license_issuer ~ '^https://')
);

insert into public.platform_settings (singleton) values (true);

create table public.billing_businesses (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles(id) on delete restrict,
  company_name text not null check (char_length(company_name) between 2 and 180),
  contact_person text not null default '' check (char_length(contact_person) <= 120),
  email text,
  phone text not null default '',
  address text not null default '',
  gstin text,
  currency_code text not null default 'INR' check (currency_code ~ '^[A-Z]{3}$'),
  invoice_prefix text not null default 'INV' check (invoice_prefix ~ '^[A-Z0-9-]{1,12}$'),
  next_invoice_number bigint not null default 1 check (next_invoice_number > 0),
  low_stock_threshold numeric(14,3) not null default 5 check (low_stock_threshold >= 0),
  status public.entity_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint billing_businesses_email_format check (email is null or email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'),
  constraint billing_businesses_gstin_format check (gstin is null or gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
);

create table public.billing_customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.billing_businesses(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 180),
  email text,
  phone text not null default '',
  address text not null default '',
  gstin text,
  status public.entity_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint billing_customers_email_format check (email is null or email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'),
  constraint billing_customers_gstin_format check (gstin is null or gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
);

create table public.billing_products (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.billing_businesses(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 180),
  sku text not null check (char_length(sku) between 1 and 80),
  description text not null default '',
  unit text not null default 'unit' check (char_length(unit) between 1 and 24),
  price_in_paise bigint not null check (price_in_paise >= 0),
  tax_rate_basis_points integer not null default 0 check (tax_rate_basis_points between 0 and 10000),
  stock_quantity numeric(14,3) not null default 0 check (stock_quantity >= 0),
  status public.entity_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, sku)
);

create table public.billing_invoices (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.billing_businesses(id) on delete cascade,
  customer_id uuid references public.billing_customers(id) on delete restrict,
  invoice_number text not null,
  issued_at timestamptz not null default now(),
  due_at timestamptz,
  status public.billing_invoice_status not null default 'DUE',
  subtotal_in_paise bigint not null default 0 check (subtotal_in_paise >= 0),
  tax_in_paise bigint not null default 0 check (tax_in_paise >= 0),
  total_in_paise bigint generated always as (subtotal_in_paise + tax_in_paise) stored,
  notes text not null default '',
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, invoice_number),
  constraint billing_invoices_due_after_issue check (due_at is null or due_at >= issued_at)
);

create table public.billing_invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.billing_invoices(id) on delete cascade,
  product_id uuid references public.billing_products(id) on delete restrict,
  description text not null check (char_length(description) between 1 and 240),
  quantity numeric(14,3) not null check (quantity > 0),
  unit_price_in_paise bigint not null check (unit_price_in_paise >= 0),
  tax_rate_basis_points integer not null default 0 check (tax_rate_basis_points between 0 and 10000),
  line_subtotal_in_paise bigint not null check (line_subtotal_in_paise >= 0),
  line_tax_in_paise bigint not null check (line_tax_in_paise >= 0),
  created_at timestamptz not null default now()
);

create table public.billing_payments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.billing_businesses(id) on delete cascade,
  invoice_id uuid not null references public.billing_invoices(id) on delete restrict,
  amount_in_paise bigint not null check (amount_in_paise > 0),
  method public.billing_payment_method not null,
  reference text,
  paid_at timestamptz not null default now(),
  notes text not null default '',
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);

create index billing_businesses_created_by_idx on public.billing_businesses(created_by, status);
create index billing_customers_business_idx on public.billing_customers(business_id, status, created_at desc);
create index billing_products_business_idx on public.billing_products(business_id, status, name);
create index billing_invoices_business_issued_idx on public.billing_invoices(business_id, issued_at desc);
create index billing_invoices_customer_idx on public.billing_invoices(customer_id, issued_at desc);
create index billing_invoice_items_invoice_idx on public.billing_invoice_items(invoice_id);
create index billing_payments_business_paid_idx on public.billing_payments(business_id, paid_at desc);
create index billing_payments_invoice_idx on public.billing_payments(invoice_id);

create trigger billing_businesses_set_updated_at before update on public.billing_businesses for each row execute function public.set_updated_at();
create trigger platform_settings_set_updated_at before update on public.platform_settings for each row execute function public.set_updated_at();
create trigger billing_customers_set_updated_at before update on public.billing_customers for each row execute function public.set_updated_at();
create trigger billing_products_set_updated_at before update on public.billing_products for each row execute function public.set_updated_at();
create trigger billing_invoices_set_updated_at before update on public.billing_invoices for each row execute function public.set_updated_at();

alter table public.billing_businesses enable row level security;
alter table public.platform_settings enable row level security;
alter table public.billing_customers enable row level security;
alter table public.billing_products enable row level security;
alter table public.billing_invoices enable row level security;
alter table public.billing_invoice_items enable row level security;
alter table public.billing_payments enable row level security;

create policy billing_businesses_admin_access on public.billing_businesses for all to authenticated
  using (created_by = auth.uid() and public.is_active_admin())
  with check (created_by = auth.uid() and public.is_active_admin(array['OWNER','ADMIN']::public.admin_role[]));
create policy platform_settings_admin_read on public.platform_settings for select to authenticated using (public.is_active_admin());
create policy platform_settings_owner_admin_write on public.platform_settings for update to authenticated
  using (public.is_active_admin(array['OWNER','ADMIN']::public.admin_role[]))
  with check (updated_by = auth.uid() and public.is_active_admin(array['OWNER','ADMIN']::public.admin_role[]));
create policy billing_customers_admin_access on public.billing_customers for all to authenticated
  using (exists (select 1 from public.billing_businesses b where b.id = business_id and b.created_by = auth.uid()) and public.is_active_admin())
  with check (exists (select 1 from public.billing_businesses b where b.id = business_id and b.created_by = auth.uid()) and public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]));
create policy billing_products_admin_access on public.billing_products for all to authenticated
  using (exists (select 1 from public.billing_businesses b where b.id = business_id and b.created_by = auth.uid()) and public.is_active_admin())
  with check (exists (select 1 from public.billing_businesses b where b.id = business_id and b.created_by = auth.uid()) and public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]));
create policy billing_invoices_admin_access on public.billing_invoices for all to authenticated
  using (exists (select 1 from public.billing_businesses b where b.id = business_id and b.created_by = auth.uid()) and public.is_active_admin())
  with check (exists (select 1 from public.billing_businesses b where b.id = business_id and b.created_by = auth.uid()) and created_by = auth.uid() and public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]));
create policy billing_invoice_items_admin_access on public.billing_invoice_items for all to authenticated
  using (exists (select 1 from public.billing_invoices i join public.billing_businesses b on b.id = i.business_id where i.id = billing_invoice_items.invoice_id and b.created_by = auth.uid()) and public.is_active_admin())
  with check (exists (select 1 from public.billing_invoices i join public.billing_businesses b on b.id = i.business_id where i.id = billing_invoice_items.invoice_id and b.created_by = auth.uid()) and public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]));
create policy billing_payments_admin_access on public.billing_payments for all to authenticated
  using (exists (select 1 from public.billing_businesses b where b.id = business_id and b.created_by = auth.uid()) and public.is_active_admin())
  with check (exists (select 1 from public.billing_businesses b where b.id = business_id and b.created_by = auth.uid()) and created_by = auth.uid() and public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]));

revoke all on public.billing_businesses, public.billing_customers, public.billing_products, public.billing_invoices, public.billing_invoice_items, public.billing_payments from anon;
grant select, insert, update, delete on public.billing_businesses, public.billing_customers, public.billing_products, public.billing_invoices, public.billing_invoice_items, public.billing_payments to authenticated;
grant select, update on public.platform_settings to authenticated;

create policy audit_admin_insert on public.audit_logs for insert to authenticated
  with check (actor_id = auth.uid() and public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]));
grant insert on public.audit_logs to authenticated;

create or replace function public.create_billing_invoice(
  p_business_id uuid,
  p_customer_id uuid,
  p_product_id uuid,
  p_quantity numeric,
  p_due_at timestamptz default null,
  p_notes text default ''
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_business public.billing_businesses;
  v_product public.billing_products;
  v_invoice_id uuid;
  v_invoice_number text;
  v_subtotal bigint;
  v_tax bigint;
begin
  if not public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]) then
    raise exception 'Insufficient permissions';
  end if;
  if p_quantity <= 0 then raise exception 'Quantity must be positive'; end if;

  select * into v_business from public.billing_businesses
    where id = p_business_id and created_by = auth.uid() and status = 'ACTIVE' for update;
  if not found then raise exception 'Billing business not found'; end if;

  select * into v_product from public.billing_products
    where id = p_product_id and business_id = p_business_id and status = 'ACTIVE' for update;
  if not found then raise exception 'Product not found'; end if;
  if v_product.stock_quantity < p_quantity then raise exception 'Insufficient stock'; end if;
  if p_customer_id is not null and not exists (
    select 1 from public.billing_customers where id = p_customer_id and business_id = p_business_id and status = 'ACTIVE'
  ) then raise exception 'Customer not found'; end if;

  v_invoice_number := v_business.invoice_prefix || '-' || lpad(v_business.next_invoice_number::text, 6, '0');
  v_subtotal := round(v_product.price_in_paise * p_quantity)::bigint;
  v_tax := round(v_subtotal * v_product.tax_rate_basis_points / 10000.0)::bigint;

  insert into public.billing_invoices (business_id, customer_id, invoice_number, due_at, subtotal_in_paise, tax_in_paise, notes, created_by)
  values (p_business_id, p_customer_id, v_invoice_number, p_due_at, v_subtotal, v_tax, coalesce(p_notes, ''), auth.uid())
  returning id into v_invoice_id;

  insert into public.billing_invoice_items (invoice_id, product_id, description, quantity, unit_price_in_paise, tax_rate_basis_points, line_subtotal_in_paise, line_tax_in_paise)
  values (v_invoice_id, p_product_id, v_product.name, p_quantity, v_product.price_in_paise, v_product.tax_rate_basis_points, v_subtotal, v_tax);

  update public.billing_products set stock_quantity = stock_quantity - p_quantity where id = p_product_id;
  update public.billing_businesses set next_invoice_number = next_invoice_number + 1 where id = p_business_id;
  return v_invoice_id;
end; $$;

create or replace function public.record_billing_payment(
  p_business_id uuid,
  p_invoice_id uuid,
  p_amount_in_paise bigint,
  p_method public.billing_payment_method,
  p_reference text default null,
  p_notes text default ''
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_invoice public.billing_invoices;
  v_paid bigint;
  v_payment_id uuid;
begin
  if not public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]) then
    raise exception 'Insufficient permissions';
  end if;
  if p_amount_in_paise <= 0 then raise exception 'Payment must be positive'; end if;
  if not exists (select 1 from public.billing_businesses where id = p_business_id and created_by = auth.uid() and status = 'ACTIVE') then
    raise exception 'Billing business not found';
  end if;

  select * into v_invoice from public.billing_invoices
    where id = p_invoice_id and business_id = p_business_id and status not in ('CANCELLED','PAID') for update;
  if not found then raise exception 'Payable invoice not found'; end if;
  select coalesce(sum(amount_in_paise), 0) into v_paid from public.billing_payments where invoice_id = p_invoice_id;
  if v_paid + p_amount_in_paise > v_invoice.total_in_paise then raise exception 'Payment exceeds outstanding balance'; end if;

  insert into public.billing_payments (business_id, invoice_id, amount_in_paise, method, reference, notes, created_by)
  values (p_business_id, p_invoice_id, p_amount_in_paise, p_method, nullif(trim(p_reference), ''), coalesce(p_notes, ''), auth.uid())
  returning id into v_payment_id;

  update public.billing_invoices set status = case when v_paid + p_amount_in_paise = total_in_paise then 'PAID'::public.billing_invoice_status else 'PARTIALLY_PAID'::public.billing_invoice_status end
  where id = p_invoice_id;
  return v_payment_id;
end; $$;

revoke all on function public.create_billing_invoice(uuid, uuid, uuid, numeric, timestamptz, text) from public, anon;
revoke all on function public.record_billing_payment(uuid, uuid, bigint, public.billing_payment_method, text, text) from public, anon;
grant execute on function public.create_billing_invoice(uuid, uuid, uuid, numeric, timestamptz, text) to authenticated;
grant execute on function public.record_billing_payment(uuid, uuid, bigint, public.billing_payment_method, text, text) to authenticated;
