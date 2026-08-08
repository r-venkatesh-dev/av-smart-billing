import { PageHeader, StatusBadge } from "@/components/ui";
import { WorkspaceRequired } from "@/components/workspace-required";
import { listBillingCustomers } from "@/data/billing";
import { formatDate } from "@/lib/format";

export default async function Page() {
  const { business, customers } = await listBillingCustomers();
  if (!business) return <div className="space-y-7"><PageHeader eyebrow="Billing desk" title="Customers" description="Set up a workspace before adding billing customers." /><WorkspaceRequired /></div>;
  return <div className="space-y-7"><PageHeader eyebrow={business.companyName} title="Customers" description="Customer records stored in your billing workspace." actionLabel="Add customer" actionHref="/billing/customers/new" /><div className="surface overflow-hidden"><div className="overflow-x-auto"><table className="w-full min-w-[760px] text-left text-sm"><thead className="bg-[#fafbfc] text-[11px] uppercase tracking-wide text-[#98a2b3]"><tr>{["Customer", "Contact", "GSTIN", "Invoices", "Added", "Status"].map((heading) => <th key={heading} className="px-6 py-3">{heading}</th>)}</tr></thead><tbody className="divide-y divide-[#eef0f4]">{customers.map((customer) => <tr key={customer.id}><td className="px-6 py-4 font-semibold">{customer.name}</td><td className="px-6 py-4 text-[#667085]">{customer.phone || customer.email || "—"}</td><td className="px-6 py-4 font-mono text-xs text-[#667085]">{customer.gstin ?? "—"}</td><td className="px-6 py-4 text-[#667085]">{customer.invoiceCount}</td><td className="px-6 py-4 text-[#667085]">{formatDate(customer.createdAt)}</td><td className="px-6 py-4"><StatusBadge status={customer.status} /></td></tr>)}</tbody></table></div>{!customers.length ? <p className="p-10 text-center text-sm text-[#667085]">No billing customers yet.</p> : null}</div></div>;
}
