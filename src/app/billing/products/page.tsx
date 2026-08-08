import { PageHeader, StatusBadge } from "@/components/ui";
import Link from "next/link";
import { ProductRowActions } from "@/components/product-row-actions";
import { WorkspaceRequired } from "@/components/workspace-required";
import { listBillingProducts } from "@/data/billing";
import { formatMoney } from "@/lib/format";

export default async function Page() {
  const { business, products } = await listBillingProducts();
  if (!business) return <div className="space-y-7"><PageHeader eyebrow="Billing desk" title="Products" description="Set up a workspace before adding products." /><WorkspaceRequired /></div>;
  return <div className="space-y-7"><PageHeader eyebrow={business.companyName} title="Products" description="Pricing, tax and stock records from Supabase." actionLabel="Add product" actionHref="/billing/products/new" /><div className="surface overflow-hidden"><div className="overflow-x-auto"><table className="w-full min-w-[980px] text-left text-sm"><thead className="bg-[#fafbfc] text-[11px] uppercase tracking-wide text-[#98a2b3]"><tr>{["Product", "SKU", "Price", "Tax", "Stock", "Status"].map((heading) => <th key={heading} className="px-6 py-3">{heading}</th>)}<th className="sticky right-0 bg-[#f7f8f7] px-6 py-3 text-right">Actions</th></tr></thead><tbody className="divide-y divide-[#eef0f4]">{products.map((product) => <tr key={product.id}><td className="px-6 py-4"><Link href={`/billing/products/${product.id}/edit`} className="font-semibold hover:text-[#057c73]">{product.name}</Link><small className="block text-[#98a2b3]">{product.description}</small></td><td className="px-6 py-4 font-mono text-xs">{product.sku}</td><td className="px-6 py-4">{formatMoney(product.priceInPaise)}</td><td className="px-6 py-4 text-[#667085]">{product.taxRateBasisPoints / 100}%</td><td className={`px-6 py-4 ${product.stockQuantity <= business.lowStockThreshold ? "font-semibold text-amber-700" : "text-[#667085]"}`}>{product.stockQuantity} {product.unit}</td><td className="px-6 py-4"><StatusBadge status={product.status} /></td><td className="sticky right-0 bg-white px-6 py-4"><ProductRowActions id={product.id} name={product.name} /></td></tr>)}</tbody></table></div>{!products.length ? <p className="p-10 text-center text-sm text-[#667085]">No products yet.</p> : null}</div></div>;
}
