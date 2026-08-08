"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { CheckCircle2, KeyRound, LoaderCircle, RefreshCw } from "lucide-react";

type ActivationResponse = { ok: boolean; message?: string; grant?: { licenseId: string; deviceId: string; customerName: string; planName: string; expiresAt: string; validationWindowDays: number; maxDevices: number }; signed?: { token: string; validUntil: string; publicKey: string; keyId: string; issuer: string } };

const storageKey = "av-smartbilling-local-activation";

async function deviceIdentity() {
  if (window.avSmartbillingDesktop) {
    try {
      return await window.avSmartbillingDesktop.getDeviceIdentity();
    } catch {
      // Fall back to a browser identity if the desktop bridge is unavailable.
    }
  }
  const existing = localStorage.getItem("av-smartbilling-browser-device-id");
  if (existing) return { fingerprint: existing, deviceName: "Localhost test computer" };
  const created = `${crypto.randomUUID()}-${crypto.randomUUID()}`;
  localStorage.setItem("av-smartbilling-browser-device-id", created);
  return { fingerprint: created, deviceName: "Localhost test computer" };
}

function save(result: ActivationResponse, deviceFingerprint: string) {
  if (!result.grant || !result.signed) return;
  localStorage.setItem(storageKey, JSON.stringify({ deviceId: result.grant.deviceId, deviceFingerprint, token: result.signed.token, validUntil: result.signed.validUntil, publicKey: result.signed.publicKey, keyId: result.signed.keyId }));
}

export function ActivationForm() {
  const router = useRouter();
  const [result, setResult] = useState<ActivationResponse | null>(null);
  const [pending, setPending] = useState(false);
  const [deviceName, setDeviceName] = useState("This computer");

  useEffect(() => {
    let active = true;
    deviceIdentity().then((identity) => { if (active) setDeviceName(identity.deviceName); });
    return () => { active = false; };
  }, []);

  async function activate(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPending(true);
    setResult(null);
    const form = new FormData(event.currentTarget);
    try {
      const identity = await deviceIdentity();
      const deviceFingerprint = identity.fingerprint;
      const response = await fetch("/api/license/activate", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ licenseKey: String(form.get("licenseKey") ?? "").trim().toUpperCase(), deviceName: String(form.get("deviceName") ?? "").trim(), deviceFingerprint }) });
      const payload = await response.json() as ActivationResponse;
      if (payload.ok) save(payload, deviceFingerprint);
      setResult(payload);
      if (payload.ok) window.setTimeout(() => router.push("/billing/dashboard"), 900);
    } catch {
      setResult({ ok: false, message: "Unable to reach the activation server. Check your internet connection and try again." });
    } finally {
      setPending(false);
    }
  }

  async function validateStored() {
    const raw = localStorage.getItem(storageKey);
    if (!raw) return setResult({ ok: false, message: "No activation is stored in this browser yet." });
    setPending(true);
    try {
      const stored = JSON.parse(raw) as { deviceId: string; deviceFingerprint: string };
      const response = await fetch("/api/license/validate", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ deviceId: stored.deviceId, deviceFingerprint: stored.deviceFingerprint }) });
      const payload = await response.json() as ActivationResponse;
      if (payload.ok) save(payload, stored.deviceFingerprint);
      setResult(payload);
      if (payload.ok) window.setTimeout(() => router.push("/billing/dashboard"), 900);
    } catch {
      setResult({ ok: false, message: "Unable to validate the stored activation. Check your internet connection and try again." });
    } finally {
      setPending(false);
    }
  }

  return <div className="space-y-5"><form onSubmit={activate} className="surface space-y-5 p-6"><label><span className="mb-2 block text-sm font-semibold">License key</span><input name="licenseKey" required autoComplete="off" spellCheck={false} placeholder="ABCD-EFGH-JKLM-NPQR" className="focus-ring h-12 w-full border border-[#dfe3e1] bg-white px-4 font-mono text-sm uppercase tracking-[.08em]" /></label><label><span className="mb-2 block text-sm font-semibold">Device name</span><input name="deviceName" required value={deviceName} onChange={(event) => setDeviceName(event.target.value)} className="focus-ring h-12 w-full border border-[#dfe3e1] bg-white px-4 text-sm" /></label><button disabled={pending} className="flex h-12 w-full items-center justify-center gap-2 bg-[#057c73] text-[11px] font-bold uppercase tracking-[.12em] text-white disabled:opacity-60">{pending ? <LoaderCircle size={17} className="animate-spin" /> : <KeyRound size={17} />}{pending ? "Activating…" : "Activate software"}</button></form><button type="button" disabled={pending} onClick={validateStored} className="flex h-11 w-full items-center justify-center gap-2 border border-[#dfe3e1] bg-white text-[10px] font-bold uppercase tracking-[.1em] disabled:opacity-60"><RefreshCw size={15} />Validate stored activation</button>{result ? <section role="status" className={`border-l-4 p-5 ${result.ok ? "border-[#057c73] bg-[#e6f2f0]" : "border-rose-600 bg-rose-50"}`}>{result.ok && result.grant && result.signed ? <><div className="flex items-center gap-2 text-[#035f58]"><CheckCircle2 size={20} /><h2 className="font-bold">Activation successful</h2></div><dl className="mt-4 grid gap-3 text-sm sm:grid-cols-2"><div><dt className="text-xs text-[#6d716f]">Customer</dt><dd className="font-semibold">{result.grant.customerName}</dd></div><div><dt className="text-xs text-[#6d716f]">Plan</dt><dd className="font-semibold">{result.grant.planName}</dd></div><div><dt className="text-xs text-[#6d716f]">License expiry</dt><dd className="font-semibold">{new Date(result.grant.expiresAt).toLocaleDateString("en-IN")}</dd></div><div><dt className="text-xs text-[#6d716f]">Validation valid until</dt><dd className="font-semibold">{new Date(result.signed.validUntil).toLocaleString("en-IN")}</dd></div></dl><p className="mt-4 text-xs leading-5 text-[#035f58]">This signed activation is stored for this installation. Internet is required again when its validation window ends.</p></> : <p className="text-sm font-semibold text-rose-700">{result.message ?? "Activation failed."}</p>}</section> : null}</div>;
}
