"use client";

import { useState, useTransition } from "react";
import { Ban, MonitorOff, PauseCircle, PlayCircle, X } from "lucide-react";
import { changeLicenseStatus, deactivateLicenseDevice } from "@/app/admin/actions";

type Confirmation = { kind: "SUSPEND" | "REVOKE" | "REACTIVATE" | "DEVICE"; id: string; name: string };

export function LicenseControls({ licenseId, status, devices, canManageLicense, canManageDevice }: { licenseId: string; status: string; devices: { id: string; name: string; status: string }[]; canManageLicense: boolean; canManageDevice: boolean }) {
  const [confirmation, setConfirmation] = useState<Confirmation | null>(null);
  const [message, setMessage] = useState("");
  const [pending, startTransition] = useTransition();
  const destructive = confirmation?.kind === "REVOKE";

  function confirm() {
    if (!confirmation) return;
    startTransition(async () => {
      const result = confirmation.kind === "DEVICE" ? await deactivateLicenseDevice(licenseId, confirmation.id) : await changeLicenseStatus(licenseId, confirmation.kind);
      setMessage(result.message);
      setConfirmation(null);
    });
  }

  return <div className="space-y-5">
    {canManageLicense ? <section className="surface p-5"><h2 className="font-bold">License controls</h2><p className="mt-1 text-xs leading-5 text-[#667085]">Suspend temporarily, or revoke permanently if the entitlement must be cancelled.</p><div className="mt-4 flex flex-wrap gap-3">{status === "ACTIVE" ? <button type="button" onClick={() => setConfirmation({ kind: "SUSPEND", id: licenseId, name: "this license" })} className="inline-flex items-center gap-2 border border-amber-300 px-4 py-2.5 text-[10px] font-bold uppercase tracking-[.1em] text-amber-800"><PauseCircle size={15} />Suspend</button> : null}{status === "SUSPENDED" ? <button type="button" onClick={() => setConfirmation({ kind: "REACTIVATE", id: licenseId, name: "this license" })} className="inline-flex items-center gap-2 bg-[#057c73] px-4 py-2.5 text-[10px] font-bold uppercase tracking-[.1em] text-white"><PlayCircle size={15} />Reactivate</button> : null}{status !== "REVOKED" ? <button type="button" onClick={() => setConfirmation({ kind: "REVOKE", id: licenseId, name: "this license" })} className="inline-flex items-center gap-2 border border-rose-300 px-4 py-2.5 text-[10px] font-bold uppercase tracking-[.1em] text-rose-700"><Ban size={15} />Revoke permanently</button> : null}</div></section> : null}
    {canManageDevice && devices.some((device) => device.status === "ACTIVE") ? <section className="surface p-5"><h2 className="font-bold">Device transfer</h2><p className="mt-1 text-xs leading-5 text-[#667085]">If a customer’s computer is damaged, deactivate only that device. This frees a slot without revoking the license.</p><div className="mt-4 space-y-2">{devices.filter((device) => device.status === "ACTIVE").map((device) => <div key={device.id} className="flex flex-col gap-3 border border-[#dfe3e1] p-3 sm:flex-row sm:items-center sm:justify-between"><span className="text-sm font-semibold">{device.name}</span><button type="button" onClick={() => setConfirmation({ kind: "DEVICE", id: device.id, name: device.name })} className="inline-flex items-center justify-center gap-2 border border-[#dfe3e1] px-3 py-2 text-[10px] font-bold uppercase tracking-[.08em] text-[#057c73]"><MonitorOff size={14} />Deactivate &amp; free slot</button></div>)}</div></section> : null}
    {message ? <p role="status" className="border-l-2 border-[#057c73] bg-[#e6f2f0] p-3 text-sm text-[#035f58]">{message}</p> : null}
    {confirmation ? <div className="fixed inset-0 z-[90] grid place-items-center bg-[#26272a]/55 p-5" onMouseDown={(event) => { if (event.target === event.currentTarget && !pending) setConfirmation(null); }}><div role="dialog" aria-modal="true" aria-labelledby="license-confirm-title" className="w-full max-w-md border border-[#dfe3e1] bg-[#f7f8f7] p-6 shadow-2xl"><div className="flex items-start justify-between gap-4"><div><p className={`text-[10px] font-bold uppercase tracking-[.16em] ${destructive ? "text-rose-700" : "text-[#057c73]"}`}>Confirm action</p><h2 id="license-confirm-title" className="mt-2 text-2xl">{confirmation.kind === "DEVICE" ? `Deactivate ${confirmation.name}?` : `${confirmation.kind[0]}${confirmation.kind.slice(1).toLowerCase()} ${confirmation.name}?`}</h2></div><button type="button" disabled={pending} onClick={() => setConfirmation(null)} aria-label="Close confirmation" className="grid size-9 place-items-center border border-[#dfe3e1]"><X size={17} /></button></div><p className="mt-4 text-sm leading-6 text-[#6d716f]">{confirmation.kind === "DEVICE" ? "This device will stop validating and one activation slot will become available for the customer's replacement computer." : confirmation.kind === "REVOKE" ? "This is a permanent entitlement block. Every active device will be deactivated and this key cannot be used again." : confirmation.kind === "SUSPEND" ? "Activation and validation will be blocked until an administrator reactivates the license." : "The license will be allowed to activate and validate again if it has not expired."}</p><div className="mt-6 flex justify-end gap-3 border-t border-[#dfe3e1] pt-5"><button type="button" disabled={pending} onClick={() => setConfirmation(null)} className="border border-[#dfe3e1] px-4 py-2.5 text-[10px] font-bold uppercase tracking-[.1em]">Cancel</button><button type="button" disabled={pending} onClick={confirm} className={`${destructive ? "bg-rose-700" : "bg-[#057c73]"} px-4 py-2.5 text-[10px] font-bold uppercase tracking-[.1em] text-white disabled:opacity-60`}>{pending ? "Updating…" : "Confirm"}</button></div></div></div> : null}
  </div>;
}
