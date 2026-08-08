import { BillingBusinessForm } from "@/components/billing-forms";
import { PageHeader } from "@/components/ui";
import { getBillingBusiness } from "@/data/billing";

export default async function Page() {
  const business = await getBillingBusiness();
  return <div className="mx-auto max-w-4xl space-y-7"><PageHeader eyebrow="Billing desk" title={business ? "Business settings" : "Set up billing workspace"} description={business ? "Update the company identity, invoice numbering and stock policy stored in Supabase." : "Create the business profile that owns your operational billing data."} /><BillingBusinessForm business={business ?? undefined} /></div>;
}
