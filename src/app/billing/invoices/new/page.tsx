import { redirect } from "next/navigation";
import { BillingInvoiceForm } from "@/components/billing-forms";
import { PageHeader } from "@/components/ui";
import { listBillingCustomers, listBillingProducts } from "@/data/billing";

export default async function Page() {
  const [customerData, productData] = await Promise.all([listBillingCustomers(), listBillingProducts()]);
  if (!customerData.business || !productData.business) redirect("/billing/settings");
  return <div className="space-y-7"><PageHeader backHref="/billing/invoices" eyebrow={customerData.business.companyName} title="Create invoice" description="Search a saved customer or capture walk-in customer details for a traceable invoice." /><BillingInvoiceForm customers={customerData.customers.filter((customer) => customer.status === "ACTIVE").map(({ id, name, phone }) => ({ id, name, phone }))} products={productData.products.filter((product) => product.status === "ACTIVE").map(({ id, name, sku, stockQuantity }) => ({ id, name, sku, stockQuantity }))} /></div>;
}
