"use client";

import { useState } from "react";
import { Copy, Eye, EyeOff, X } from "lucide-react";
import { revealLicenseKey } from "@/app/admin/license-key-actions";

export function LicenseKeyReveal({ licenseId, recoverable }: { licenseId: string; recoverable: boolean }) {
  const [open, setOpen] = useState(false);
  const [password, setPassword] = useState("");
  const [licenseKey, setLicenseKey] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  function close() {
    setOpen(false); setPassword(""); setLicenseKey(""); setMessage(""); setBusy(false);
  }

  async function verify(event: React.FormEvent) {
    event.preventDefault(); setBusy(true); setMessage("");
    const result = await revealLicenseKey(licenseId, password);
    setBusy(false); setMessage(result.message); setPassword("");
    if (result.ok && result.licenseKey) setLicenseKey(result.licenseKey);
  }

  return <>
    <button type="button" onClick={() => { setOpen(true); if (!recoverable) setMessage("This legacy key was stored as a one-way hash and cannot be recovered."); }} aria-label="View license key" title="View license key" className="focus-ring grid size-8 place-items-center text-[#5b4df5] hover:bg-indigo-50"><Eye size={16} /></button>
    {open ? <div className="fixed inset-0 z-[90] grid place-items-center bg-[#171b36]/60 p-4" onMouseDown={(event) => { if (event.target === event.currentTarget) close(); }}><section role="dialog" aria-modal="true" aria-labelledby={`reveal-${licenseId}`} className="w-full max-w-md bg-white p-6 text-[#26272a] shadow-2xl"><div className="flex items-start justify-between gap-4"><div><p className="text-[10px] font-bold uppercase tracking-[.14em] text-[#5b4df5]">Protected license key</p><h2 id={`reveal-${licenseId}`} className="mt-1 text-2xl">Verify your password</h2></div><button type="button" onClick={close} aria-label="Close" className="grid size-9 place-items-center border border-[#dfe3eb]"><X size={17} /></button></div>
      {licenseKey ? <div className="mt-5"><p className="text-xs leading-5 text-amber-800">Visible only until this dialog closes or the page reloads.</p><code className="mt-3 block select-all break-all border border-amber-300 bg-amber-50 p-4 text-center font-mono text-xl font-bold tracking-[.06em]">{licenseKey}</code><button type="button" onClick={() => navigator.clipboard.writeText(licenseKey)} className="mt-3 flex h-11 w-full items-center justify-center gap-2 bg-[#057c73] text-xs font-bold uppercase tracking-[.08em] text-white"><Copy size={16} />Copy key</button></div> : recoverable ? <form onSubmit={verify} className="mt-5"><label><span className="mb-2 block text-sm font-semibold">Admin login password</span><input autoFocus type="password" required value={password} onChange={(event) => setPassword(event.target.value)} autoComplete="current-password" className="h-11 w-full border border-[#dfe3eb] px-3" /></label><button disabled={busy} className="mt-4 flex h-11 w-full items-center justify-center gap-2 bg-[#171b36] text-xs font-bold uppercase tracking-[.08em] text-white disabled:opacity-60"><EyeOff size={16} />{busy ? "Verifying…" : "Verify and reveal"}</button></form> : null}
      {message ? <p className={`mt-4 p-3 text-sm ${licenseKey ? "bg-emerald-50 text-emerald-800" : "bg-rose-50 text-rose-700"}`}>{message}</p> : null}
    </section></div> : null}
  </>;
}
