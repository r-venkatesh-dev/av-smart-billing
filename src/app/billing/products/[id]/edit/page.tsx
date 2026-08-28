import { notFound } from "next/navigation";
import { BillingProductForm } from "@/components/billing-forms";
import { PageHeader } from "@/components/ui";
import { getBillingProduct } from "@/data/billing";

export default async function Page({ params }: PageProps<"/billing/products/[id]/edit">) {
  const { id } = await params;
  const { business, product } = await getBillingProduct(id);
  if (!business || !product) notFound();
  return <div className="space-y-7"><PageHeader backHref="/billing/products" eyebrow={business.companyName} title={`Edit ${product.name}`} description="Current product values are loaded directly from Supabase. Review them before saving." /><BillingProductForm key={product.id} product={product} /></div>;
}
