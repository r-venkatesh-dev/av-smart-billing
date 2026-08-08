import Link from "next/link";
import {
  ArrowUpRight,
  IndianRupee,
  Package,
  Plus,
  ReceiptText,
  Users,
} from "lucide-react";
import { PageHeader, StatusBadge } from "@/components/ui";
import { WorkspaceRequired } from "@/components/workspace-required";
import { getBillingDashboard } from "@/data/billing";
import { formatDate, formatMoney } from "@/lib/format";

export const metadata = { title: "Billing dashboard" };

export default async function BillingDashboardPage() {
  const dashboard = await getBillingDashboard();
  if (!dashboard)
    return (
      <div className="space-y-7">
        <PageHeader
          eyebrow="Billing desk"
          title="Billing dashboard"
          description="Set up a business workspace to begin billing."
        />
        <WorkspaceRequired />
      </div>
    );
  const metrics = [
    [
      "Today’s sales",
      formatMoney(dashboard.todaysSalesInPaise),
      "Recorded today",
      IndianRupee,
    ],
    [
      "Invoices today",
      String(dashboard.todaysInvoiceCount),
      "Issued today",
      ReceiptText,
    ],
    ["Customers", String(dashboard.customerCount), "Active records", Users],
    [
      "Low stock items",
      String(dashboard.lowStockCount),
      "At or below threshold",
      Package,
    ],
  ] as const;
  return (
    <div className="space-y-5">
      <PageHeader
        eyebrow={dashboard.business.companyName}
        title="Billing dashboard"
        description="Live sales and counter activity from the browser billing store."
        actionLabel="Create invoice"
        actionHref="/billing/invoices/new"
      />

      <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {metrics.map(([label, value, hint, Icon]) => (
          <article key={label} className="surface p-5">
            <div className="flex items-center justify-between">
              <span className="grid size-10 place-items-center rounded-xl bg-indigo-50 text-indigo-600">
                <Icon size={20} />
              </span>
              <ArrowUpRight size={17} className="text-[#98a2b3]" />
            </div>
            <p className="mt-5 text-sm text-[#667085]">{label}</p>
            <strong className="mt-1 block text-2xl">{value}</strong>
            <small className="mt-1 block text-emerald-700">{hint}</small>
          </article>
        ))}
      </section>
      <div className="grid gap-5 xl:grid-cols-[1.45fr_.75fr]">
        <section className="surface overflow-hidden">
          <div className="flex items-center justify-between border-b border-[#eaecf0] px-6 py-5">
            <div>
              <h2 className="font-bold">Recent invoices</h2>
              <p className="mt-1 text-xs text-[#98a2b3]">
                Latest transactions stored in Supabase
              </p>
            </div>
            <Link
              href="/billing/invoices"
              className="text-xs font-bold text-[#5b4df5]"
            >
              View all
            </Link>
          </div>
          {dashboard.recentInvoices.length ? (
            <div className="divide-y divide-[#eef0f4]">
              {dashboard.recentInvoices.map((invoice) => (
                <div key={invoice.id} className="flex items-center gap-4 p-5">
                  <span className="grid size-10 place-items-center rounded-xl bg-[#f5f6fa] text-[#667085]">
                    <ReceiptText size={18} />
                  </span>
                  <span className="min-w-0 flex-1">
                    <strong className="block text-sm">
                      {invoice.customerName}
                    </strong>
                    <Link href={`/billing/invoices/${invoice.id}`} className="text-xs text-[#057c73] hover:underline">
                      {invoice.invoiceNumber} · {formatDate(invoice.issuedAt)}
                    </Link>
                  </span>
                  <strong className="text-sm">
                    {formatMoney(invoice.totalInPaise)}
                  </strong>
                  <StatusBadge status={invoice.status} />
                </div>
              ))}
            </div>
          ) : (
            <p className="p-8 text-center text-sm text-[#667085]">
              No invoices yet.
            </p>
          )}
        </section>
        <section className="surface p-6">
          <h2 className="font-bold">Quick actions</h2>
          <p className="mt-1 text-xs text-[#98a2b3]">Common billing tasks</p>
          <div className="mt-5 grid gap-3">
            {[
              ["New invoice", "/billing/invoices/new"],
              ["Add customer", "/billing/customers/new"],
              ["Add product", "/billing/products/new"],
              ["Record payment", "/billing/payments/new"],
            ].map(([label, href], index) => (
              <Link
                key={label}
                href={href}
                className={`focus-ring flex items-center justify-between rounded-xl border p-3.5 text-sm font-semibold ${index === 0 ? "border-[#5b4df5] bg-[#5b4df5] text-white" : "border-[#e0e4ec] text-[#475467] hover:bg-[#f8f8fb]"}`}
              >
                <span className="flex items-center gap-2">
                  <Plus size={16} />
                  {label}
                </span>
                <ArrowUpRight size={15} />
              </Link>
            ))}
          </div>
        </section>
      </div>
    </div>
  );
}
