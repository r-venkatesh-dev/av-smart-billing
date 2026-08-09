"use client";

import { useActionState, useRef, useState } from "react";
import { adjustBillingStock, type BillingFormState } from "@/app/billing/actions";

const initialState: BillingFormState = {};
const inputClass = "focus-ring h-11 w-full border border-[#dfe3e1] bg-white px-3 text-sm outline-none";

export function InventoryAdjustmentForm({ products }: { products: { id: string; name: string; sku: string; unit: string; stockQuantity: number }[] }) {
  const [state, action, pending] = useActionState(adjustBillingStock, initialState);
  const [confirming, setConfirming] = useState(false);
  const confirmed = useRef(false);
  const formRef = useRef<HTMLFormElement>(null);
  function submit(event: React.FormEvent<HTMLFormElement>) {
    if (confirmed.current) { confirmed.current = false; return; }
    event.preventDefault(); setConfirming(true);
  }
  function confirm() { confirmed.current = true; setConfirming(false); formRef.current?.requestSubmit(); }
  return <><form ref={formRef} action={action} onSubmit={submit} className="surface grid gap-4 p-5 md:grid-cols-2 xl:grid-cols-5"><label className="md:col-span-2"><span className="mb-2 block text-xs font-semibold">Product</span><select name="productId" required className={inputClass}><option value="">Select product</option>{products.map((product) => <option key={product.id} value={product.id}>{product.name} · {product.sku} · {product.stockQuantity} {product.unit}</option>)}</select></label><label><span className="mb-2 block text-xs font-semibold">Movement</span><select name="movementType" className={inputClass}><option value="PURCHASE">Purchase / Stock in</option><option value="RETURN">Sales return / Stock in</option><option value="ADJUSTMENT">Set counted stock</option></select></label><label><span className="mb-2 block text-xs font-semibold">Quantity</span><input name="quantity" type="number" min="0" step=".001" required className={inputClass} /></label><label><span className="mb-2 block text-xs font-semibold">Reference</span><input name="reference" className={inputClass} /></label><label className="md:col-span-2 xl:col-span-4"><span className="mb-2 block text-xs font-semibold">Notes</span><input name="notes" className={inputClass} /></label><button disabled={pending} className="focus-ring h-11 self-end bg-[#057c73] px-4 text-[10px] font-bold uppercase tracking-[.1em] text-white disabled:opacity-50">{pending ? "Updating…" : "Update stock"}</button>{state.message ? <p className="md:col-span-2 xl:col-span-5 border-l-2 border-[#057c73] bg-[#e6f2f0] p-3 text-xs text-[#035f58]">{state.message}</p> : null}</form>{confirming ? <div className="fixed inset-0 z-[80] grid place-items-center bg-[#26272a]/55 p-5" onMouseDown={(event) => { if (event.target === event.currentTarget) setConfirming(false); }}><div role="dialog" aria-modal="true" className="w-full max-w-md border border-[#dfe3e1] bg-white p-6 shadow-2xl"><p className="text-[10px] font-bold uppercase tracking-[.16em] text-[#057c73]">Confirm inventory movement</p><h2 className="mt-2 text-2xl font-normal">Update this product&apos;s stock?</h2><p className="mt-3 text-sm leading-6 text-[#6d716f]">Current stock will change and a permanent movement-history entry will be created.</p><div className="mt-6 flex justify-end gap-3 border-t border-[#dfe3e1] pt-5"><button type="button" onClick={() => setConfirming(false)} className="border border-[#dfe3e1] px-4 py-2.5 text-[10px] font-bold uppercase">Review</button><button type="button" onClick={confirm} className="bg-[#057c73] px-4 py-2.5 text-[10px] font-bold uppercase text-white">Confirm update</button></div></div></div> : null}</>;
}
