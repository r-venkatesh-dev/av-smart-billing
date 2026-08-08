"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { getBillingBusiness } from "@/data/billing";
import { requireAdminRole } from "@/lib/auth/authorization";
import { createBillingDataClient, requireBillingAccess } from "@/lib/billing-access";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { billingBusinessSchema, billingCustomerSchema, billingInvoiceSchema, billingPaymentSchema, billingProductSchema } from "@/lib/validation/billing";
import { percentToBasisPoints, rupeesToPaise } from "@/lib/money";

export interface BillingFormState { message?: string; errors?: Record<string, string[]> }

function fields(formData: FormData, names: string[]) {
  return Object.fromEntries(names.map((name) => [name, formData.get(name)]));
}

export async function createBillingBusiness(_state: BillingFormState, formData: FormData): Promise<BillingFormState> {
  const profile = await requireAdminRole(["OWNER", "ADMIN"]);
  const parsed = billingBusinessSchema.safeParse(fields(formData, ["companyName", "contactPerson", "email", "phone", "address", "gstin", "currencyCode", "invoicePrefix", "lowStockThreshold"]));
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.from("billing_businesses").insert({ created_by: profile.id, company_name: parsed.data.companyName, contact_person: parsed.data.contactPerson, email: parsed.data.email || null, phone: parsed.data.phone, address: parsed.data.address, gstin: parsed.data.gstin || null, currency_code: parsed.data.currencyCode, invoice_prefix: parsed.data.invoicePrefix, low_stock_threshold: parsed.data.lowStockThreshold });
  if (error) return { message: error.message };
  redirect("/billing/dashboard");
}

export async function updateBillingBusiness(_state: BillingFormState, formData: FormData): Promise<BillingFormState> {
  await requireBillingAccess(["OWNER", "ADMIN"]);
  const business = await getBillingBusiness();
  if (!business) return { message: "Create a billing workspace first." };
  const parsed = billingBusinessSchema.safeParse(fields(formData, ["companyName", "contactPerson", "email", "phone", "address", "gstin", "currencyCode", "invoicePrefix", "lowStockThreshold"]));
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  const supabase = await createBillingDataClient();
  const { error } = await supabase.from("billing_businesses").update({ company_name: parsed.data.companyName, contact_person: parsed.data.contactPerson, email: parsed.data.email || null, phone: parsed.data.phone, address: parsed.data.address, gstin: parsed.data.gstin || null, currency_code: parsed.data.currencyCode, invoice_prefix: parsed.data.invoicePrefix, low_stock_threshold: parsed.data.lowStockThreshold }).eq("id", business.id);
  if (error) return { message: error.message };
  redirect("/billing/settings?saved=1");
}

export async function createBillingCustomer(_state: BillingFormState, formData: FormData): Promise<BillingFormState> {
  await requireBillingAccess(["OWNER", "ADMIN", "SUPPORT"]);
  const business = await getBillingBusiness();
  if (!business) return { message: "Create a billing workspace first." };
  const parsed = billingCustomerSchema.safeParse(fields(formData, ["name", "email", "phone", "address", "gstin"]));
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  const supabase = await createBillingDataClient();
  const { error } = await supabase.from("billing_customers").insert({ business_id: business.id, name: parsed.data.name, email: parsed.data.email || null, phone: parsed.data.phone, address: parsed.data.address, gstin: parsed.data.gstin || null });
  if (error) return { message: error.message };
  redirect("/billing/customers");
}

export async function createBillingProduct(_state: BillingFormState, formData: FormData): Promise<BillingFormState> {
  await requireBillingAccess(["OWNER", "ADMIN", "SUPPORT"]);
  const business = await getBillingBusiness();
  if (!business) return { message: "Create a billing workspace first." };
  const parsed = billingProductSchema.safeParse(fields(formData, ["name", "sku", "description", "unit", "priceInRupees", "taxRatePercent", "stockQuantity", "status"]));
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  const supabase = await createBillingDataClient();
  const { error } = await supabase.from("billing_products").insert({ business_id: business.id, name: parsed.data.name, sku: parsed.data.sku, description: parsed.data.description, unit: parsed.data.unit, price_in_paise: rupeesToPaise(parsed.data.priceInRupees), tax_rate_basis_points: percentToBasisPoints(parsed.data.taxRatePercent), stock_quantity: parsed.data.stockQuantity, status: parsed.data.status });
  if (error) return { message: error.message };
  redirect("/billing/products");
}

export async function updateBillingProduct(id: string, _state: BillingFormState, formData: FormData): Promise<BillingFormState> {
  await requireBillingAccess(["OWNER", "ADMIN", "SUPPORT"]);
  const business = await getBillingBusiness();
  if (!business) return { message: "Create a billing workspace first." };
  const parsed = billingProductSchema.safeParse(fields(formData, ["name", "sku", "description", "unit", "priceInRupees", "taxRatePercent", "stockQuantity", "status"]));
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  const supabase = await createBillingDataClient();
  const { error } = await supabase.from("billing_products").update({ name: parsed.data.name, sku: parsed.data.sku, description: parsed.data.description, unit: parsed.data.unit, price_in_paise: rupeesToPaise(parsed.data.priceInRupees), tax_rate_basis_points: percentToBasisPoints(parsed.data.taxRatePercent), stock_quantity: parsed.data.stockQuantity, status: parsed.data.status }).eq("id", id).eq("business_id", business.id);
  if (error) return { message: error.message };
  redirect("/billing/products");
}

export interface DeleteProductResult {
  ok: boolean;
  mode?: "deleted" | "archived";
  message: string;
}

export async function deleteBillingProduct(id: string): Promise<DeleteProductResult> {
  await requireBillingAccess(["OWNER", "ADMIN"]);
  const business = await getBillingBusiness();
  if (!business) return { ok: false, message: "Billing workspace not found." };
  const supabase = await createBillingDataClient();
  const product = await supabase.from("billing_products").select("id, name").eq("id", id).eq("business_id", business.id).maybeSingle();
  if (product.error) return { ok: false, message: product.error.message };
  if (!product.data) return { ok: false, message: "Product not found." };

  const references = await supabase.from("billing_invoice_items").select("id", { count: "exact", head: true }).eq("product_id", id);
  if (references.error) return { ok: false, message: references.error.message };

  let mode: "deleted" | "archived";
  if ((references.count ?? 0) > 0) {
    const archived = await supabase.from("billing_products").update({ status: "INACTIVE" }).eq("id", id).eq("business_id", business.id);
    if (archived.error) return { ok: false, message: archived.error.message };
    mode = "archived";
  } else {
    const removed = await supabase.from("billing_products").delete().eq("id", id).eq("business_id", business.id);
    if (removed.error) {
      if (removed.error.code !== "23503") return { ok: false, message: removed.error.message };
      const archived = await supabase.from("billing_products").update({ status: "INACTIVE" }).eq("id", id).eq("business_id", business.id);
      if (archived.error) return { ok: false, message: archived.error.message };
      mode = "archived";
    } else {
      mode = "deleted";
    }
  }
  revalidatePath("/billing/products");
  revalidatePath("/billing/invoices/new");
  return { ok: true, mode, message: mode === "deleted" ? `${product.data.name} was permanently deleted.` : `${product.data.name} is used by an invoice, so it was archived safely.` };
}

export async function createBillingInvoice(_state: BillingFormState, formData: FormData): Promise<BillingFormState> {
  await requireBillingAccess(["OWNER", "ADMIN", "SUPPORT"]);
  const business = await getBillingBusiness();
  if (!business) return { message: "Create a billing workspace first." };
  const parsed = billingInvoiceSchema.safeParse(fields(formData, ["customerId", "walkInName", "walkInPhone", "productId", "quantity", "dueAt", "notes"]));
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  const supabase = await createBillingDataClient();
  const dueAt = parsed.data.dueAt ? new Date(`${parsed.data.dueAt}T23:59:59`).toISOString() : null;
  const walkIn = parsed.data.customerId === "WALK_IN";
  const { data: invoiceId, error } = await supabase.rpc("create_billing_invoice", { p_business_id: business.id, p_customer_id: walkIn ? null : parsed.data.customerId, p_product_id: parsed.data.productId, p_quantity: parsed.data.quantity, p_due_at: dueAt, p_notes: parsed.data.notes, p_walk_in_name: walkIn ? parsed.data.walkInName : null, p_walk_in_phone: walkIn ? parsed.data.walkInPhone : null });
  if (error) return { message: error.message };
  redirect(`/billing/invoices/${invoiceId}`);
}

export async function createBillingPayment(_state: BillingFormState, formData: FormData): Promise<BillingFormState> {
  await requireBillingAccess(["OWNER", "ADMIN", "SUPPORT"]);
  const business = await getBillingBusiness();
  if (!business) return { message: "Create a billing workspace first." };
  const parsed = billingPaymentSchema.safeParse(fields(formData, ["invoiceId", "amountInRupees", "method", "reference", "notes"]));
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  const supabase = await createBillingDataClient();
  const { error } = await supabase.rpc("record_billing_payment", { p_business_id: business.id, p_invoice_id: parsed.data.invoiceId, p_amount_in_paise: rupeesToPaise(parsed.data.amountInRupees), p_method: parsed.data.method, p_reference: parsed.data.reference || null, p_notes: parsed.data.notes });
  if (error) return { message: error.message };
  redirect(`/billing/invoices/${parsed.data.invoiceId}`);
}
