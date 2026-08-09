import { PageHeader } from "@/components/ui";
import { QuickPos } from "@/components/quick-pos";
import { listBillingCustomers, listBillingProducts } from "@/data/billing";

export default async function Page() {
  const [customerData, productData] = await Promise.all([listBillingCustomers(), listBillingProducts()]);
  const products = productData.products.filter((product) => product.status === "ACTIVE" && product.stockQuantity > 0).map(({ id, name, sku, barcode, category, unit, priceInPaise, taxRateBasisPoints, stockQuantity }) => ({ id, name, sku, barcode, category, unit, priceInPaise, taxRateBasisPoints, stockQuantity }));
  const customers = customerData.customers.filter((customer) => customer.status === "ACTIVE").map(({ id, name, phone }) => ({ id, name, phone }));
  return <div className="space-y-6"><PageHeader eyebrow={productData.business?.companyName ?? "Billing desk"} title="Quick POS" description="Barcode-first retail checkout with keyboard shortcuts, GST, payment and printing." /><div className="flex flex-wrap gap-2 text-[9px] font-bold uppercase tracking-[.08em] text-[#6d716f]"><span className="border border-[#dfe3e1] bg-white px-2 py-1">F2 Search</span><span className="border border-[#dfe3e1] bg-white px-2 py-1">F4 Customer</span><span className="border border-[#dfe3e1] bg-white px-2 py-1">F8 Payment</span><span className="border border-[#dfe3e1] bg-white px-2 py-1">F9 Pay &amp; print</span></div><QuickPos products={products} customers={customers} /></div>;
}
