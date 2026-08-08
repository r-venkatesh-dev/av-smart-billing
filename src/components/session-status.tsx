"use client";

import { useEffect, useRef, useState } from "react";
import { CheckCircle2, KeyRound, ShieldCheck, UserRound, X } from "lucide-react";

export function SessionStatus({ mode, user }: { mode: "admin" | "billing"; user?: { fullName: string; role: string } }) {
  const [open, setOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function close(event: KeyboardEvent) {
      if (event.key === "Escape") setOpen(false);
    }
    function outside(event: PointerEvent) {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) setOpen(false);
    }
    document.addEventListener("keydown", close);
    document.addEventListener("pointerdown", outside);
    return () => {
      document.removeEventListener("keydown", close);
      document.removeEventListener("pointerdown", outside);
    };
  }, []);

  const licensed = user?.role === "LICENSED";
  const roleLabel = licensed ? "Licensed customer" : user?.role ? user.role.toLocaleLowerCase().replace(/^./, (letter) => letter.toUpperCase()) : "Authenticated user";

  return <div ref={containerRef} className="relative">
    <button type="button" aria-label="View security and session status" aria-expanded={open} onClick={() => setOpen((value) => !value)} className={`focus-ring rounded-xl border p-2 transition ${open ? "border-[#057c73] bg-[#edf7f5] text-[#057c73]" : "border-[#e4e7ec] text-[#475467] hover:border-[#b9cfcb] hover:text-[#057c73]"}`}><ShieldCheck size={19} /></button>
    {open ? <section className="absolute right-0 top-[calc(100%+10px)] z-50 w-[min(88vw,340px)] border border-[#dfe3e1] bg-white p-5 shadow-[0_18px_50px_rgba(23,27,54,.16)]" aria-label="Session details">
      <div className="flex items-start justify-between gap-3">
        <div><p className="text-[9px] font-bold uppercase tracking-[.15em] text-[#057c73]">Security</p><h2 className="mt-1 font-serif text-xl text-[#26272a]">Secure session</h2></div>
        <button type="button" aria-label="Close session details" onClick={() => setOpen(false)} className="grid size-8 place-items-center border border-[#e3e7e5] text-[#667085] hover:text-[#26272a]"><X size={15} /></button>
      </div>
      <div className="mt-4 flex items-center gap-3 border border-emerald-100 bg-emerald-50 p-3">
        <CheckCircle2 size={19} className="shrink-0 text-emerald-700" />
        <div><p className="text-xs font-semibold text-emerald-900">Session active</p><p className="mt-0.5 text-[10px] text-emerald-700">Your access has been verified.</p></div>
      </div>
      <dl className="mt-4 space-y-3 text-xs">
        <div className="flex gap-3"><UserRound size={16} className="mt-0.5 shrink-0 text-[#057c73]" /><div className="min-w-0"><dt className="text-[9px] font-bold uppercase tracking-[.1em] text-[#8b918e]">Signed in as</dt><dd className="mt-0.5 truncate font-semibold text-[#26272a]">{user?.fullName || "Active user"}</dd><dd className="text-[10px] text-[#7b817e]">{roleLabel}</dd></div></div>
        <div className="flex gap-3"><KeyRound size={16} className="mt-0.5 shrink-0 text-[#057c73]" /><div><dt className="text-[9px] font-bold uppercase tracking-[.1em] text-[#8b918e]">Access method</dt><dd className="mt-0.5 font-semibold text-[#26272a]">{licensed ? "Signed license activation" : "Supabase administrator login"}</dd><dd className="text-[10px] text-[#7b817e]">{mode === "admin" ? "Control Center" : "Billing Desk"}</dd></div></div>
      </dl>
      <p className="mt-4 border-t border-[#edf0ee] pt-3 text-[10px] leading-4 text-[#7b817e]">This icon shows the current login and access type. It is not a notification bell.</p>
    </section> : null}
  </div>;
}
