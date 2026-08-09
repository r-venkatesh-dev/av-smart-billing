"use client";

import { useActionState, useEffect, useMemo, useRef, useState } from "react";
import { Barcode, Minus, Plus, Search, ShoppingCart, Trash2 } from "lucide-react";
import { createBillingPosSale, type BillingFormState } from "@/app/billing/actions";
import { formatMoney } from "@/lib/format";

type PosProduct = { id: string; name: string; sku: string; barcode: string | null; category: string; unit: string; priceInPaise: number; taxRateBasisPoints: number; stockQuantity: number };
type PosCustomer = { id: string; name: string; phone: string };
type CartLine = { productId: string; quantity: number; discountPercent: number };

const initialState: BillingFormState = {};
const inputClass = "focus-ring h-11 w-full border border-[#dfe3e1] bg-white px-3 text-sm outline-none";

export function QuickPos({ products, customers }: { products: PosProduct[]; customers: PosCustomer[] }) {
  const [state, action, pending] = useActionState(createBillingPosSale, initialState);
  const [cart, setCart] = useState<CartLine[]>([]);
  const [query, setQuery] = useState("");
  const [customerId, setCustomerId] = useState("");
  const [walkInName, setWalkInName] = useState("");
  const [walkInPhone, setWalkInPhone] = useState("");
  const [paymentMethod, setPaymentMethod] = useState("CASH");
  const [amountReceived, setAmountReceived] = useState("");
  const [taxType, setTaxType] = useState("INTRA_STATE");
  const barcodeRef = useRef<HTMLInputElement>(null);
  const searchRef = useRef<HTMLInputElement>(null);
  const customerRef = useRef<HTMLSelectElement>(null);
  const paymentRef = useRef<HTMLSelectElement>(null);
  const formRef = useRef<HTMLFormElement>(null);

  const matches = useMemo(() => products.filter((product) => `${product.name} ${product.sku} ${product.barcode ?? ""} ${product.category}`.toLowerCase().includes(query.toLowerCase())).slice(0, 12), [products, query]);
  const totals = useMemo(() => cart.reduce((sum, line) => {
    const product = products.find((item) => item.id === line.productId);
    if (!product) return sum;
    const gross = Math.round(product.priceInPaise * line.quantity);
    const discount = Math.round(gross * line.discountPercent / 100);
    const taxable = gross - discount;
    const tax = Math.round(taxable * product.taxRateBasisPoints / 10000);
    return { gross: sum.gross + gross, discount: sum.discount + discount, tax: sum.tax + tax, total: sum.total + taxable + tax };
  }, { gross: 0, discount: 0, tax: 0, total: 0 }), [cart, products]);

  useEffect(() => {
    function shortcut(event: KeyboardEvent) {
      if (event.key === "F2") { event.preventDefault(); searchRef.current?.focus(); }
      if (event.key === "F4") { event.preventDefault(); customerRef.current?.focus(); }
      if (event.key === "F8") { event.preventDefault(); paymentRef.current?.focus(); }
      if (event.key === "F9") { event.preventDefault(); formRef.current?.querySelector<HTMLButtonElement>('[name="print"]')?.click(); }
    }
    document.addEventListener("keydown", shortcut);
    barcodeRef.current?.focus();
    return () => document.removeEventListener("keydown", shortcut);
  }, []);

  function add(product: PosProduct) {
    setCart((current) => {
      const found = current.find((line) => line.productId === product.id);
      if (!found) return [...current, { productId: product.id, quantity: 1, discountPercent: 0 }];
      return current.map((line) => line.productId === product.id ? { ...line, quantity: Math.min(product.stockQuantity, line.quantity + 1) } : line);
    });
    setQuery("");
    barcodeRef.current?.focus();
  }

  function update(index: number, changes: Partial<CartLine>) {
    setCart((current) => current.map((line, itemIndex) => {
      if (index !== itemIndex) return line;
      const product = products.find((item) => item.id === line.productId);
      return { ...line, ...changes, quantity: Math.max(.001, Math.min(product?.stockQuantity ?? line.quantity, changes.quantity ?? line.quantity)), discountPercent: Math.max(0, Math.min(100, changes.discountPercent ?? line.discountPercent)) };
    }));
  }

  function scan(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const value = barcodeRef.current?.value.trim().toLowerCase();
    const product = products.find((item) => item.barcode?.toLowerCase() === value || item.sku.toLowerCase() === value);
    if (product) { add(product); if (barcodeRef.current) barcodeRef.current.value = ""; }
    else if (barcodeRef.current) { barcodeRef.current.setCustomValidity("No active in-stock product matches this barcode or SKU."); barcodeRef.current.reportValidity(); }
  }

  const effectiveAmountReceived = amountReceived || (totals.total / 100).toFixed(2);
  const payload = JSON.stringify({ customerId: customerId || null, walkInName, walkInPhone, items: cart, paymentMethod, amountReceivedInRupees: paymentMethod === "CREDIT" ? "0" : effectiveAmountReceived, reference: "", taxType });

  return <div className="grid overflow-hidden border border-[#dfe3e1] bg-white xl:grid-cols-[.85fr_1.35fr]">
    <section className="border-b border-[#dfe3e1] bg-[#fafbfa] p-5 xl:border-r xl:border-b-0">
      <form onSubmit={scan} className="grid gap-3 border border-[#bddbd7] bg-[#e6f2f0] p-3 sm:grid-cols-[.8fr_1.2fr] sm:items-center">
        <label htmlFor="pos-barcode" className="flex items-center gap-3 text-[#035f58]"><Barcode size={24} /><span><strong className="block text-xs">Scan barcode</strong><small className="text-[10px]">USB scanners work as keyboard input</small></span></label>
        <input ref={barcodeRef} id="pos-barcode" className={inputClass} autoComplete="off" placeholder="Scan barcode or enter SKU" onInput={(event) => event.currentTarget.setCustomValidity("")} />
      </form>
      <label className="mt-3 flex h-11 items-center gap-2 border border-[#dfe3e1] bg-white px-3"><Search size={16} className="text-[#6d716f]" /><input ref={searchRef} value={query} onChange={(event) => setQuery(event.target.value)} className="min-w-0 flex-1 bg-transparent text-xs outline-none" placeholder="Search product, SKU, barcode or category" /></label>
      <div className="mt-3 grid gap-2 sm:grid-cols-2">{matches.map((product) => <button key={product.id} type="button" onClick={() => add(product)} className="focus-ring flex min-h-16 items-center justify-between gap-3 border border-[#dfe3e1] bg-white p-3 text-left transition hover:border-[#057c73] hover:bg-[#f3f8f7]"><span className="min-w-0"><strong className="block truncate text-xs">{product.name}</strong><small className="mt-1 block truncate text-[10px] text-[#6d716f]">{product.sku}{product.barcode ? ` · ${product.barcode}` : ""}</small></span><span className="shrink-0 text-right text-xs font-bold text-[#035f58]">{formatMoney(product.priceInPaise)}<small className="mt-1 block text-[9px] font-normal text-[#6d716f]">{product.stockQuantity} {product.unit}</small></span></button>)}{!matches.length ? <p className="col-span-full p-8 text-center text-xs text-[#6d716f]">No available products match this search.</p> : null}</div>
    </section>

    <form ref={formRef} action={action} className="flex min-w-0 flex-col p-5">
      <input type="hidden" name="payload" value={payload} />
      <div className="grid gap-3 border-b border-[#dfe3e1] pb-4 sm:grid-cols-2"><label><span className="mb-2 block text-[10px] font-bold uppercase tracking-[.1em]">Customer <kbd className="text-[#057c73]">F4</kbd></span><select ref={customerRef} value={customerId} onChange={(event) => setCustomerId(event.target.value)} className={inputClass}><option value="">Walk-in customer</option>{customers.map((customer) => <option key={customer.id} value={customer.id}>{customer.name} · {customer.phone}</option>)}</select></label>{!customerId ? <><label><span className="mb-2 block text-[10px] font-bold uppercase tracking-[.1em]">Walk-in name</span><input required value={walkInName} onChange={(event) => setWalkInName(event.target.value)} className={inputClass} /></label><label><span className="mb-2 block text-[10px] font-bold uppercase tracking-[.1em]">Mobile number</span><input required type="tel" value={walkInPhone} onChange={(event) => setWalkInPhone(event.target.value)} className={inputClass} /></label></> : null}<label><span className="mb-2 block text-[10px] font-bold uppercase tracking-[.1em]">GST treatment</span><select value={taxType} onChange={(event) => setTaxType(event.target.value)} className={inputClass}><option value="INTRA_STATE">CGST + SGST</option><option value="INTER_STATE">IGST</option></select></label></div>
      <div className="max-h-[330px] min-h-[210px] overflow-auto"><table className="w-full min-w-[660px] text-left text-xs"><thead className="sticky top-0 bg-[#fafbfa] text-[9px] uppercase tracking-[.1em] text-[#8a908d]"><tr><th className="p-3">Item</th><th className="p-3">Qty</th><th className="p-3">Discount</th><th className="p-3 text-right">Amount</th><th /></tr></thead><tbody className="divide-y divide-[#edf0ee]">{cart.map((line, index) => { const product = products.find((item) => item.id === line.productId)!; return <tr key={line.productId}><td className="p-3"><strong className="block">{product.name}</strong><small className="text-[#8a908d]">{product.sku} · Stock {product.stockQuantity}</small></td><td className="p-3"><span className="flex items-center"><button type="button" onClick={() => update(index, { quantity: line.quantity - 1 })} className="grid size-8 place-items-center border border-[#dfe3e1]"><Minus size={13} /></button><input value={line.quantity} onChange={(event) => update(index, { quantity: Number(event.target.value) })} type="number" min=".001" max={product.stockQuantity} step=".001" className="h-8 w-14 border-y border-[#dfe3e1] text-center" /><button type="button" onClick={() => update(index, { quantity: line.quantity + 1 })} className="grid size-8 place-items-center border border-[#dfe3e1]"><Plus size={13} /></button></span></td><td className="p-3"><input value={line.discountPercent} onChange={(event) => update(index, { discountPercent: Number(event.target.value) })} type="number" min="0" max="100" step=".01" className="h-8 w-16 border border-[#dfe3e1] px-2 text-right" />%</td><td className="p-3 text-right font-semibold">{formatMoney(Math.round(product.priceInPaise * line.quantity))}</td><td className="p-3"><button type="button" onClick={() => setCart((current) => current.filter((_, itemIndex) => itemIndex !== index))} aria-label={`Remove ${product.name}`} className="text-[#b42318]"><Trash2 size={15} /></button></td></tr>; })}{!cart.length ? <tr><td colSpan={5} className="p-12 text-center text-xs text-[#6d716f]"><ShoppingCart size={24} className="mx-auto mb-2 text-[#a3aaa7]" />Scan or select a product to begin.</td></tr> : null}</tbody></table></div>
      <div className="mt-auto grid gap-4 border-t border-[#dfe3e1] pt-4 lg:grid-cols-[1fr_340px]"><div className="grid gap-3 sm:grid-cols-2"><label><span className="mb-2 block text-[10px] font-bold uppercase tracking-[.1em]">Payment <kbd className="text-[#057c73]">F8</kbd></span><select ref={paymentRef} value={paymentMethod} onChange={(event) => { setPaymentMethod(event.target.value); setAmountReceived(""); }} className={inputClass}><option value="CASH">Cash</option><option value="UPI">UPI</option><option value="CARD">Card</option><option value="BANK_TRANSFER">Bank transfer</option><option value="CREDIT">Credit / Pay later</option><option value="OTHER">Other</option></select></label>{paymentMethod !== "CREDIT" ? <label><span className="mb-2 block text-[10px] font-bold uppercase tracking-[.1em]">Amount received (₹)</span><input value={effectiveAmountReceived} onChange={(event) => setAmountReceived(event.target.value)} type="number" min="0" step=".01" required className={inputClass} /></label> : null}</div><dl className="space-y-2 text-xs"><div className="flex justify-between"><dt className="text-[#6d716f]">Subtotal</dt><dd>{formatMoney(totals.gross)}</dd></div><div className="flex justify-between"><dt className="text-[#6d716f]">Discount</dt><dd>− {formatMoney(totals.discount)}</dd></div><div className="flex justify-between"><dt className="text-[#6d716f]">GST</dt><dd>{formatMoney(totals.tax)}</dd></div><div className="flex justify-between border-t-2 border-[#26272a] pt-2 font-serif text-xl font-semibold"><dt>Total</dt><dd>{formatMoney(totals.total)}</dd></div></dl></div>
      {state.message ? <p role="alert" className="mt-3 border-l-2 border-[#b42318] bg-red-50 p-3 text-xs text-[#b42318]">{state.message}</p> : null}
      <div className="mt-4 grid gap-3 sm:grid-cols-2"><button disabled={pending || !cart.length} className="focus-ring h-12 border border-[#dfe3e1] bg-white text-[10px] font-bold uppercase tracking-[.1em] disabled:opacity-50">{pending ? "Completing…" : "Complete sale"}</button><button name="print" value="1" disabled={pending || !cart.length} className="focus-ring h-12 bg-[#057c73] text-[10px] font-bold uppercase tracking-[.1em] text-white disabled:opacity-50">Pay &amp; print <kbd className="ml-2 border border-white/40 px-1.5 py-0.5">F9</kbd></button></div>
    </form>
  </div>;
}
