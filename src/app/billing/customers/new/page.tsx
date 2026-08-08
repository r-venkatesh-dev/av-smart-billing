import { BillingCustomerForm } from "@/components/billing-forms";
import { PageHeader } from "@/components/ui";
import { getBillingBusiness } from "@/data/billing";
import { redirect } from "next/navigation";

export default async function Page() {
  const business = await getBillingBusiness();
  if (!business) redirect("/billing/settings");
  return <div className="mx-auto max-w-4xl space-y-7"><PageHeader backHref="/billing/customers" eyebrow={business.companyName} title="Add customer" description="Create a billing customer in Supabase." /><BillingCustomerForm /></div>;
}
