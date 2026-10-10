-- Migration: 202610100002_dynamic_plan_offers.sql
-- Description: Adds dynamic multi-offers array (JSONB) to plans table and applied offer tracking to subscription_orders.

alter table public.plans
  add column if not exists offers jsonb not null default '[]'::jsonb;

comment on column public.plans.offers is
  'List of dynamic promotional offers for this plan: [{ id, name, type, value, isFirstTimeOnly }].';

alter table public.subscription_orders
  add column if not exists applied_offer_id text,
  add column if not exists applied_offer_name text;

comment on column public.subscription_orders.applied_offer_id is
  'ID of the specific dynamic offer chosen by the customer at checkout.';
