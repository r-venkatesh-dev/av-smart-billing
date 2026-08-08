import { notFound } from "next/navigation";
import { CalendarDays, MonitorSmartphone, ShieldCheck } from "lucide-react";
import { LicenseControls } from "@/components/license-controls";
import { DetailItem, PageHeader, StatusBadge } from "@/components/ui";
import { getAdminLicense } from "@/data/admin";
import { requireAdminRole } from "@/lib/auth/authorization";
import { formatDate } from "@/lib/format";

export default async function LicenseDetailPage({ params }: PageProps<"/admin/licenses/[id]">) {
  const { id } = await params;
  const [license, admin] = await Promise.all([getAdminLicense(id), requireAdminRole()]);
  if (!license) notFound();
  const activeDevices = license.devices.filter((device) => device.status === "ACTIVE");
  return <div className="space-y-7">
    <PageHeader backHref="/admin/licenses" eyebrow="License details" title={license.customerName} description={license.maskedKey} />
    <div className="grid gap-5 lg:grid-cols-3"><section className="surface p-6 lg:col-span-2"><div className="flex items-center justify-between"><h2 className="font-bold">Entitlement</h2><StatusBadge status={license.status} /></div><dl className="mt-6 grid gap-6 sm:grid-cols-2 lg:grid-cols-3"><DetailItem label="Plan">{license.planName}</DetailItem><DetailItem label="Devices">{activeDevices.length} active of {license.maxDevices}</DetailItem><DetailItem label="Created">{formatDate(license.createdAt)}</DetailItem><DetailItem label="Expires">{formatDate(license.expiresAt)}</DetailItem><DetailItem label="Last validated">{license.lastValidatedAt ? formatDate(license.lastValidatedAt) : "Never"}</DetailItem><DetailItem label="Offline window">{license.validationWindowDays} days</DetailItem></dl></section><section className="bg-[#171b36] p-6 text-white"><span className="grid size-10 place-items-center bg-white/10"><ShieldCheck size={20} /></span><h2 className="mt-5 font-bold">Signed activation enabled</h2><p className="mt-2 text-sm leading-6 text-[#b9bdd3]">Activation APIs issue device-bound Ed25519 signed grants. The private key remains server-only.</p></section></div>
    <LicenseControls licenseId={license.id} status={license.status} devices={license.devices.map(({ id: deviceId, name, status }) => ({ id: deviceId, name, status }))} canManageLicense={admin.role === "OWNER" || admin.role === "ADMIN"} canManageDevice={admin.role !== "VIEWER"} />
    <section className="surface overflow-hidden"><div className="flex items-center justify-between border-b border-[#eaecf0] px-6 py-5"><div><h2 className="font-bold">Activated devices</h2><p className="mt-1 text-xs text-[#98a2b3]">Deactivate a damaged PC to free its slot for a replacement.</p></div><span className="bg-[#f0efff] px-3 py-1 text-xs font-bold text-[#5b4df5]">{activeDevices.length}/{license.maxDevices} used</span></div>{license.devices.length ? <div className="divide-y divide-[#eef0f4]">{license.devices.map((device) => <div key={device.id} className="flex flex-col gap-4 p-5 sm:flex-row sm:items-center"><span className="grid size-10 place-items-center bg-sky-50 text-sky-600"><MonitorSmartphone size={19} /></span><span className="flex-1"><strong className="block text-sm">{device.name}</strong><span className="font-mono text-xs text-[#98a2b3]">Fingerprint {device.fingerprintPreview}</span></span><span className="text-xs text-[#667085]"><CalendarDays className="mr-1.5 inline" size={14} />Activated {formatDate(device.activatedAt)}</span><StatusBadge status={device.status} /></div>)}</div> : <p className="p-8 text-center text-sm text-[#667085]">No devices have activated this license.</p>}</section>
  </div>;
}
