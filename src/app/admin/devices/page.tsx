import { MonitorSmartphone } from "lucide-react";
import { PageHeader, StatusBadge } from "@/components/ui";
import { listAdminDevices } from "@/data/admin";
import { formatDate } from "@/lib/format";

export const metadata = { title: "Devices" };

export default async function DevicesPage() {
  const devices = await listAdminDevices();
  return <div className="space-y-7"><PageHeader eyebrow="Activations" title="Devices" description="Monitor activated computers and device-slot usage." /><div className="surface overflow-hidden"><div className="divide-y divide-[#eef0f4]">{devices.map((device) => <div key={device.id} className="flex flex-col gap-4 p-5 sm:flex-row sm:items-center sm:px-6"><span className="grid size-11 place-items-center rounded-xl bg-sky-50 text-sky-600"><MonitorSmartphone size={20} /></span><div className="min-w-0 flex-1"><strong className="text-sm">{device.name}</strong><p className="mt-0.5 truncate text-xs text-[#98a2b3]">{device.customerName} · {device.fingerprintPreview}</p></div><div className="text-xs text-[#667085]"><span className="block font-medium">Last seen</span>{formatDate(device.lastValidatedAt)}</div><StatusBadge status={device.status} /></div>)}</div>{!devices.length ? <p className="p-10 text-center text-sm text-[#667085]">No device activations are stored in Supabase.</p> : null}</div></div>;
}
