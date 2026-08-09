"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { getBillingBusiness } from "@/data/billing";
import { requireAdminRole } from "@/lib/auth/authorization";
import { createBillingDataClient, requireBillingAccess } from "@/lib/billing-access";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { billingBusinessSchema, billingCustomerSchema, billingInvoiceSchema, billingPaymentSchema, billingPosSchema, billingProductSchema, billingStockAdjustmentSchema } from "@/lib/validation/billing";
import { percentToBasisPoints, rupeesToPaise } from "@/lib/money";

export interface BillingFormState { message?: string; errors?: Record<string, string[]> }

function fields(formData: FormData, names: string[]) {
  return Object.fromEntries(names.map((name) => [name, formData.get(name)]));
}

export async function createBillingBusiness(_state: BillingFormState, formData: FormData): Promise<BillingFormState> {
  const profile = await requireAdminRole(["OWNER", "ADMIN"]);
  const parsed = billingBusinessSchema.safeParse(fields(formData, ["companyName", "contactPerson", "email", "phone", "address", "gstin", "currencyCode", "invoicePrefix", "lowStockThreshold", "stateCode", "invoiceTerms", "invoiceFooter", "thermalPaperWidth"]));
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.from("billing_businesses").insert({ created_by: profile.id, company_name: parsed.data.companyName, contact_person: parsed.data.contactPerson, email: parsed.data.email || null, phone: parsed.data.phone, address: parsed.data.address, gstin: parsed.data.gstin || null, currency_code: parsed.data.currencyCode, invoice_prefix: parsed.data.invoicePrefix, low_stock_threshold: parsed.data.lowStockThreshold, state_code: parsed.data.stateCode, invoice_terms: parsed.data.invoiceTerms, invoice_footer: parsed.data.invoiceFooter, thermal_paper_width: parsed.data.thermalPaperWidth });
  if (error) return { message: error.message };
  redirect("/billing/dashboard");
}

export async function updateBillingBusiness(_state: BillingFormState, formData: FormData): Promise<BillingFormState> {
  await requireBillingAccess(["OWNER", "ADMIN"]);
  const business = await getBillingBusiness();
  if (!business) return { message: "Create a billing workspace first." };
  const parsed = billingBusinessSchema.safeParse(fields(formData, ["companyName", "contactPerson", "email", "phone", "address", "gstin", "currencyCode", "invoicePrefix", "lowStockThreshold", "stateCode", "invoiceTerms", "invoiceFooter", "thermalPaperWidth"]));
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  const supabase = await createBillingDataClient();
  const { error } = await supabase.from("billing_businesses").update({ company_name: parsed.data.companyName, contact_person: parsed.data.contactPerson, email: parsed.data.email || null, phone: parsed.data.phone, address: parsed.data.address, gstin: parsed.data.gstin || null, currency_code: parsed.data.currencyCode, invoice_prefix: parsed.data.invoicePrefix, low_stock_threshold: parsed.data.lowStockThreshold, state_code: parsed.data.stateCode, invoice_terms: parsed.data.invoiceTerms, invoice_footer: parsed.data.invoiceFooter, thermal_paper_width: parsed.data.thermalPaperWidth }).eq("id", business.id);
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
  const parsed = billingProductSchema.safeParse(fields(formData, ["name", "sku", "barcode", "category", "hsnSac", "description", "unit", "purchasePriceInRupees", "priceInRupees", "taxRatePercent", "stockQuantity", "lowStockThreshold", "status"]));
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  const supabase = await createBillingDataClient();
  const { data: product, error } = await supabase.from("billing_products").insert({ business_id: business.id, name: parsed.data.name, sku: parsed.data.sku, barcode: parsed.data.barcode || null, category: parsed.data.category, hsn_sac: parsed.data.hsnSac, description: parsed.data.description, unit: parsed.data.unit, purchase_price_in_paise: rupeesToPaise(parsed.data.purchasePriceInRupees), price_in_paise: rupeesToPaise(parsed.data.priceInRupees), tax_rate_basis_points: percentToBasisPoints(parsed.data.taxRatePercent), stock_quantity: parsed.data.stockQuantity, low_stock_threshold: parsed.data.lowStockThreshold, status: parsed.data.status }).select("id").single();
  if (error) return { message: error.message };
  if (parsed.data.stockQuantity > 0) {
    const movement = await supabase.from("billing_stock_movements").insert({ business_id: business.id, product_id: product.id, movement_type: "OPENING", quantity_change: parsed.data.stockQuantity, quantity_after: parsed.data.stockQuantity, reference_type: "PRODUCT", reference_id: product.id, notes: "Opening stock", created_by: (await requireBillingAccess()).actorId });
    if (movement.error) return { message: `Product created, but its opening stock history failed: ${movement.error.message}` };
  }
  redirect("/billing/products");
}

export async function updateBillingProduct(id: string, _state: BillingFormState, formData: FormData): Promise<BillingFormState> {
  await requireBillingAccess(["OWNER", "ADMIN", "SUPPORT"]);
  const business = await getBillingBusiness();
  if (!business) return { message: "Create a billing workspace first." };
  const parsed = billingProductSchema.safeParse(fields(formData, ["name", "sku", "barcode", "category", "hsnSac", "description", "unit", "purchasePriceInRupees", "priceInRupees", "taxRatePercent", "stockQuantity", "lowStockThreshold", "status"]));
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  const supabase = await createBillingDataClient();
  const previous = await supabase.from("billing_products").select("stock_quantity").eq("id", id).eq("business_id", business.id).single();
  if (previous.error) return { message: previous.error.message };
  const { error } = await supabase.from("billing_products").update({ name: parsed.data.name, sku: parsed.data.sku, barcode: parsed.data.barcode || null, category: parsed.data.category, hsn_sac: parsed.data.hsnSac, description: parsed.data.description, unit: parsed.data.unit, purchase_price_in_paise: rupeesToPaise(parsed.data.purchasePriceInRupees), price_in_paise: rupeesToPaise(parsed.data.priceInRupees), tax_rate_basis_points: percentToBasisPoints(parsed.data.taxRatePercent), stock_quantity: parsed.data.stockQuantity, low_stock_threshold: parsed.data.lowStockThreshold, status: parsed.data.status }).eq("id", id).eq("business_id", business.id);
  if (error) return { message: error.message };
  const stockChange = parsed.data.stockQuantity - Number(previous.data.stock_quantity);
  if (stockChange !== 0) {
    const access = await requireBillingAccess();
    const movement = await supabase.from("billing_stock_movements").insert({ business_id: business.id, product_id: id, movement_type: "ADJUSTMENT", quantity_change: stockChange, quantity_after: parsed.data.stockQuantity, reference_type: "PRODUCT", reference_id: id, notes: "Stock changed from product editor", created_by: access.actorId });
    if (movement.error) return { message: `Product updated, but stock history failed: ${movement.error.message}` };
  }
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

export async function createBillingPosSale(_state: BillingFormState, formData: FormData): Promise<BillingFormState> {
  await requireBillingAccess(["OWNER", "ADMIN", "SUPPORT"]);
  const business = await getBillingBusiness();
  if (!business) return { message: "Create a billing workspace first." };
  let payload: unknown;
  try { payload = JSON.parse(String(formData.get("payload") ?? "")); }
  catch { return { message: "The POS cart payload is invalid." }; }
  const parsed = billingPosSchema.safeParse(payload);
  if (!parsed.success) return { message: parsed.error.issues[0]?.message ?? "Review the POS sale details." };
  const supabase = await createBillingDataClient();
  const { data, error } = await supabase.rpc("create_billing_pos_sale", {
    p_business_id: business.id,
    p_customer_id: parsed.data.customerId,
    p_walk_in_name: parsed.data.walkInName,
    p_walk_in_phone: parsed.data.walkInPhone,
    p_items: parsed.data.items,
    p_payment_method: parsed.data.paymentMethod,
    p_amount_received_in_paise: rupeesToPaise(parsed.data.amountReceivedInRupees),
    p_reference: parsed.data.reference || null,
    p_tax_type: parsed.data.taxType,
  });
  if (error) return { message: error.message };
  const result = data as { invoiceId?: string } | null;
  if (!result?.invoiceId) return { message: "The sale completed without returning an invoice reference." };
  redirect(`/billing/invoices/${result.invoiceId}${formData.get("print") === "1" ? "?print=1" : ""}`);
}

export async function adjustBillingStock(_state: BillingFormState, formData: FormData): Promise<BillingFormState> {
  await requireBillingAccess(["OWNER", "ADMIN", "SUPPORT"]);
  const business = await getBillingBusiness();
  if (!business) return { message: "Create a billing workspace first." };
  const parsed = billingStockAdjustmentSchema.safeParse(fields(formData, ["productId", "movementType", "quantity", "reference", "notes"]));
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  const supabase = await createBillingDataClient();
  const { error } = await supabase.rpc("adjust_billing_stock", { p_business_id: business.id, p_product_id: parsed.data.productId, p_movement_type: parsed.data.movementType, p_quantity: parsed.data.quantity, p_reference: parsed.data.reference || null, p_notes: parsed.data.notes });
  if (error) return { message: error.message };
  revalidatePath("/billing/inventory");
  revalidatePath("/billing/products");
  return { message: "Stock movement recorded." };
}
