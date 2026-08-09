-- Incremental AV Smartbilling expansion: richer products, traceable stock,
-- GST invoice metadata, and non-destructive versioned desktop backups.

alter table public.billing_products
  add column barcode text,
  add column category text not null default '',
  add column hsn_sac text not null default '',
  add column purchase_price_in_paise bigint not null default 0 check (purchase_price_in_paise >= 0),
  add column low_stock_threshold numeric(14,3) check (low_stock_threshold is null or low_stock_threshold >= 0);

create unique index billing_products_business_barcode_unique_idx
  on public.billing_products(business_id, barcode)
  where barcode is not null and char_length(trim(barcode)) > 0;
create index billing_products_business_category_idx on public.billing_products(business_id, category, name);

create table public.billing_product_categories (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.billing_businesses(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 120),
  status public.entity_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, name)
);

create type public.billing_stock_movement_type as enum ('OPENING', 'PURCHASE', 'SALE', 'RETURN', 'ADJUSTMENT');

create table public.billing_stock_movements (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.billing_businesses(id) on delete cascade,
  product_id uuid not null references public.billing_products(id) on delete restrict,
  movement_type public.billing_stock_movement_type not null,
  quantity_change numeric(14,3) not null check (quantity_change <> 0),
  quantity_after numeric(14,3) not null check (quantity_after >= 0),
  reference_type text,
  reference_id uuid,
  reference_number text,
  notes text not null default '',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index billing_stock_movements_product_created_idx on public.billing_stock_movements(product_id, created_at desc);
create index billing_stock_movements_business_created_idx on public.billing_stock_movements(business_id, created_at desc);

insert into public.billing_stock_movements (business_id, product_id, movement_type, quantity_change, quantity_after, reference_type, reference_id, notes, created_by, created_at)
select p.business_id, p.id, 'OPENING', p.stock_quantity, p.stock_quantity, 'MIGRATION', p.id,
  'Opening balance created during inventory-ledger upgrade', b.created_by, p.created_at
from public.billing_products p
join public.billing_businesses b on b.id = p.business_id
where p.stock_quantity > 0;

alter table public.billing_businesses
  add column state_code text not null default '' check (state_code = '' or state_code ~ '^[0-9]{2}$'),
  add column invoice_terms text not null default '',
  add column invoice_footer text not null default '',
  add column thermal_paper_width integer not null default 80 check (thermal_paper_width in (58, 80));

alter table public.billing_invoices
  add column shipping_address text not null default '',
  add column discount_in_paise bigint not null default 0 check (discount_in_paise >= 0),
  add column terms text not null default '',
  add column sale_mode text not null default 'INVOICE' check (sale_mode in ('INVOICE', 'POS')),
  add column tax_type text not null default 'INTRA_STATE' check (tax_type in ('INTRA_STATE', 'INTER_STATE'));

alter table public.billing_invoice_items
  add column sku text not null default '',
  add column hsn_sac text not null default '',
  add column unit text not null default 'unit',
  add column discount_in_paise bigint not null default 0 check (discount_in_paise >= 0),
  add column taxable_in_paise bigint not null default 0 check (taxable_in_paise >= 0),
  add column cgst_in_paise bigint not null default 0 check (cgst_in_paise >= 0),
  add column sgst_in_paise bigint not null default 0 check (sgst_in_paise >= 0),
  add column igst_in_paise bigint not null default 0 check (igst_in_paise >= 0);

update public.billing_invoice_items i
set sku = p.sku,
    hsn_sac = p.hsn_sac,
    unit = p.unit,
    taxable_in_paise = i.line_subtotal_in_paise,
    cgst_in_paise = i.line_tax_in_paise / 2,
    sgst_in_paise = i.line_tax_in_paise - (i.line_tax_in_paise / 2)
from public.billing_products p
where p.id = i.product_id;

alter table public.billing_product_categories enable row level security;
alter table public.billing_stock_movements enable row level security;

create policy billing_product_categories_admin_access on public.billing_product_categories for all to authenticated
  using (exists (select 1 from public.billing_businesses b where b.id = business_id and b.created_by = auth.uid()) and public.is_active_admin())
  with check (exists (select 1 from public.billing_businesses b where b.id = business_id and b.created_by = auth.uid()) and public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]));

create policy billing_stock_movements_admin_read on public.billing_stock_movements for select to authenticated
  using (exists (select 1 from public.billing_businesses b where b.id = business_id and b.created_by = auth.uid()) and public.is_active_admin());

create policy billing_stock_movements_admin_insert on public.billing_stock_movements for insert to authenticated
  with check (exists (select 1 from public.billing_businesses b where b.id = business_id and b.created_by = auth.uid()) and created_by = auth.uid() and public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]));

grant select, insert, update, delete on public.billing_product_categories to authenticated;
grant select, insert on public.billing_stock_movements to authenticated;

-- Backups are append-only versions. Restore can select one version without
-- overwriting or deleting earlier recovery points.
alter table public.billing_backups drop constraint billing_backups_license_id_key;
create index billing_backups_license_backed_up_idx on public.billing_backups(license_id, backed_up_at desc);

comment on table public.billing_stock_movements is 'Immutable stock history shared logically with the desktop SQLite model.';
comment on table public.billing_backups is 'Versioned opaque client-encrypted SQLite snapshots used only for explicit desktop backup and restore.';

create or replace function public.create_billing_pos_sale(
  p_business_id uuid,
  p_customer_id uuid,
  p_walk_in_name text,
  p_walk_in_phone text,
  p_items jsonb,
  p_payment_method text default 'CASH',
  p_amount_received_in_paise bigint default 0,
  p_reference text default null,
  p_tax_type text default 'INTRA_STATE'
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_business public.billing_businesses;
  v_customer public.billing_customers;
  v_product public.billing_products;
  v_item jsonb;
  v_actor_id uuid;
  v_invoice_id uuid := gen_random_uuid();
  v_payment_id uuid;
  v_invoice_number text;
  v_customer_name text;
  v_customer_phone text;
  v_customer_email text;
  v_customer_address text;
  v_customer_gstin text;
  v_quantity numeric;
  v_discount_percent numeric;
  v_gross bigint;
  v_discount bigint;
  v_taxable bigint;
  v_tax bigint;
  v_cgst bigint;
  v_sgst bigint;
  v_igst bigint;
  v_gross_total bigint := 0;
  v_discount_total bigint := 0;
  v_taxable_total bigint := 0;
  v_tax_total bigint := 0;
  v_total bigint;
  v_paid bigint;
begin
  if auth.role() <> 'service_role' and not public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]) then raise exception 'Insufficient permissions'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Add at least one product'; end if;
  if p_tax_type not in ('INTRA_STATE','INTER_STATE') then raise exception 'Invalid GST treatment'; end if;
  if p_payment_method not in ('CASH','CARD','UPI','BANK_TRANSFER','OTHER','CREDIT') then raise exception 'Invalid payment method'; end if;

  select * into v_business from public.billing_businesses
    where id = p_business_id and status = 'ACTIVE' and case when auth.role() = 'service_role' then true else created_by = auth.uid() end for update;
  if not found then raise exception 'Billing business not found'; end if;
  if auth.role() = 'service_role' then v_actor_id := v_business.created_by; else v_actor_id := auth.uid(); end if;

  if p_customer_id is not null then
    select * into v_customer from public.billing_customers where id = p_customer_id and business_id = p_business_id and status = 'ACTIVE';
    if not found then raise exception 'Customer not found'; end if;
    v_customer_name := v_customer.name; v_customer_phone := v_customer.phone; v_customer_email := v_customer.email; v_customer_address := v_customer.address; v_customer_gstin := v_customer.gstin;
  else
    v_customer_name := trim(coalesce(p_walk_in_name, '')); v_customer_phone := trim(coalesce(p_walk_in_phone, ''));
    if char_length(v_customer_name) < 2 then raise exception 'Walk-in customer name is required'; end if;
    if char_length(v_customer_phone) < 5 then raise exception 'Walk-in customer mobile number is required'; end if;
    v_customer_email := null; v_customer_address := ''; v_customer_gstin := null;
  end if;

  -- Lock every requested product in deterministic order, then validate combined
  -- quantities so duplicate cart rows cannot oversell stock.
  for v_product in
    select p.* from public.billing_products p
    join (select (entry->>'productId')::uuid id, sum((entry->>'quantity')::numeric) quantity from jsonb_array_elements(p_items) entry group by 1) request on request.id = p.id
    where p.business_id = p_business_id and p.status = 'ACTIVE'
    order by p.id for update of p
  loop
    select sum((entry->>'quantity')::numeric) into v_quantity from jsonb_array_elements(p_items) entry where (entry->>'productId')::uuid = v_product.id;
    if v_quantity <= 0 or v_product.stock_quantity < v_quantity then raise exception 'Insufficient stock for %', v_product.name; end if;
  end loop;

  if (select count(distinct (entry->>'productId')::uuid) from jsonb_array_elements(p_items) entry) <>
     (select count(*) from public.billing_products p where p.business_id = p_business_id and p.status = 'ACTIVE' and p.id in (select (entry->>'productId')::uuid from jsonb_array_elements(p_items) entry)) then
    raise exception 'One or more products are unavailable';
  end if;

  v_invoice_number := v_business.invoice_prefix || '-' || lpad(v_business.next_invoice_number::text, 6, '0');

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select * into strict v_product from public.billing_products where id = (v_item->>'productId')::uuid and business_id = p_business_id;
    v_quantity := (v_item->>'quantity')::numeric;
    v_discount_percent := least(100, greatest(0, coalesce((v_item->>'discountPercent')::numeric, 0)));
    v_gross := round(v_product.price_in_paise * v_quantity)::bigint;
    v_discount := round(v_gross * v_discount_percent / 100.0)::bigint;
    v_taxable := v_gross - v_discount;
    v_tax := round(v_taxable * v_product.tax_rate_basis_points / 10000.0)::bigint;
    v_cgst := case when p_tax_type = 'INTRA_STATE' then v_tax / 2 else 0 end;
    v_sgst := case when p_tax_type = 'INTRA_STATE' then v_tax - v_cgst else 0 end;
    v_igst := case when p_tax_type = 'INTER_STATE' then v_tax else 0 end;
    v_gross_total := v_gross_total + v_gross; v_discount_total := v_discount_total + v_discount; v_taxable_total := v_taxable_total + v_taxable; v_tax_total := v_tax_total + v_tax;

  end loop;

  insert into public.billing_invoices (id,business_id,customer_id,customer_name,customer_phone,customer_email,customer_address,customer_gstin,shipping_address,invoice_number,status,subtotal_in_paise,discount_in_paise,tax_in_paise,notes,terms,sale_mode,tax_type,created_by)
  values (v_invoice_id,p_business_id,p_customer_id,v_customer_name,v_customer_phone,v_customer_email,v_customer_address,v_customer_gstin,v_customer_address,v_invoice_number,'DUE',v_taxable_total,v_discount_total,v_tax_total,'POS sale',v_business.invoice_terms,'POS',p_tax_type,v_actor_id);

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select * into strict v_product from public.billing_products where id = (v_item->>'productId')::uuid and business_id = p_business_id;
    v_quantity := (v_item->>'quantity')::numeric;
    v_discount_percent := least(100, greatest(0, coalesce((v_item->>'discountPercent')::numeric, 0)));
    v_gross := round(v_product.price_in_paise * v_quantity)::bigint;
    v_discount := round(v_gross * v_discount_percent / 100.0)::bigint;
    v_taxable := v_gross - v_discount;
    v_tax := round(v_taxable * v_product.tax_rate_basis_points / 10000.0)::bigint;
    v_cgst := case when p_tax_type = 'INTRA_STATE' then v_tax / 2 else 0 end;
    v_sgst := case when p_tax_type = 'INTRA_STATE' then v_tax - v_cgst else 0 end;
    v_igst := case when p_tax_type = 'INTER_STATE' then v_tax else 0 end;
    insert into public.billing_invoice_items (id,invoice_id,product_id,description,sku,hsn_sac,unit,quantity,unit_price_in_paise,tax_rate_basis_points,discount_in_paise,taxable_in_paise,cgst_in_paise,sgst_in_paise,igst_in_paise,line_subtotal_in_paise,line_tax_in_paise)
    values (gen_random_uuid(),v_invoice_id,v_product.id,v_product.name,v_product.sku,v_product.hsn_sac,v_product.unit,v_quantity,v_product.price_in_paise,v_product.tax_rate_basis_points,v_discount,v_taxable,v_cgst,v_sgst,v_igst,v_gross,v_tax);
  end loop;

  for v_product in select p.* from public.billing_products p where p.id in (select (entry->>'productId')::uuid from jsonb_array_elements(p_items) entry) order by p.id
  loop
    select sum((entry->>'quantity')::numeric) into v_quantity from jsonb_array_elements(p_items) entry where (entry->>'productId')::uuid = v_product.id;
    update public.billing_products set stock_quantity = stock_quantity - v_quantity where id = v_product.id returning stock_quantity into v_product.stock_quantity;
    insert into public.billing_stock_movements (business_id,product_id,movement_type,quantity_change,quantity_after,reference_type,reference_id,notes,created_by)
    values (p_business_id,v_product.id,'SALE',-v_quantity,v_product.stock_quantity,'INVOICE',v_invoice_id,v_invoice_number,v_actor_id);
  end loop;

  v_total := v_taxable_total + v_tax_total;
  if p_payment_method <> 'CREDIT' then
    v_paid := least(v_total, case when p_amount_received_in_paise > 0 then p_amount_received_in_paise else v_total end);
    insert into public.billing_payments (business_id,invoice_id,amount_in_paise,method,reference,notes,created_by)
    values (p_business_id,v_invoice_id,v_paid,p_payment_method::public.billing_payment_method,nullif(trim(p_reference),''),'POS checkout',v_actor_id) returning id into v_payment_id;
    update public.billing_invoices set status = case when v_paid = v_total then 'PAID'::public.billing_invoice_status else 'PARTIALLY_PAID'::public.billing_invoice_status end where id = v_invoice_id;
  end if;

  update public.billing_businesses set next_invoice_number = next_invoice_number + 1 where id = p_business_id;
  return jsonb_build_object('invoiceId',v_invoice_id,'invoiceNumber',v_invoice_number,'totalInPaise',v_total,'changeInPaise',case when p_payment_method='CASH' then greatest(0,p_amount_received_in_paise-v_total) else 0 end);
end; $$;

revoke all on function public.create_billing_pos_sale(uuid,uuid,text,text,jsonb,text,bigint,text,text) from public, anon;
grant execute on function public.create_billing_pos_sale(uuid,uuid,text,text,jsonb,text,bigint,text,text) to authenticated, service_role;

create or replace function public.adjust_billing_stock(
  p_business_id uuid,
  p_product_id uuid,
  p_movement_type text,
  p_quantity numeric,
  p_reference text default null,
  p_notes text default ''
) returns numeric
language plpgsql security definer set search_path = '' as $$
declare
  v_product public.billing_products;
  v_actor_id uuid;
  v_change numeric;
  v_after numeric;
begin
  if auth.role() <> 'service_role' and not public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]) then raise exception 'Insufficient permissions'; end if;
  if p_movement_type not in ('PURCHASE','RETURN','ADJUSTMENT') then raise exception 'Invalid stock movement'; end if;
  select p.* into v_product from public.billing_products p where p.id = p_product_id and p.business_id = p_business_id for update;
  if not found then raise exception 'Product not found'; end if;
  select b.created_by into v_actor_id from public.billing_businesses b where b.id = p_business_id and case when auth.role()='service_role' then true else b.created_by=auth.uid() end;
  if not found then raise exception 'Billing business not found'; end if;
  if auth.role() <> 'service_role' then v_actor_id := auth.uid(); end if;
  if p_movement_type = 'ADJUSTMENT' then v_change := p_quantity - v_product.stock_quantity; else v_change := p_quantity; end if;
  if (p_movement_type <> 'ADJUSTMENT' and p_quantity <= 0) or v_change = 0 then raise exception 'Stock quantity does not create a movement'; end if;
  v_after := v_product.stock_quantity + v_change;
  if v_after < 0 then raise exception 'Stock cannot become negative'; end if;
  update public.billing_products set stock_quantity = v_after where id = p_product_id;
  insert into public.billing_stock_movements (business_id,product_id,movement_type,quantity_change,quantity_after,reference_type,reference_number,notes,created_by)
  values (p_business_id,p_product_id,p_movement_type::public.billing_stock_movement_type,v_change,v_after,p_movement_type,nullif(trim(p_reference),''),coalesce(p_notes,''),v_actor_id);
  return v_after;
end; $$;

revoke all on function public.adjust_billing_stock(uuid,uuid,text,numeric,text,text) from public, anon;
grant execute on function public.adjust_billing_stock(uuid,uuid,text,numeric,text,text) to authenticated, service_role;

create or replace function public.create_billing_invoice(
  p_business_id uuid,
  p_customer_id uuid,
  p_product_id uuid,
  p_quantity numeric,
  p_due_at timestamptz default null,
  p_notes text default '',
  p_walk_in_name text default null,
  p_walk_in_phone text default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_business public.billing_businesses;
  v_product public.billing_products;
  v_customer public.billing_customers;
  v_invoice_id uuid;
  v_invoice_number text;
  v_subtotal bigint;
  v_tax bigint;
  v_cgst bigint;
  v_actor_id uuid;
  v_customer_name text;
  v_customer_phone text;
  v_customer_email text;
  v_customer_address text;
  v_customer_gstin text;
begin
  if auth.role() <> 'service_role' and not public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]) then raise exception 'Insufficient permissions'; end if;
  if p_quantity <= 0 then raise exception 'Quantity must be positive'; end if;
  select * into v_business from public.billing_businesses where id=p_business_id and status='ACTIVE' and case when auth.role()='service_role' then true else created_by=auth.uid() end for update;
  if not found then raise exception 'Billing business not found'; end if;
  if auth.role()='service_role' then v_actor_id:=v_business.created_by; else v_actor_id:=auth.uid(); end if;
  select * into v_product from public.billing_products where id=p_product_id and business_id=p_business_id and status='ACTIVE' for update;
  if not found then raise exception 'Product not found'; end if;
  if v_product.stock_quantity < p_quantity then raise exception 'Insufficient stock'; end if;
  if p_customer_id is not null then
    select * into v_customer from public.billing_customers where id=p_customer_id and business_id=p_business_id and status='ACTIVE';
    if not found then raise exception 'Customer not found'; end if;
    v_customer_name:=v_customer.name; v_customer_phone:=v_customer.phone; v_customer_email:=v_customer.email; v_customer_address:=v_customer.address; v_customer_gstin:=v_customer.gstin;
  else
    v_customer_name:=trim(coalesce(p_walk_in_name,'')); v_customer_phone:=trim(coalesce(p_walk_in_phone,''));
    if char_length(v_customer_name)<2 then raise exception 'Walk-in customer name is required'; end if;
    if char_length(v_customer_phone)<5 then raise exception 'Walk-in customer mobile number is required'; end if;
    v_customer_email:=null; v_customer_address:=''; v_customer_gstin:=null;
  end if;
  v_invoice_number:=v_business.invoice_prefix||'-'||lpad(v_business.next_invoice_number::text,6,'0');
  v_subtotal:=round(v_product.price_in_paise*p_quantity)::bigint;
  v_tax:=round(v_subtotal*v_product.tax_rate_basis_points/10000.0)::bigint;
  v_cgst:=v_tax/2;
  insert into public.billing_invoices(business_id,customer_id,customer_name,customer_phone,customer_email,customer_address,customer_gstin,shipping_address,invoice_number,due_at,subtotal_in_paise,tax_in_paise,notes,terms,sale_mode,tax_type,created_by)
  values(p_business_id,p_customer_id,v_customer_name,v_customer_phone,v_customer_email,v_customer_address,v_customer_gstin,v_customer_address,v_invoice_number,p_due_at,v_subtotal,v_tax,coalesce(p_notes,''),v_business.invoice_terms,'INVOICE','INTRA_STATE',v_actor_id) returning id into v_invoice_id;
  insert into public.billing_invoice_items(invoice_id,product_id,description,sku,hsn_sac,unit,quantity,unit_price_in_paise,tax_rate_basis_points,taxable_in_paise,cgst_in_paise,sgst_in_paise,line_subtotal_in_paise,line_tax_in_paise)
  values(v_invoice_id,v_product.id,v_product.name,v_product.sku,v_product.hsn_sac,v_product.unit,p_quantity,v_product.price_in_paise,v_product.tax_rate_basis_points,v_subtotal,v_cgst,v_tax-v_cgst,v_subtotal,v_tax);
  update public.billing_products set stock_quantity=stock_quantity-p_quantity where id=v_product.id returning stock_quantity into v_product.stock_quantity;
  insert into public.billing_stock_movements(business_id,product_id,movement_type,quantity_change,quantity_after,reference_type,reference_id,notes,created_by)
  values(p_business_id,v_product.id,'SALE',-p_quantity,v_product.stock_quantity,'INVOICE',v_invoice_id,v_invoice_number,v_actor_id);
  update public.billing_businesses set next_invoice_number=next_invoice_number+1 where id=p_business_id;
  return v_invoice_id;
end; $$;

grant execute on function public.create_billing_invoice(uuid,uuid,uuid,numeric,timestamptz,text,text,text) to authenticated, service_role;
