-- Migration: 202610100001_new_user_discounts.sql
-- Description: Adds first-time customer discount configuration to subscription plans
--              and tracking columns to subscription orders.

-- 1. Add discount fields to public.plans
alter table public.plans
  add column if not exists new_user_discount_type text not null default 'NONE' check (new_user_discount_type in ('NONE', 'FLAT', 'PERCENTAGE')),
  add column if not exists new_user_discount_value numeric not null default 0 check (new_user_discount_value >= 0);

comment on column public.plans.new_user_discount_type is
  'Promotional discount type for first-time customers with a new mobile number: NONE, FLAT (rupees), or PERCENTAGE.';

comment on column public.plans.new_user_discount_value is
  'Value of promotional discount (amount in rupees for FLAT, or percentage 0-100 for PERCENTAGE).';

-- 2. Add discount auditing columns to public.subscription_orders
alter table public.subscription_orders
  add column if not exists discount_applied_in_paise bigint not null default 0,
  add column if not exists discount_notes text;

comment on column public.subscription_orders.discount_applied_in_paise is
  'Promotional discount subtracted from plan standard price for first-time customers.';
