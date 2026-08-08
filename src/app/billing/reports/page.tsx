import { IndianRupee, ReceiptText, Scale, WalletCards } from "lucide-react";
import { PageHeader } from "@/components/ui";
import { WorkspaceRequired } from "@/components/workspace-required";
import { getBillingReport } from "@/data/billing";
import { formatMoney } from "@/lib/format";

export default async function Page() {
  const report = await getBillingReport();
  if (!report) return <div className="space-y-7"><PageHeader eyebrow="Billing desk" title="Reports" description="Set up a workspace to generate reports." /><WorkspaceRequired /></div>;
  const cards = [["Monthly sales", formatMoney(report.salesInPaise), IndianRupee], ["Tax collected", formatMoney(report.taxInPaise), Scale], ["Payments received", formatMoney(report.paymentsInPaise), WalletCards], ["Invoices issued", String(report.invoiceCount), ReceiptText]] as const;
  return <div className="space-y-7"><PageHeader eyebrow={report.business.companyName} title="Reports" description="Current-month totals calculated from live invoice and payment data." /><section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{cards.map(([label, value, Icon]) => <article key={label} className="surface p-5"><span className="grid size-10 place-items-center bg-[#e6f2f0] text-[#057c73]"><Icon size={20} /></span><p className="mt-5 text-sm text-[#667085]">{label}</p><strong className="mt-1 block text-2xl">{value}</strong></article>)}</section><p className="surface p-6 text-sm leading-6 text-[#667085]">These figures include the current calendar month. Cancelled invoices are excluded from sales and tax totals.</p></div>;
}
