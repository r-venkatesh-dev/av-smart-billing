import "server-only";

import { createBillingDataClient, requireBillingAccess } from "@/lib/billing-access";

function assertQuery<T>(data: T | null, error: { message: string } | null): T {
  if (error) throw new Error(`Supabase query failed: ${error.message}`);
  if (data === null) throw new Error("Supabase query returned no data");
  return data;
}

function one<T>(value: T | T[] | null): T | null {
  return Array.isArray(value) ? value[0] ?? null : value;
}

export async function getBillingBusiness() {
  const access = await requireBillingAccess();
  const supabase = await createBillingDataClient();
  let query = supabase
    .from("billing_businesses")
    .select("id, company_name, contact_person, email, phone, address, gstin, currency_code, invoice_prefix, next_invoice_number, low_stock_threshold, status, created_at")
    .eq("status", "ACTIVE")
    .order("created_at")
    .limit(1);
  query = access.kind === "license" ? query.eq("license_id", access.licenseId) : query.eq("created_by", access.actorId);
  const { data, error } = await query.maybeSingle();
  if (error) throw new Error(`Supabase query failed: ${error.message}`);
  if (!data) return null;
  return {
    id: data.id,
    companyName: data.company_name,
    contactPerson: data.contact_person,
    email: data.email,
    phone: data.phone,
    address: data.address,
    gstin: data.gstin,
    currencyCode: data.currency_code,
    invoicePrefix: data.invoice_prefix,
    nextInvoiceNumber: Number(data.next_invoice_number),
    lowStockThreshold: Number(data.low_stock_threshold),
  };
}

export async function listBillingCustomers() {
  const business = await getBillingBusiness();
  if (!business) return { business: null, customers: [] };
  const supabase = await createBillingDataClient();
  const { data, error } = await supabase
    .from("billing_customers")
    .select("id, name, email, phone, address, gstin, status, created_at, billing_invoices(count)")
    .eq("business_id", business.id)
    .order("created_at", { ascending: false });
  const customers = assertQuery(data, error).map((row) => ({
    id: row.id,
    name: row.name,
    email: row.email,
    phone: row.phone,
    address: row.address,
    gstin: row.gstin,
    status: row.status,
    createdAt: row.created_at,
    invoiceCount: one(row.billing_invoices)?.count ?? 0,
  }));
  return { business, customers };
}

export async function listBillingProducts() {
  const business = await getBillingBusiness();
  if (!business) return { business: null, products: [] };
  const supabase = await createBillingDataClient();
  const { data, error } = await supabase
    .from("billing_products")
    .select("id, name, sku, description, unit, price_in_paise, tax_rate_basis_points, stock_quantity, status, created_at")
    .eq("business_id", business.id)
    .order("name");
  const products = assertQuery(data, error).map((row) => ({
    id: row.id,
    name: row.name,
    sku: row.sku,
    description: row.description,
    unit: row.unit,
    priceInPaise: Number(row.price_in_paise),
    taxRateBasisPoints: row.tax_rate_basis_points,
    stockQuantity: Number(row.stock_quantity),
    status: row.status,
    createdAt: row.created_at,
  }));
  return { business, products };
}

export async function getBillingProduct(id: string) {
  const business = await getBillingBusiness();
  if (!business) return { business: null, product: null };
  const supabase = await createBillingDataClient();
  const { data, error } = await supabase
    .from("billing_products")
    .select("id, name, sku, description, unit, price_in_paise, tax_rate_basis_points, stock_quantity, status")
    .eq("id", id)
    .eq("business_id", business.id)
    .maybeSingle();
  if (error) throw new Error(`Supabase query failed: ${error.message}`);
  if (!data) return { business, product: null };
  return {
    business,
    product: {
      id: data.id,
      name: data.name,
      sku: data.sku,
      description: data.description ?? "",
      unit: data.unit,
      priceInPaise: Number(data.price_in_paise),
      taxRateBasisPoints: Number(data.tax_rate_basis_points),
      stockQuantity: Number(data.stock_quantity),
      status: data.status,
    },
  };
}

export async function listBillingInvoices(limit?: number) {
  const business = await getBillingBusiness();
  if (!business) return { business: null, invoices: [] };
  const supabase = await createBillingDataClient();
  let query = supabase
    .from("billing_invoices")
    .select("id, invoice_number, customer_name, issued_at, due_at, status, subtotal_in_paise, tax_in_paise, total_in_paise, notes, billing_payments(amount_in_paise)")
    .eq("business_id", business.id)
    .order("issued_at", { ascending: false });
  if (limit) query = query.limit(limit);
  const { data, error } = await query;
  const invoices = assertQuery(data, error).map((row) => ({
    id: row.id,
    invoiceNumber: row.invoice_number,
    customerName: row.customer_name,
    issuedAt: row.issued_at,
    dueAt: row.due_at,
    status: row.status,
    subtotalInPaise: Number(row.subtotal_in_paise),
    taxInPaise: Number(row.tax_in_paise),
    totalInPaise: Number(row.total_in_paise),
    paidInPaise: (row.billing_payments ?? []).reduce((sum, payment) => sum + Number(payment.amount_in_paise), 0),
    notes: row.notes,
  }));
  return { business, invoices };
}

export async function getBillingInvoice(id: string) {
  const business = await getBillingBusiness();
  if (!business) return { business: null, invoice: null };
  const supabase = await createBillingDataClient();
  const { data, error } = await supabase
    .from("billing_invoices")
    .select("id, invoice_number, customer_name, customer_email, customer_phone, customer_address, customer_gstin, issued_at, due_at, status, subtotal_in_paise, tax_in_paise, total_in_paise, notes, billing_invoice_items(id, description, quantity, unit_price_in_paise, tax_rate_basis_points, line_subtotal_in_paise, line_tax_in_paise, billing_products(sku, unit)), billing_payments(id, amount_in_paise, method, reference, paid_at, notes)")
    .eq("id", id)
    .eq("business_id", business.id)
    .maybeSingle();
  if (error) throw new Error(`Supabase query failed: ${error.message}`);
  if (!data) return { business, invoice: null };
  const items = (data.billing_invoice_items ?? []).map((item) => {
    const product = one(item.billing_products);
    return {
      id: item.id,
      description: item.description,
      sku: product?.sku ?? "—",
      unit: product?.unit ?? "unit",
      quantity: Number(item.quantity),
      unitPriceInPaise: Number(item.unit_price_in_paise),
      taxRateBasisPoints: Number(item.tax_rate_basis_points),
      subtotalInPaise: Number(item.line_subtotal_in_paise),
      taxInPaise: Number(item.line_tax_in_paise),
    };
  });
  const payments = (data.billing_payments ?? [])
    .map((payment) => ({
      id: payment.id,
      amountInPaise: Number(payment.amount_in_paise),
      method: payment.method,
      reference: payment.reference,
      paidAt: payment.paid_at,
      notes: payment.notes,
    }))
    .sort((a, b) => b.paidAt.localeCompare(a.paidAt));
  const paidInPaise = payments.reduce((sum, payment) => sum + payment.amountInPaise, 0);
  return {
    business,
    invoice: {
      id: data.id,
      invoiceNumber: data.invoice_number,
      issuedAt: data.issued_at,
      dueAt: data.due_at,
      status: data.status,
      subtotalInPaise: Number(data.subtotal_in_paise),
      taxInPaise: Number(data.tax_in_paise),
      totalInPaise: Number(data.total_in_paise),
      paidInPaise,
      balanceInPaise: Math.max(0, Number(data.total_in_paise) - paidInPaise),
      notes: data.notes,
      customer: {
        name: data.customer_name,
        email: data.customer_email,
        phone: data.customer_phone,
        address: data.customer_address,
        gstin: data.customer_gstin,
      },
      items,
      payments,
    },
  };
}

export async function listBillingPayments() {
  const business = await getBillingBusiness();
  if (!business) return { business: null, payments: [] };
  const supabase = await createBillingDataClient();
  const { data, error } = await supabase
    .from("billing_payments")
    .select("id, amount_in_paise, method, reference, paid_at, notes, billing_invoices(invoice_number, customer_name)")
    .eq("business_id", business.id)
    .order("paid_at", { ascending: false });
  const payments = assertQuery(data, error).map((row) => {
    const invoice = one(row.billing_invoices);
    return {
      id: row.id,
      amountInPaise: Number(row.amount_in_paise),
      method: row.method,
      reference: row.reference,
      paidAt: row.paid_at,
      notes: row.notes,
      invoiceNumber: invoice?.invoice_number ?? "Unknown invoice",
      customerName: invoice?.customer_name ?? "Unknown customer",
    };
  });
  return { business, payments };
}

export async function getBillingDashboard() {
  const business = await getBillingBusiness();
  if (!business) return null;
  const supabase = await createBillingDataClient();
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(end.getDate() + 1);

  const [invoiceResult, customerResult, productResult] = await Promise.all([
    supabase.from("billing_invoices").select("id, invoice_number, customer_name, issued_at, status, total_in_paise").eq("business_id", business.id).order("issued_at", { ascending: false }).limit(8),
    supabase.from("billing_customers").select("id", { count: "exact", head: true }).eq("business_id", business.id).eq("status", "ACTIVE"),
    supabase.from("billing_products").select("id, stock_quantity").eq("business_id", business.id).eq("status", "ACTIVE").lte("stock_quantity", business.lowStockThreshold),
  ]);
  if (invoiceResult.error) throw new Error(`Supabase query failed: ${invoiceResult.error.message}`);
  if (customerResult.error) throw new Error(`Supabase query failed: ${customerResult.error.message}`);
  if (productResult.error) throw new Error(`Supabase query failed: ${productResult.error.message}`);

  const invoices = (invoiceResult.data ?? []).map((row) => ({
    id: row.id,
    invoiceNumber: row.invoice_number,
    issuedAt: row.issued_at,
    status: row.status,
    totalInPaise: Number(row.total_in_paise),
    customerName: row.customer_name,
  }));
  const todaysInvoices = invoices.filter((invoice) => invoice.issuedAt >= start.toISOString() && invoice.issuedAt < end.toISOString());
  return {
    business,
    recentInvoices: invoices.slice(0, 5),
    todaysSalesInPaise: todaysInvoices.filter((invoice) => invoice.status !== "CANCELLED").reduce((sum, invoice) => sum + invoice.totalInPaise, 0),
    todaysInvoiceCount: todaysInvoices.length,
    customerCount: customerResult.count ?? 0,
    lowStockCount: productResult.data?.length ?? 0,
  };
}

export async function getBillingReport() {
  const business = await getBillingBusiness();
  if (!business) return null;
  const supabase = await createBillingDataClient();
  const monthStart = new Date();
  monthStart.setDate(1);
  monthStart.setHours(0, 0, 0, 0);
  const [invoiceResult, paymentResult] = await Promise.all([
    supabase.from("billing_invoices").select("status, subtotal_in_paise, tax_in_paise, total_in_paise").eq("business_id", business.id).gte("issued_at", monthStart.toISOString()),
    supabase.from("billing_payments").select("amount_in_paise").eq("business_id", business.id).gte("paid_at", monthStart.toISOString()),
  ]);
  if (invoiceResult.error) throw new Error(`Supabase query failed: ${invoiceResult.error.message}`);
  if (paymentResult.error) throw new Error(`Supabase query failed: ${paymentResult.error.message}`);
  const invoices = invoiceResult.data ?? [];
  return {
    business,
    invoiceCount: invoices.length,
    salesInPaise: invoices.filter((row) => row.status !== "CANCELLED").reduce((sum, row) => sum + Number(row.total_in_paise), 0),
    taxInPaise: invoices.filter((row) => row.status !== "CANCELLED").reduce((sum, row) => sum + Number(row.tax_in_paise), 0),
    paymentsInPaise: (paymentResult.data ?? []).reduce((sum, row) => sum + Number(row.amount_in_paise), 0),
  };
}
