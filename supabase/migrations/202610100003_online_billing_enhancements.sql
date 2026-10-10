-- Online Billing Enhancements:
-- 1. Make walk-in customer mobile number optional in create_billing_pos_sale (for Swiggy/Zomato/walk-ins).
-- 2. Support overall discount percent.

create or replace function public.create_billing_pos_sale(
  p_business_id uuid,
  p_customer_id uuid,
  p_walk_in_name text,
  p_walk_in_phone text,
  p_items jsonb,
  p_payment_method text,
  p_amount_received_in_paise bigint,
  p_reference text default null,
  p_tax_type text default 'INTRA_STATE',
  p_overall_discount_percent numeric default 0
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_business public.billing_businesses;
  v_customer public.billing_customers;
  v_product public.billing_products;
  v_actor_id uuid;
  v_invoice_id uuid := gen_random_uuid();
  v_payment_id uuid;
  v_invoice_number text;
  v_customer_name text;
  v_customer_phone text;
  v_customer_email text;
  v_customer_address text;
  v_customer_gstin text;
  v_item jsonb;
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
  v_overall_discount_ratio numeric := 0;
  v_overall_discount bigint := 0;
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
    v_customer_name := v_customer.name; v_customer_phone := coalesce(v_customer.phone, ''); v_customer_email := v_customer.email; v_customer_address := coalesce(v_customer.address, ''); v_customer_gstin := v_customer.gstin;
  else
    v_customer_name := trim(coalesce(p_walk_in_name, '')); v_customer_phone := trim(coalesce(p_walk_in_phone, ''));
    if char_length(v_customer_name) < 2 then v_customer_name := 'Walk-in Customer'; end if;
    if char_length(v_customer_phone) > 40 then raise exception 'Walk-in customer mobile number is too long'; end if;
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

  v_overall_discount_ratio := least(100.0, greatest(0.0, coalesce(p_overall_discount_percent, 0.0))) / 100.0;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select * into strict v_product from public.billing_products where id = (v_item->>'productId')::uuid and business_id = p_business_id;
    v_quantity := (v_item->>'quantity')::numeric;
    v_discount_percent := least(100, greatest(0, coalesce((v_item->>'discountPercent')::numeric, 0)));
    v_gross := round(v_product.price_in_paise * v_quantity)::bigint;
    v_discount := round(v_gross * v_discount_percent / 100.0)::bigint;
    v_taxable := v_gross - v_discount;
    if v_overall_discount_ratio > 0 then
      v_overall_discount := round(v_taxable * v_overall_discount_ratio)::bigint;
      v_discount := v_discount + v_overall_discount;
      v_taxable := v_taxable - v_overall_discount;
    end if;
    v_tax := round(v_taxable * v_product.tax_rate_basis_points / 10000.0)::bigint;
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
    if v_overall_discount_ratio > 0 then
      v_overall_discount := round(v_taxable * v_overall_discount_ratio)::bigint;
      v_discount := v_discount + v_overall_discount;
      v_taxable := v_taxable - v_overall_discount;
    end if;
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

revoke all on function public.create_billing_pos_sale(uuid,uuid,text,text,jsonb,text,bigint,text,text,numeric) from public, anon;
grant execute on function public.create_billing_pos_sale(uuid,uuid,text,text,jsonb,text,bigint,text,text,numeric) to authenticated, service_role;
