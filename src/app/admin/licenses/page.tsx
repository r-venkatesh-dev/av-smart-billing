import Link from "next/link";
import { KeyRound } from "lucide-react";
import { LicenseKeyReveal } from "@/components/license-key-reveal";
import { PageHeader, StatusBadge } from "@/components/ui";
import { listAdminLicenses } from "@/data/admin";
import { requireAdminRole } from "@/lib/auth/authorization";
import { formatDate } from "@/lib/format";

export const metadata = { title: "Licenses" };

export default async function LicensesPage() {
  const [licenses, admin] = await Promise.all([listAdminLicenses(), requireAdminRole()]);
  const active = licenses.filter((license) => license.status === "ACTIVE").length;
  const expiring = licenses.filter((license) => license.isExpiringSoon).length;
  const restricted = licenses.filter((license) => license.status === "SUSPENDED" || license.status === "REVOKED").length;
  const canReveal = admin.role === "OWNER" || admin.role === "ADMIN";
  return <div className="space-y-7">
    <PageHeader eyebrow="Entitlements" title="Licenses" description="Generate, activate and control customer licenses from Supabase." actionLabel="Generate license" actionHref="/admin/licenses/new" />
    <div className="grid gap-4 sm:grid-cols-3"><div className="surface p-5"><p className="text-sm text-[#667085]">Active</p><strong className="mt-1 block text-2xl">{active}</strong></div><div className="surface p-5"><p className="text-sm text-[#667085]">Expiring in 30 days</p><strong className="mt-1 block text-2xl text-amber-600">{expiring}</strong></div><div className="surface p-5"><p className="text-sm text-[#667085]">Suspended or revoked</p><strong className="mt-1 block text-2xl text-rose-600">{restricted}</strong></div></div>
    <div className="surface overflow-hidden"><div className="overflow-x-auto"><table className="w-full min-w-[900px] text-left text-sm"><thead className="bg-[#fafbfc] text-[11px] uppercase tracking-wide text-[#98a2b3]"><tr>{["License", "Customer", "Plan", "Devices", "Created", "Expires", "Status"].map((heading) => <th key={heading} className="px-6 py-3 font-semibold">{heading}</th>)}</tr></thead><tbody className="divide-y divide-[#eef0f4]">{licenses.map((license) => <tr key={license.id} className="hover:bg-[#fafaff]"><td className="px-6 py-4"><span className="flex items-center gap-3"><span className="grid size-8 place-items-center bg-indigo-50 text-indigo-600"><KeyRound size={15} /></span><Link href={`/admin/licenses/${license.id}`} className="font-mono text-xs font-semibold text-[#475467] hover:text-[#5b4df5]">{license.maskedKey}</Link>{canReveal ? <LicenseKeyReveal licenseId={license.id} recoverable={license.recoverableKey} /> : null}</span></td><td className="px-6 py-4 font-semibold text-[#344054]">{license.customerName}</td><td className="px-6 py-4 text-[#667085]">{license.planName}</td><td className="px-6 py-4 text-[#667085]">{license.activeDevices}/{license.maxDevices}</td><td className="px-6 py-4 text-[#667085]">{formatDate(license.createdAt)}</td><td className="px-6 py-4 text-[#667085]">{formatDate(license.expiresAt)}</td><td className="px-6 py-4"><StatusBadge status={license.status} /></td></tr>)}</tbody></table></div>{!licenses.length ? <p className="p-10 text-center text-sm text-[#667085]">No licenses yet. Generate the first key for a customer.</p> : null}</div>
  </div>;
}
