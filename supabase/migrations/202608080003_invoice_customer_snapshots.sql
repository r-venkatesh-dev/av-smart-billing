alter table public.billing_invoices
  add column customer_name text,
  add column customer_phone text not null default '',
  add column customer_email text,
  add column customer_address text not null default '',
  add column customer_gstin text;

update public.billing_invoices i
set customer_name = coalesce(c.name, 'Walk-in customer'),
    customer_phone = coalesce(c.phone, ''),
    customer_email = c.email,
    customer_address = coalesce(c.address, ''),
    customer_gstin = c.gstin
from public.billing_customers c
where c.id = i.customer_id;

update public.billing_invoices
set customer_name = 'Walk-in customer'
where customer_name is null;

alter table public.billing_invoices
  alter column customer_name set not null,
  add constraint billing_invoices_customer_name_present check (char_length(trim(customer_name)) between 2 and 180),
  add constraint billing_invoices_customer_phone_length check (char_length(customer_phone) <= 40);

drop function if exists public.create_billing_invoice(uuid, uuid, uuid, numeric, timestamptz, text);

create function public.create_billing_invoice(
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
  v_customer_name text;
  v_customer_phone text;
  v_customer_email text;
  v_customer_address text;
  v_customer_gstin text;
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

  if p_customer_id is not null then
    select * into v_customer from public.billing_customers
      where id = p_customer_id and business_id = p_business_id and status = 'ACTIVE';
    if not found then raise exception 'Customer not found'; end if;
    v_customer_name := v_customer.name;
    v_customer_phone := v_customer.phone;
    v_customer_email := v_customer.email;
    v_customer_address := v_customer.address;
    v_customer_gstin := v_customer.gstin;
  else
    v_customer_name := trim(coalesce(p_walk_in_name, ''));
    v_customer_phone := trim(coalesce(p_walk_in_phone, ''));
    if char_length(v_customer_name) < 2 then raise exception 'Walk-in customer name is required'; end if;
    if char_length(v_customer_phone) < 5 then raise exception 'Walk-in customer mobile number is required'; end if;
    v_customer_email := null;
    v_customer_address := '';
    v_customer_gstin := null;
  end if;

  v_invoice_number := v_business.invoice_prefix || '-' || lpad(v_business.next_invoice_number::text, 6, '0');
  v_subtotal := round(v_product.price_in_paise * p_quantity)::bigint;
  v_tax := round(v_subtotal * v_product.tax_rate_basis_points / 10000.0)::bigint;

  insert into public.billing_invoices (business_id, customer_id, customer_name, customer_phone, customer_email, customer_address, customer_gstin, invoice_number, due_at, subtotal_in_paise, tax_in_paise, notes, created_by)
  values (p_business_id, p_customer_id, v_customer_name, v_customer_phone, v_customer_email, v_customer_address, v_customer_gstin, v_invoice_number, p_due_at, v_subtotal, v_tax, coalesce(p_notes, ''), auth.uid())
  returning id into v_invoice_id;

  insert into public.billing_invoice_items (invoice_id, product_id, description, quantity, unit_price_in_paise, tax_rate_basis_points, line_subtotal_in_paise, line_tax_in_paise)
  values (v_invoice_id, p_product_id, v_product.name, p_quantity, v_product.price_in_paise, v_product.tax_rate_basis_points, v_subtotal, v_tax);

  update public.billing_products set stock_quantity = stock_quantity - p_quantity where id = p_product_id;
  update public.billing_businesses set next_invoice_number = next_invoice_number + 1 where id = p_business_id;
  return v_invoice_id;
end; $$;

revoke all on function public.create_billing_invoice(uuid, uuid, uuid, numeric, timestamptz, text, text, text) from public, anon;
grant execute on function public.create_billing_invoice(uuid, uuid, uuid, numeric, timestamptz, text, text, text) to authenticated;
