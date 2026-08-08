"use client";

import Link from "next/link";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Pencil, Trash2, X } from "lucide-react";
import { deleteCustomer } from "@/app/admin/actions";

export function CustomerRowActions({ id, name, canEdit, canDelete, detail = false }: { id: string; name: string; canEdit: boolean; canDelete: boolean; detail?: boolean }) {
  const router = useRouter();
  const [confirming, setConfirming] = useState(false);
  const [message, setMessage] = useState("");
  const [pending, startTransition] = useTransition();

  function remove() {
    startTransition(async () => {
      const result = await deleteCustomer(id);
      setMessage(result.message);
      setConfirming(false);
      if (result.ok && result.mode === "deleted") router.push("/admin/customers");
      else if (result.ok) router.refresh();
    });
  }

  return <><div className={`flex flex-wrap items-center ${detail ? "justify-start" : "justify-end"} gap-2`}>{canEdit ? <Link href={`/admin/customers/${id}/edit`} className="focus-ring inline-flex h-9 items-center gap-2 border border-[#dfe3e1] px-3 text-[10px] font-bold uppercase tracking-[.08em] text-[#057c73]"><Pencil size={13} />Edit</Link> : null}{canDelete ? <button type="button" onClick={() => setConfirming(true)} className="focus-ring inline-flex h-9 items-center gap-2 border border-rose-200 px-3 text-[10px] font-bold uppercase tracking-[.08em] text-rose-700"><Trash2 size={13} />Delete</button> : null}</div>{message ? <p role="status" className={`mt-2 text-xs text-[#6d716f] ${detail ? "text-left" : "text-right"}`}>{message}</p> : null}{confirming ? <div className="fixed inset-0 z-[90] grid place-items-center bg-[#26272a]/55 p-5" onMouseDown={(event) => { if (event.target === event.currentTarget && !pending) setConfirming(false); }}><div role="dialog" aria-modal="true" aria-labelledby={`delete-customer-${id}`} className="w-full max-w-md border border-[#dfe3e1] bg-[#f7f8f7] p-6 shadow-2xl"><div className="flex items-start justify-between gap-4"><div><p className="text-[10px] font-bold uppercase tracking-[.16em] text-rose-700">Confirm customer deletion</p><h2 id={`delete-customer-${id}`} className="mt-2 text-2xl">Delete {name}?</h2></div><button type="button" disabled={pending} onClick={() => setConfirming(false)} aria-label="Close confirmation" className="grid size-9 place-items-center border border-[#dfe3e1]"><X size={17} /></button></div><p className="mt-4 text-sm leading-6 text-[#6d716f]">Customers without licenses are permanently deleted. If licenses exist, the customer is deactivated instead so license, device and audit history remain intact.</p><div className="mt-6 flex justify-end gap-3 border-t border-[#dfe3e1] pt-5"><button type="button" disabled={pending} onClick={() => setConfirming(false)} className="border border-[#dfe3e1] px-4 py-2.5 text-[10px] font-bold uppercase tracking-[.1em]">Cancel</button><button type="button" disabled={pending} onClick={remove} className="bg-rose-700 px-4 py-2.5 text-[10px] font-bold uppercase tracking-[.1em] text-white disabled:opacity-60">{pending ? "Checking…" : "Delete safely"}</button></div></div></div> : null}</>;
}
