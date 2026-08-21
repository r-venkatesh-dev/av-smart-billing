-- Additive mobile Online Mode support. Existing desktop/web billing behavior is
-- unchanged; clients that do not use this column continue to receive 0%.
alter table public.billing_products
  add column if not exists discount_percent numeric(5,2) not null default 0
  check (discount_percent between 0 and 100);

comment on column public.billing_products.discount_percent is
  'Default line discount suggested by mobile and other POS clients.';
