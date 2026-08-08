"use client";

import Link from "next/link";
import { useEffect, useState, useTransition } from "react";
import { Pencil, Trash2, X } from "lucide-react";
import { deleteBillingProduct } from "@/app/billing/actions";

export function ProductRowActions({ id, name }: { id: string; name: string }) {
  const [confirming, setConfirming] = useState(false);
  const [message, setMessage] = useState("");
  const [pending, startTransition] = useTransition();

  useEffect(() => {
    function escape(event: KeyboardEvent) {
      if (event.key === "Escape") setConfirming(false);
    }
    document.addEventListener("keydown", escape);
    return () => document.removeEventListener("keydown", escape);
  }, []);

  function remove() {
    startTransition(async () => {
      const result = await deleteBillingProduct(id);
      setMessage(result.message);
      setConfirming(false);
    });
  }

  return <><div className="flex items-center justify-end gap-2"><Link href={`/billing/products/${id}/edit`} className="focus-ring inline-flex h-9 items-center gap-2 border border-[#dfe3e1] px-3 text-[10px] font-bold uppercase tracking-[.08em] text-[#057c73]"><Pencil size={13} />Edit</Link><button type="button" onClick={() => setConfirming(true)} className="focus-ring inline-flex h-9 items-center gap-2 border border-rose-200 px-3 text-[10px] font-bold uppercase tracking-[.08em] text-rose-700"><Trash2 size={13} />Delete</button></div>{message ? <span className="mt-1 block max-w-56 text-right text-[10px] leading-4 text-[#6d716f]">{message}</span> : null}{confirming ? <div className="fixed inset-0 z-[80] grid place-items-center bg-[#26272a]/55 p-5" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setConfirming(false); }}><div role="dialog" aria-modal="true" aria-labelledby={`delete-product-${id}`} className="w-full max-w-md border border-[#dfe3e1] bg-[#f7f8f7] p-6 text-left shadow-2xl"><div className="flex items-start justify-between gap-4"><div><p className="text-[10px] font-bold uppercase tracking-[.16em] text-rose-700">Product action</p><h2 id={`delete-product-${id}`} className="mt-2 text-2xl font-normal">Delete {name}?</h2></div><button type="button" onClick={() => setConfirming(false)} aria-label="Close confirmation" className="focus-ring grid size-9 place-items-center border border-[#dfe3e1]"><X size={17} /></button></div><p className="mt-4 text-sm leading-6 text-[#6d716f]">Unused products are permanently deleted. If this product appears on an existing invoice, it will be archived instead so your accounting history remains correct.</p><div className="mt-6 flex justify-end gap-3 border-t border-[#dfe3e1] pt-5"><button type="button" onClick={() => setConfirming(false)} className="border border-[#dfe3e1] px-4 py-2.5 text-[10px] font-bold uppercase tracking-[.1em]">Cancel</button><button type="button" disabled={pending} onClick={remove} className="bg-rose-700 px-4 py-2.5 text-[10px] font-bold uppercase tracking-[.1em] text-white disabled:opacity-60">{pending ? "Checking…" : "Delete safely"}</button></div></div></div> : null}</>;
}
