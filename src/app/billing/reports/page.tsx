import { IndianRupee, ReceiptText, Scale, WalletCards } from "lucide-react";
import { BillingReportControls } from "@/components/billing-report-controls";
import { PageHeader, StatusBadge } from "@/components/ui";
import { WorkspaceRequired } from "@/components/workspace-required";
import { getBillingReport } from "@/data/billing";
import { formatDate, formatMoney } from "@/lib/format";
import { getBillingAccess } from "@/lib/billing-access";

function dateValue(date: Date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

function validDate(value: string | string[] | undefined) {
  const candidate = typeof value === "string" ? value : "";
  if (!/^\d{4}-\d{2}-\d{2}$/.test(candidate)) return "";
  const parsed = new Date(`${candidate}T00:00:00`);
  return Number.isNaN(parsed.getTime()) || dateValue(parsed) !== candidate ? "" : candidate;
}

export default async function Page({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const access = await getBillingAccess();
  if (access?.kind === "license" && !access.allowReportsExports) return <div className="space-y-7"><PageHeader eyebrow="Plan capability" title="Reports & Exports" description="This feature is not included in your current plan." /><p className="surface p-6 text-sm leading-6 text-[#667085]">Upgrade your plan and validate the new activation to access business reports and supported exports.</p></div>;

  const query = await searchParams;
  const today = new Date();
  const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
  let from = validDate(query.from) || dateValue(monthStart);
  let to = validDate(query.to) || dateValue(today);
  if (from > to) [from, to] = [to, from];

  const report = await getBillingReport({ from, to });
  if (!report) return <div className="space-y-7"><PageHeader eyebrow="Billing desk" title="Reports" description="Set up a workspace to generate reports." /><WorkspaceRequired /></div>;

  const cards = [["Sales", formatMoney(report.salesInPaise), IndianRupee], ["Tax collected", formatMoney(report.taxInPaise), Scale], ["Payments received", formatMoney(report.paymentsInPaise), WalletCards], ["Invoices issued", String(report.invoiceCount), ReceiptText]] as const;
  const rangeLabel = `${formatDate(`${from}T00:00:00`)} – ${formatDate(`${to}T00:00:00`)}`;

  return <div className="space-y-7">
    <PageHeader eyebrow={report.business.companyName} title="Reports & Exports" description={`Live billing summary for ${rangeLabel}. Cancelled invoices are excluded from sales and tax totals.`} />
    <BillingReportControls from={from} to={to} invoices={report.invoices} />
    <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{cards.map(([label, value, Icon]) => <article key={label} className="surface p-5"><span className="grid size-10 place-items-center bg-[#e6f2f0] text-[#057c73]"><Icon size={20} /></span><p className="mt-5 text-sm text-[#667085]">{label}</p><strong className="mt-1 block text-2xl">{value}</strong></article>)}</section>
    <section className="grid gap-5 xl:grid-cols-[minmax(0,2fr)_minmax(260px,1fr)]">
      <div className="surface overflow-hidden">
        <div className="border-b border-[#eef0f4] px-6 py-4"><h2 className="text-lg">Invoice details</h2><p className="mt-1 text-xs text-[#667085]">{rangeLabel}</p></div>
        <div className="overflow-x-auto"><table className="w-full min-w-[860px] text-left text-sm"><thead className="bg-[#fafbfc] text-[11px] uppercase tracking-wide text-[#98a2b3]"><tr>{["Invoice", "Customer", "Issued", "Subtotal", "Tax", "Total", "Status"].map((heading) => <th key={heading} className="px-5 py-3">{heading}</th>)}</tr></thead><tbody className="divide-y divide-[#eef0f4]">{report.invoices.map((invoice) => <tr key={invoice.id}><td className="px-5 py-4 font-mono text-xs font-semibold text-[#057c73]">{invoice.invoiceNumber}</td><td className="px-5 py-4 font-semibold">{invoice.customerName}</td><td className="px-5 py-4 text-[#667085]">{formatDate(invoice.issuedAt)}</td><td className="px-5 py-4">{formatMoney(invoice.subtotalInPaise)}</td><td className="px-5 py-4">{formatMoney(invoice.taxInPaise)}</td><td className="px-5 py-4 font-semibold">{formatMoney(invoice.totalInPaise)}</td><td className="px-5 py-4"><StatusBadge status={invoice.status} /></td></tr>)}</tbody></table></div>
        {!report.invoices.length ? <p className="p-10 text-center text-sm text-[#667085]">No invoices found in this date range.</p> : null}
      </div>
      <aside className="surface self-start p-5"><h2 className="text-lg">Payments by method</h2><div className="mt-4 divide-y divide-[#eef0f4]">{report.paymentMethods.map((payment) => <div key={payment.method} className="flex items-center justify-between gap-4 py-3 text-sm"><span className="capitalize text-[#667085]">{payment.method.replaceAll("_", " ").toLowerCase()}</span><strong>{formatMoney(payment.amountInPaise)}</strong></div>)}</div>{!report.paymentMethods.length ? <p className="mt-4 text-sm text-[#667085]">No payments received in this date range.</p> : null}</aside>
    </section>
  </div>;
}
