alter table public.billing_businesses
  add column license_id uuid unique references public.licenses(id) on delete restrict;

create index billing_businesses_license_idx on public.billing_businesses(license_id) where license_id is not null;

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
  v_actor_id uuid;
  v_customer_name text;
  v_customer_phone text;
  v_customer_email text;
  v_customer_address text;
  v_customer_gstin text;
begin
  if auth.role() <> 'service_role' and not public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]) then raise exception 'Insufficient permissions'; end if;
  if p_quantity <= 0 then raise exception 'Quantity must be positive'; end if;
  select * into v_business from public.billing_businesses where id = p_business_id and status = 'ACTIVE' and case when auth.role() = 'service_role' then true else created_by = auth.uid() end for update;
  if not found then raise exception 'Billing business not found'; end if;
  if auth.role() = 'service_role' then v_actor_id := v_business.created_by; else v_actor_id := auth.uid(); end if;
  select * into v_product from public.billing_products where id = p_product_id and business_id = p_business_id and status = 'ACTIVE' for update;
  if not found then raise exception 'Product not found'; end if;
  if v_product.stock_quantity < p_quantity then raise exception 'Insufficient stock'; end if;
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
  v_invoice_number := v_business.invoice_prefix || '-' || lpad(v_business.next_invoice_number::text, 6, '0');
  v_subtotal := round(v_product.price_in_paise * p_quantity)::bigint;
  v_tax := round(v_subtotal * v_product.tax_rate_basis_points / 10000.0)::bigint;
  insert into public.billing_invoices (business_id, customer_id, customer_name, customer_phone, customer_email, customer_address, customer_gstin, invoice_number, due_at, subtotal_in_paise, tax_in_paise, notes, created_by)
  values (p_business_id, p_customer_id, v_customer_name, v_customer_phone, v_customer_email, v_customer_address, v_customer_gstin, v_invoice_number, p_due_at, v_subtotal, v_tax, coalesce(p_notes, ''), v_actor_id) returning id into v_invoice_id;
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
  v_business public.billing_businesses;
  v_invoice public.billing_invoices;
  v_paid bigint;
  v_payment_id uuid;
  v_actor_id uuid;
begin
  if auth.role() <> 'service_role' and not public.is_active_admin(array['OWNER','ADMIN','SUPPORT']::public.admin_role[]) then raise exception 'Insufficient permissions'; end if;
  if p_amount_in_paise <= 0 then raise exception 'Payment must be positive'; end if;
  select * into v_business from public.billing_businesses where id = p_business_id and status = 'ACTIVE' and case when auth.role() = 'service_role' then true else created_by = auth.uid() end;
  if not found then raise exception 'Billing business not found'; end if;
  if auth.role() = 'service_role' then v_actor_id := v_business.created_by; else v_actor_id := auth.uid(); end if;
  select * into v_invoice from public.billing_invoices where id = p_invoice_id and business_id = p_business_id and status not in ('CANCELLED','PAID') for update;
  if not found then raise exception 'Payable invoice not found'; end if;
  select coalesce(sum(amount_in_paise), 0) into v_paid from public.billing_payments where invoice_id = p_invoice_id;
  if v_paid + p_amount_in_paise > v_invoice.total_in_paise then raise exception 'Payment exceeds outstanding balance'; end if;
  insert into public.billing_payments (business_id, invoice_id, amount_in_paise, method, reference, notes, created_by)
  values (p_business_id, p_invoice_id, p_amount_in_paise, p_method, nullif(trim(p_reference), ''), coalesce(p_notes, ''), v_actor_id) returning id into v_payment_id;
  update public.billing_invoices set status = case when v_paid + p_amount_in_paise = total_in_paise then 'PAID'::public.billing_invoice_status else 'PARTIALLY_PAID'::public.billing_invoice_status end where id = p_invoice_id;
  return v_payment_id;
end; $$;

grant execute on function public.create_billing_invoice(uuid, uuid, uuid, numeric, timestamptz, text, text, text) to service_role;
grant execute on function public.record_billing_payment(uuid, uuid, bigint, public.billing_payment_method, text, text) to service_role;
