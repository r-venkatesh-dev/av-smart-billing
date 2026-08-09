-- Follow-up for installations that already applied the v0.3.0 POS migration.
-- Unused products are deleted with their stock-only history. Products referenced
-- by invoices are hidden from the catalogue while invoice snapshots remain intact.

create or replace function public.delete_billing_product(p_business_id uuid, p_product_id uuid)
returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_product public.billing_products;
begin
  if auth.role() <> 'service_role' and not public.is_active_admin(array['OWNER','ADMIN']::public.admin_role[]) then raise exception 'Insufficient permissions'; end if;
  select p.* into v_product from public.billing_products p
    join public.billing_businesses b on b.id=p.business_id
    where p.id=p_product_id and p.business_id=p_business_id and case when auth.role()='service_role' then true else b.created_by=auth.uid() end
    for update of p;
  if not found then raise exception 'Product not found'; end if;
  if exists(select 1 from public.billing_invoice_items where product_id=p_product_id) then
    update public.billing_products set status='INACTIVE' where id=p_product_id;
    return 'archived';
  end if;
  delete from public.billing_stock_movements where product_id=p_product_id;
  delete from public.billing_products where id=p_product_id;
  return 'deleted';
end; $$;

revoke all on function public.delete_billing_product(uuid,uuid) from public, anon;
grant execute on function public.delete_billing_product(uuid,uuid) to authenticated, service_role;
