import Link from "next/link";
import { CustomerRowActions } from "@/components/customer-row-actions";
import { PageHeader, StatusBadge } from "@/components/ui";
import { listAdminCustomers } from "@/data/admin";
import { requireAdminRole } from "@/lib/auth/authorization";
import { formatDate } from "@/lib/format";

export const metadata = { title: "Customers" };

export default async function CustomersPage() {
  const [customers, admin] = await Promise.all([listAdminCustomers(), requireAdminRole()]);
  const canEdit = admin.role !== "VIEWER";
  const canDelete = admin.role === "OWNER" || admin.role === "ADMIN";
  return <div className="space-y-7">
    <PageHeader eyebrow="Management" title="Customers" description="Manage every business using your billing platform." actionLabel="Add customer" actionHref="/admin/customers/new" />
    <div className="surface overflow-hidden">
      <div className="overflow-x-auto"><table className="w-full min-w-[1020px] text-left text-sm"><thead className="bg-[#fafbfc] text-[11px] uppercase tracking-wide text-[#98a2b3]"><tr>{["Company", "Contact", "GSTIN", "Licenses", "Joined", "Status"].map((heading) => <th key={heading} className="px-6 py-3 font-semibold">{heading}</th>)}<th className="sticky right-0 bg-[#f7f8f7] px-6 py-3 text-right font-semibold">Actions</th></tr></thead><tbody className="divide-y divide-[#eef0f4]">{customers.map((customer) => <tr key={customer.id} className="transition hover:bg-[#fafaff]"><td className="px-6 py-4"><Link href={`/admin/customers/${customer.id}`} className="font-semibold text-[#344054] hover:text-[#5b4df5]">{customer.companyName}</Link><span className="mt-0.5 block text-xs text-[#98a2b3]">{customer.email}</span></td><td className="px-6 py-4"><span className="font-medium text-[#475467]">{customer.contactPerson}</span><span className="mt-0.5 block text-xs text-[#98a2b3]">{customer.phone}</span></td><td className="px-6 py-4 font-mono text-xs text-[#667085]">{customer.gstin ?? "—"}</td><td className="px-6 py-4 text-[#667085]">{customer.licenseCount}</td><td className="px-6 py-4 text-[#667085]">{formatDate(customer.createdAt)}</td><td className="px-6 py-4"><StatusBadge status={customer.status} /></td><td className="sticky right-0 bg-white px-6 py-4"><CustomerRowActions id={customer.id} name={customer.companyName} canEdit={canEdit} canDelete={canDelete} /></td></tr>)}</tbody></table></div>
      {!customers.length ? <p className="p-10 text-center text-sm text-[#667085]">No customers are stored in Supabase yet.</p> : null}
      <div className="border-t border-[#eaecf0] px-6 py-4 text-xs text-[#667085]">{customers.length} customer{customers.length === 1 ? "" : "s"}</div>
    </div>
  </div>;
}
