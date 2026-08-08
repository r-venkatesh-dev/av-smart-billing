import { PageHeader } from "@/components/ui";
import { WorkspaceRequired } from "@/components/workspace-required";
import { listBillingPayments } from "@/data/billing";
import { formatDate, formatMoney } from "@/lib/format";

export default async function Page() {
  const { business, payments } = await listBillingPayments();
  if (!business) return <div className="space-y-7"><PageHeader eyebrow="Billing desk" title="Payments" description="Set up a workspace before recording payments." /><WorkspaceRequired /></div>;
  return <div className="space-y-7"><PageHeader eyebrow={business.companyName} title="Payments" description="Receipts reconciled against billing invoices." actionLabel="Record payment" actionHref="/billing/payments/new" /><div className="surface overflow-hidden"><div className="overflow-x-auto"><table className="w-full min-w-[760px] text-left text-sm"><thead className="bg-[#fafbfc] text-[11px] uppercase tracking-wide text-[#98a2b3]"><tr>{["Date", "Invoice", "Customer", "Method", "Reference", "Amount"].map((heading) => <th key={heading} className="px-6 py-3">{heading}</th>)}</tr></thead><tbody className="divide-y divide-[#eef0f4]">{payments.map((payment) => <tr key={payment.id}><td className="px-6 py-4 text-[#667085]">{formatDate(payment.paidAt)}</td><td className="px-6 py-4 font-mono text-xs font-semibold">{payment.invoiceNumber}</td><td className="px-6 py-4">{payment.customerName}</td><td className="px-6 py-4 text-[#667085]">{payment.method.replaceAll("_", " ")}</td><td className="px-6 py-4 text-[#667085]">{payment.reference ?? "—"}</td><td className="px-6 py-4 font-semibold text-emerald-700">{formatMoney(payment.amountInPaise)}</td></tr>)}</tbody></table></div>{!payments.length ? <p className="p-10 text-center text-sm text-[#667085]">No payments yet.</p> : null}</div></div>;
}
