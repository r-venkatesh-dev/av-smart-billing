import { AuthorizationError } from "@/lib/auth/authorization";
import { listAdminCustomers, listAdminDevices, listAdminLicenses, listAdminPlans } from "@/data/admin";
import { listBillingCustomers, listBillingInvoices, listBillingPayments, listBillingProducts } from "@/data/billing";

export const dynamic = "force-dynamic";

export type GlobalSearchResult = {
  id: string;
  type: string;
  title: string;
  subtitle: string;
  href: string;
};

const navigation = {
  admin: [
    ["Dashboard", "Platform overview and activity", "/admin/dashboard"],
    ["Customers", "Manage licensed customers", "/admin/customers"],
    ["Licenses", "Generate and manage licenses", "/admin/licenses"],
    ["Devices", "Review activated devices", "/admin/devices"],
    ["Plans", "Configure license plans", "/admin/plans"],
    ["Settings", "Platform and license settings", "/admin/settings"],
  ],
  billing: [
    ["Dashboard", "Billing overview", "/billing/dashboard"],
    ["Customers", "Manage billing customers", "/billing/customers"],
    ["Products", "Manage products and stock", "/billing/products"],
    ["Invoices", "View and create invoices", "/billing/invoices"],
    ["Payments", "Record and review payments", "/billing/payments"],
    ["Reports", "Billing and revenue reports", "/billing/reports"],
    ["Settings", "Business and invoice settings", "/billing/settings"],
  ],
} satisfies Record<"admin" | "billing", string[][]>;

function contains(query: string, ...values: Array<string | null | undefined>) {
  return values.some((value) => value?.toLocaleLowerCase().includes(query));
}

function navigationResults(mode: "admin" | "billing", query: string): GlobalSearchResult[] {
  return navigation[mode]
    .filter(([title, subtitle]) => contains(query, title, subtitle))
    .map(([title, subtitle, href]) => ({ id: `page-${href}`, type: "Page", title, subtitle, href }));
}

async function searchAdmin(query: string): Promise<GlobalSearchResult[]> {
  const [customers, licenses, devices, plans] = await Promise.all([
    listAdminCustomers(),
    listAdminLicenses(),
    listAdminDevices(),
    listAdminPlans(),
  ]);

  return [
    ...customers.filter((item) => contains(query, item.companyName, item.contactPerson, item.email, item.phone, item.gstin)).map((item) => ({
      id: `customer-${item.id}`,
      type: "Customer",
      title: item.companyName,
      subtitle: [item.contactPerson, item.email, item.phone].filter(Boolean).join(" · "),
      href: `/admin/customers/${item.id}`,
    })),
    ...licenses.filter((item) => contains(query, item.maskedKey, item.customerName, item.planName, item.status)).map((item) => ({
      id: `license-${item.id}`,
      type: "License",
      title: item.maskedKey,
      subtitle: `${item.customerName} · ${item.planName} · ${item.status}`,
      href: `/admin/licenses/${item.id}`,
    })),
    ...devices.filter((item) => contains(query, item.name, item.customerName, item.maskedKey, item.fingerprintPreview, item.status)).map((item) => ({
      id: `device-${item.id}`,
      type: "Device",
      title: item.name,
      subtitle: `${item.customerName} · ${item.status}`,
      href: "/admin/devices",
    })),
    ...plans.filter((item) => contains(query, item.name, item.description, item.status)).map((item) => ({
      id: `plan-${item.id}`,
      type: "Plan",
      title: item.name,
      subtitle: item.description || `${item.maxDevices} device plan`,
      href: `/admin/plans/${item.id}/edit`,
    })),
  ];
}

async function searchBilling(query: string): Promise<GlobalSearchResult[]> {
  const [customerResult, productResult, invoiceResult, paymentResult] = await Promise.all([
    listBillingCustomers(),
    listBillingProducts(),
    listBillingInvoices(),
    listBillingPayments(),
  ]);

  return [
    ...customerResult.customers.filter((item) => contains(query, item.name, item.email, item.phone, item.gstin, item.status)).map((item) => ({
      id: `customer-${item.id}`,
      type: "Customer",
      title: item.name,
      subtitle: [item.phone, item.email].filter(Boolean).join(" · ") || item.status,
      href: "/billing/customers",
    })),
    ...productResult.products.filter((item) => contains(query, item.name, item.sku, item.description, item.status)).map((item) => ({
      id: `product-${item.id}`,
      type: "Product",
      title: item.name,
      subtitle: `${item.sku} · ${item.status}`,
      href: `/billing/products/${item.id}/edit`,
    })),
    ...invoiceResult.invoices.filter((item) => contains(query, item.invoiceNumber, item.customerName, item.status)).map((item) => ({
      id: `invoice-${item.id}`,
      type: "Invoice",
      title: item.invoiceNumber,
      subtitle: `${item.customerName} · ${item.status}`,
      href: `/billing/invoices/${item.id}`,
    })),
    ...paymentResult.payments.filter((item) => contains(query, item.invoiceNumber, item.customerName, item.reference, item.method)).map((item) => ({
      id: `payment-${item.id}`,
      type: "Payment",
      title: item.invoiceNumber,
      subtitle: `${item.customerName} · ${item.method}${item.reference ? ` · ${item.reference}` : ""}`,
      href: "/billing/payments",
    })),
  ];
}

export async function GET(request: Request) {
  const url = new URL(request.url);
  const query = url.searchParams.get("q")?.trim().toLocaleLowerCase() ?? "";
  const mode = url.searchParams.get("mode");

  if (mode !== "admin" && mode !== "billing") return Response.json({ error: "Invalid workspace" }, { status: 400 });
  if (query.length < 2) return Response.json({ results: [] satisfies GlobalSearchResult[] });

  try {
    const records = mode === "admin" ? await searchAdmin(query) : await searchBilling(query);
    const results = [...navigationResults(mode, query), ...records].slice(0, 12);
    return Response.json({ results }, { headers: { "Cache-Control": "no-store" } });
  } catch (error) {
    if (error instanceof AuthorizationError) return Response.json({ error: error.message }, { status: error.status });
    console.error("Global search failed", error);
    return Response.json({ error: "Search is temporarily unavailable" }, { status: 500 });
  }
}
