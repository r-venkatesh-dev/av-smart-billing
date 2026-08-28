import { redirect } from "next/navigation";
import { BillingPaymentForm } from "@/components/billing-forms";
import { PageHeader } from "@/components/ui";
import { listBillingInvoices } from "@/data/billing";

export default async function Page({ searchParams }: PageProps<"/billing/payments/new">) {
  const { invoiceId } = await searchParams;
  const { business, invoices } = await listBillingInvoices();
  if (!business) redirect("/billing/settings");
  const outstanding = invoices.filter((invoice) => !["PAID", "CANCELLED"].includes(invoice.status) && invoice.totalInPaise > invoice.paidInPaise).map((invoice) => ({ id: invoice.id, invoiceNumber: invoice.invoiceNumber, customerName: invoice.customerName, outstandingInPaise: invoice.totalInPaise - invoice.paidInPaise }));
  const selectedInvoiceId = typeof invoiceId === "string" && outstanding.some((invoice) => invoice.id === invoiceId) ? invoiceId : "";
  return <div className="space-y-7"><PageHeader backHref="/billing/payments" eyebrow={business.companyName} title="Record payment" description="Apply a receipt to an outstanding invoice." /><BillingPaymentForm invoices={outstanding} defaultInvoiceId={selectedInvoiceId} paymentQrUrl={business.paymentQrUrl} /></div>;
}
