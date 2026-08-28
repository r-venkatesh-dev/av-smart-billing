import { redirect } from "next/navigation";
import { BillingProductForm } from "@/components/billing-forms";
import { PageHeader } from "@/components/ui";
import { getBillingBusiness } from "@/data/billing";

export default async function Page() {
  const business = await getBillingBusiness();
  if (!business) redirect("/billing/settings");
  return <div className="space-y-7"><PageHeader backHref="/billing/products" eyebrow={business.companyName} title="Add product" description="Create a product with pricing, tax and stock." /><BillingProductForm /></div>;
}
