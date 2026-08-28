import { BillingBusinessForm } from "@/components/billing-forms";
import { PaymentQrSettings } from "@/components/payment-qr";
import { PageHeader } from "@/components/ui";
import { getBillingBusiness } from "@/data/billing";

export default async function Page() {
  const business = await getBillingBusiness();
  return <div className="space-y-7"><PageHeader eyebrow="Billing desk" title={business ? "Business settings" : "Set up billing workspace"} description={business ? "Update company details, invoice defaults and the shop payment QR code." : "Create the business profile that owns your operational billing data."} /><BillingBusinessForm business={business ?? undefined} />{business ? <PaymentQrSettings paymentQrUrl={business.paymentQrUrl} /> : null}</div>;
}
