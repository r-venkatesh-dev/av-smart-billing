import Link from "next/link";
import { notFound } from "next/navigation";
import { Building2, KeyRound, Mail, MapPin, Phone } from "lucide-react";
import { DetailItem, PageHeader, StatusBadge } from "@/components/ui";
import { CustomerRowActions } from "@/components/customer-row-actions";
import { getAdminCustomer } from "@/data/admin";
import { requireAdminRole } from "@/lib/auth/authorization";
import { formatDate } from "@/lib/format";

export default async function CustomerDetailPage({ params }: PageProps<"/admin/customers/[id]">) {
  const { id } = await params;
  const [customer, admin] = await Promise.all([getAdminCustomer(id), requireAdminRole()]);
  if (!customer) notFound();
  return <div className="space-y-7">
    <PageHeader backHref="/admin/customers" eyebrow="Customer profile" title={customer.companyName} description={`Customer since ${formatDate(customer.createdAt)}`} />
    <CustomerRowActions id={customer.id} name={customer.companyName} canEdit={admin.role !== "VIEWER"} canDelete={admin.role === "OWNER" || admin.role === "ADMIN"} detail />
    <div className="grid gap-5 xl:grid-cols-[1fr_1.5fr]">
      <section className="surface p-6"><div className="flex items-start justify-between"><span className="grid size-12 place-items-center rounded-2xl bg-indigo-50 text-indigo-600"><Building2 /></span><StatusBadge status={customer.status} /></div><h2 className="mt-5 text-lg font-bold">Business details</h2><dl className="mt-5 grid gap-6 sm:grid-cols-2 xl:grid-cols-1"><DetailItem label="Contact person">{customer.contactPerson}</DetailItem><DetailItem label="GSTIN">{customer.gstin ?? "Not provided"}</DetailItem><DetailItem label="Email"><span className="flex items-center gap-2"><Mail size={15} />{customer.email}</span></DetailItem><DetailItem label="Phone"><span className="flex items-center gap-2"><Phone size={15} />{customer.phone}</span></DetailItem><DetailItem label="Address"><span className="flex items-start gap-2"><MapPin className="mt-0.5 shrink-0" size={15} />{customer.address}</span></DetailItem></dl></section>
      <section className="surface overflow-hidden"><div className="border-b border-[#eaecf0] px-6 py-5"><h2 className="font-bold">Licenses</h2><p className="mt-1 text-xs text-[#98a2b3]">Licenses issued to this customer</p></div>{customer.licenses.length ? <div className="divide-y divide-[#eef0f4]">{customer.licenses.map((license) => <Link href={`/admin/licenses/${license.id}`} key={license.id} className="flex items-center gap-4 p-5 transition hover:bg-[#fafaff]"><span className="grid size-10 place-items-center rounded-xl bg-[#efedff] text-[#5b4df5]"><KeyRound size={19} /></span><span className="min-w-0 flex-1"><strong className="block text-sm">{license.planName}</strong><span className="mt-0.5 block truncate font-mono text-xs text-[#98a2b3]">{license.maskedKey}</span></span><span className="text-right"><StatusBadge status={license.status} /><small className="mt-1 block text-[#98a2b3]">Expires {formatDate(license.expiresAt)}</small></span></Link>)}</div> : <p className="p-8 text-center text-sm text-[#667085]">No licenses issued yet.</p>}</section>
    </div>
  </div>;
}
