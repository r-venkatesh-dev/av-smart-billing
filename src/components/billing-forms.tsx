"use client";

import Link from "next/link";
import { useActionState, useEffect, useRef, useState } from "react";
import { useFormStatus } from "react-dom";
import { X } from "lucide-react";
import { createBillingBusiness, createBillingCustomer, createBillingInvoice, createBillingPayment, createBillingProduct, updateBillingBusiness, updateBillingProduct, type BillingFormState } from "@/app/billing/actions";
import { ThemedDatePicker, ThemedSelect } from "@/components/themed-controls";

const initialState: BillingFormState = {};
const inputClass = "focus-ring h-11 w-full rounded-xl border border-[#dfe3eb] bg-white px-3 text-sm";

function Submit({ children }: { children: string }) {
  const { pending } = useFormStatus();
  return <button disabled={pending} className="focus-ring rounded-xl bg-[#5b4df5] px-5 py-3 text-[11px] font-bold uppercase tracking-[.1em] text-white disabled:opacity-60">{pending ? "Saving…" : children}</button>;
}

function Message({ state }: { state: BillingFormState }) {
  return state.message ? <p role="alert" className="rounded-xl bg-rose-50 p-3 text-sm text-rose-700">{state.message}</p> : null;
}

function ErrorText({ state, name }: { state: BillingFormState; name: string }) {
  return state.errors?.[name]?.[0] ? <span className="mt-1 block text-xs text-rose-600">{state.errors[name][0]}</span> : null;
}

function Actions({ cancel, label }: { cancel: string; label: string }) {
  return <div className="flex justify-end gap-3 border-t border-[#eaecf0] pt-5"><Link href={cancel} className="rounded-xl border border-[#dfe3eb] px-5 py-3 text-[11px] font-bold uppercase tracking-[.1em]">Cancel</Link><Submit>{label}</Submit></div>;
}

export function BillingBusinessForm({ business }: { business?: { companyName: string; contactPerson: string; email: string | null; phone: string; address: string; gstin: string | null; stateCode: string; currencyCode: string; invoicePrefix: string; lowStockThreshold: number; invoiceTerms: string; invoiceFooter: string; thermalPaperWidth: 58 | 80 } }) {
  const [state, action] = useActionState(business ? updateBillingBusiness : createBillingBusiness, initialState);
  return <form action={action} className="surface space-y-5 p-6"><div className="grid gap-5 sm:grid-cols-2"><label><span className="mb-2 block text-sm font-semibold">Company name</span><input name="companyName" required defaultValue={business?.companyName} className={inputClass} /><ErrorText state={state} name="companyName" /></label><label><span className="mb-2 block text-sm font-semibold">Contact person</span><input name="contactPerson" defaultValue={business?.contactPerson} className={inputClass} /></label><label><span className="mb-2 block text-sm font-semibold">Email</span><input name="email" type="email" defaultValue={business?.email ?? ""} className={inputClass} /><ErrorText state={state} name="email" /></label><label><span className="mb-2 block text-sm font-semibold">Phone</span><input name="phone" defaultValue={business?.phone} className={inputClass} /></label><label><span className="mb-2 block text-sm font-semibold">Business GSTIN</span><input name="gstin" defaultValue={business?.gstin ?? ""} className={inputClass} /><ErrorText state={state} name="gstin" /></label><label><span className="mb-2 block text-sm font-semibold">GST state code</span><input name="stateCode" inputMode="numeric" maxLength={2} defaultValue={business?.stateCode ?? ""} className={inputClass} /><ErrorText state={state} name="stateCode" /></label><label><span className="mb-2 block text-sm font-semibold">Currency</span><input name="currencyCode" required defaultValue={business?.currencyCode ?? "INR"} maxLength={3} className={inputClass} /></label><label><span className="mb-2 block text-sm font-semibold">Invoice prefix</span><input name="invoicePrefix" required defaultValue={business?.invoicePrefix ?? "INV"} className={inputClass} /></label><label><span className="mb-2 block text-sm font-semibold">Low-stock threshold</span><input name="lowStockThreshold" type="number" min="0" step="0.001" required defaultValue={business?.lowStockThreshold ?? 5} className={inputClass} /></label><label><span className="mb-2 block text-sm font-semibold">Thermal receipt width</span><select name="thermalPaperWidth" defaultValue={business?.thermalPaperWidth ?? 80} className={inputClass}><option value="80">80 mm</option><option value="58">58 mm</option></select></label><label className="sm:col-span-2"><span className="mb-2 block text-sm font-semibold">Address</span><textarea name="address" defaultValue={business?.address} rows={4} className="focus-ring w-full rounded-xl border border-[#dfe3eb] bg-white p-3 text-sm" /></label><label className="sm:col-span-2"><span className="mb-2 block text-sm font-semibold">Default invoice terms</span><textarea name="invoiceTerms" defaultValue={business?.invoiceTerms} rows={3} className="focus-ring w-full rounded-xl border border-[#dfe3eb] bg-white p-3 text-sm" /></label><label className="sm:col-span-2"><span className="mb-2 block text-sm font-semibold">Invoice / receipt footer</span><textarea name="invoiceFooter" defaultValue={business?.invoiceFooter} rows={2} className="focus-ring w-full rounded-xl border border-[#dfe3eb] bg-white p-3 text-sm" /></label></div><Message state={state} /><Actions cancel={business ? "/billing/dashboard" : "/admin/dashboard"} label={business ? "Save settings" : "Create workspace"} /></form>;
}

export function BillingCustomerForm() {
  const [state, action] = useActionState(createBillingCustomer, initialState);
  return <form action={action} className="surface space-y-5 p-6"><div className="grid gap-5 sm:grid-cols-2"><label><span className="mb-2 block text-sm font-semibold">Customer name</span><input name="name" required className={inputClass} /><ErrorText state={state} name="name" /></label><label><span className="mb-2 block text-sm font-semibold">Phone</span><input name="phone" className={inputClass} /></label><label><span className="mb-2 block text-sm font-semibold">Email</span><input name="email" type="email" className={inputClass} /></label><label><span className="mb-2 block text-sm font-semibold">GSTIN</span><input name="gstin" className={inputClass} /></label><label className="sm:col-span-2"><span className="mb-2 block text-sm font-semibold">Address</span><textarea name="address" rows={4} className="focus-ring w-full rounded-xl border border-[#dfe3eb] bg-white p-3 text-sm" /></label></div><Message state={state} /><Actions cancel="/billing/customers" label="Create customer" /></form>;
}

export function BillingProductForm({ product }: { product?: { id: string; name: string; sku: string; barcode: string | null; category: string; hsnSac: string; description: string; unit: string; purchasePriceInPaise: number; priceInPaise: number; taxRateBasisPoints: number; stockQuantity: number; lowStockThreshold: number | null; status: string } }) {
  const formAction = product ? updateBillingProduct.bind(null, product.id) : createBillingProduct;
  const [state, action] = useActionState(formAction, initialState);
  const formRef = useRef<HTMLFormElement>(null);
  const confirmedRef = useRef(false);
  const [confirming, setConfirming] = useState(false);
  const [sku, setSku] = useState(product?.sku ?? "");
  const statusOptions = [{ value: "ACTIVE", label: "Active", description: "Available for new invoices" }, { value: "INACTIVE", label: "Inactive", description: "Hidden from new invoices" }];

  useEffect(() => {
    function escape(event: KeyboardEvent) {
      if (event.key === "Escape") setConfirming(false);
    }
    document.addEventListener("keydown", escape);
    return () => document.removeEventListener("keydown", escape);
  }, []);

  function submit(event: React.FormEvent<HTMLFormElement>) {
    if (!product || confirmedRef.current) {
      confirmedRef.current = false;
      return;
    }
    event.preventDefault();
    setConfirming(true);
  }

  function confirmSave() {
    confirmedRef.current = true;
    setConfirming(false);
    formRef.current?.requestSubmit();
  }

  return <>
    <form ref={formRef} action={action} onSubmit={submit} className="surface space-y-5 p-6">
      <div className="grid gap-5 sm:grid-cols-2">
        <label><span className="mb-2 block text-sm font-semibold">Product name</span><input name="name" required defaultValue={product?.name ?? ""} className={inputClass} /></label>
        <label><span className="mb-2 block text-sm font-semibold">SKU</span><span className="flex gap-2"><input name="sku" required value={sku} onChange={(event) => setSku(event.target.value)} className={inputClass} /><button type="button" onClick={() => setSku(`AV-${crypto.randomUUID().slice(0, 8).toUpperCase()}`)} className="focus-ring border border-[#dfe3e1] bg-[#f7f8f7] px-3 text-[10px] font-bold uppercase tracking-[.08em]">Generate</button></span><ErrorText state={state} name="sku" /></label>
        <label><span className="mb-2 block text-sm font-semibold">Barcode</span><input name="barcode" defaultValue={product?.barcode ?? ""} inputMode="numeric" className={inputClass} /><ErrorText state={state} name="barcode" /></label>
        <label><span className="mb-2 block text-sm font-semibold">Category</span><input name="category" defaultValue={product?.category ?? ""} className={inputClass} /></label>
        <label><span className="mb-2 block text-sm font-semibold">HSN / SAC</span><input name="hsnSac" defaultValue={product?.hsnSac ?? ""} className={inputClass} /></label>
        <label><span className="mb-2 block text-sm font-semibold">Unit</span><input name="unit" defaultValue={product?.unit ?? "unit"} required className={inputClass} /></label>
        <label><span className="mb-2 block text-sm font-semibold">Purchase price (₹)</span><input name="purchasePriceInRupees" type="number" min="0" step="0.01" required defaultValue={product ? (product.purchasePriceInPaise / 100).toFixed(2) : "0.00"} className={inputClass} /></label>
        <label><span className="mb-2 block text-sm font-semibold">Selling price (₹)</span><input name="priceInRupees" type="number" min="0" step="0.01" required defaultValue={product ? (product.priceInPaise / 100).toFixed(2) : ""} className={inputClass} /></label>
        <label><span className="mb-2 block text-sm font-semibold">GST rate (%)</span><input name="taxRatePercent" type="number" min="0" max="100" step="0.01" defaultValue={product ? (product.taxRateBasisPoints / 100).toFixed(2) : "0"} required className={inputClass} /></label>
        <label><span className="mb-2 block text-sm font-semibold">{product ? "Current stock" : "Opening stock"}</span><input name="stockQuantity" type="number" min="0" step="0.001" defaultValue={product?.stockQuantity ?? 0} required className={inputClass} /></label>
        <label><span className="mb-2 block text-sm font-semibold">Low-stock threshold</span><input name="lowStockThreshold" type="number" min="0" step="0.001" defaultValue={product?.lowStockThreshold ?? ""} placeholder="Use business default" className={inputClass} /></label>
        <ThemedSelect name="status" label="Status" options={statusOptions} defaultValue={product?.status ?? "ACTIVE"} required />
        <label className="sm:col-span-2"><span className="mb-2 block text-sm font-semibold">Description</span><textarea name="description" defaultValue={product?.description ?? ""} rows={3} className="focus-ring w-full rounded-xl border border-[#dfe3eb] bg-white p-3 text-sm" /></label>
      </div>
      <Message state={state} /><Actions cancel="/billing/products" label={product ? "Save product" : "Create product"} />
    </form>
    {product && confirming ? <div className="fixed inset-0 z-[80] grid place-items-center bg-[#26272a]/55 p-5" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setConfirming(false); }}><div role="dialog" aria-modal="true" aria-labelledby={`save-product-${product.id}`} className="w-full max-w-md border border-[#dfe3e1] bg-[#f7f8f7] p-6 text-left shadow-2xl"><div className="flex items-start justify-between gap-4"><div><p className="text-[10px] font-bold uppercase tracking-[.16em] text-[#057c73]">Confirm product update</p><h2 id={`save-product-${product.id}`} className="mt-2 text-2xl font-normal">Save changes to {product.name}?</h2></div><button type="button" onClick={() => setConfirming(false)} aria-label="Close confirmation" className="focus-ring grid size-9 place-items-center border border-[#dfe3e1]"><X size={17} /></button></div><p className="mt-4 text-sm leading-6 text-[#6d716f]">This updates product details and creates an inventory adjustment whenever stock changes. Existing invoice snapshots remain unchanged.</p><div className="mt-6 flex justify-end gap-3 border-t border-[#dfe3e1] pt-5"><button type="button" onClick={() => setConfirming(false)} className="border border-[#dfe3e1] px-4 py-2.5 text-[10px] font-bold uppercase tracking-[.1em]">Review again</button><button type="button" onClick={confirmSave} className="bg-[#057c73] px-4 py-2.5 text-[10px] font-bold uppercase tracking-[.1em] text-white">Confirm &amp; save</button></div></div></div> : null}
  </>;
}

export function BillingInvoiceForm({ customers, products }: { customers: { id: string; name: string; phone: string }[]; products: { id: string; name: string; sku: string; stockQuantity: number }[] }) {
  const [state, action] = useActionState(createBillingInvoice, initialState);
  const [selectedCustomer, setSelectedCustomer] = useState("");
  const customerOptions = [{ value: "WALK_IN", label: "Walk-in customer", description: "Enter customer name and mobile for this invoice" }, ...customers.map((customer) => ({ value: customer.id, label: customer.name, description: customer.phone || "Saved customer" }))];
  const productOptions = products.map((product) => ({ value: product.id, label: product.name, description: `${product.sku} · ${product.stockQuantity} available${product.stockQuantity <= 0 ? " · Out of stock" : ""}`, disabled: product.stockQuantity <= 0 }));
  return <form action={action} className="surface space-y-5 p-6"><div className="grid gap-5 sm:grid-cols-2"><div className="sm:col-span-2"><ThemedSelect name="customerId" label="Customer" options={customerOptions} placeholder="Search or select a customer" required searchable emptyMessage="No matching customers found." onValueChange={setSelectedCustomer} /><ErrorText state={state} name="customerId" /></div>{selectedCustomer === "WALK_IN" ? <div className="grid gap-5 border-l-2 border-[#057c73] bg-[#e6f2f0]/60 p-4 sm:col-span-2 sm:grid-cols-2"><label><span className="mb-2 block text-sm font-semibold">Walk-in customer name</span><input name="walkInName" required className={inputClass} placeholder="Customer's full name" /><ErrorText state={state} name="walkInName" /></label><label><span className="mb-2 block text-sm font-semibold">Mobile number</span><input name="walkInPhone" type="tel" required className={inputClass} placeholder="Customer's mobile number" /><ErrorText state={state} name="walkInPhone" /></label></div> : <><input type="hidden" name="walkInName" value="" /><input type="hidden" name="walkInPhone" value="" /></>}<div><ThemedSelect name="productId" label="Product" options={productOptions} placeholder="Select product" required searchable emptyMessage="No active products found. Add a product first." /><ErrorText state={state} name="productId" /></div><label><span className="mb-2 block text-sm font-semibold">Quantity</span><input name="quantity" type="number" min="0.001" step="0.001" defaultValue="1" required className={inputClass} /><ErrorText state={state} name="quantity" /></label><ThemedDatePicker name="dueAt" label="Due date" /><label className="sm:col-span-2"><span className="mb-2 block text-sm font-semibold">Notes</span><textarea name="notes" rows={3} className="focus-ring w-full rounded-xl border border-[#dfe3eb] bg-white p-3 text-sm" /></label></div>{products.length && products.every((product) => product.stockQuantity <= 0) ? <p className="border-l-2 border-amber-500 bg-amber-50 p-3 text-xs leading-5 text-amber-800">Products are visible, but every product is out of stock. Update stock before creating an invoice.</p> : null}<Message state={state} /><Actions cancel="/billing/invoices" label="Create invoice" /></form>;
}

export function BillingPaymentForm({ invoices, defaultInvoiceId = "" }: { invoices: { id: string; invoiceNumber: string; customerName: string; outstandingInPaise: number }[]; defaultInvoiceId?: string }) {
  const [state, action] = useActionState(createBillingPayment, initialState);
  const initialInvoice = invoices.find((invoice) => invoice.id === defaultInvoiceId);
  const [selectedInvoiceId, setSelectedInvoiceId] = useState(defaultInvoiceId);
  const [amount, setAmount] = useState(initialInvoice ? (initialInvoice.outstandingInPaise / 100).toFixed(2) : "");
  const selectedInvoice = invoices.find((invoice) => invoice.id === selectedInvoiceId);
  const invoiceOptions = invoices.map((invoice) => ({ value: invoice.id, label: `${invoice.invoiceNumber} · ${invoice.customerName}`, description: `₹${(invoice.outstandingInPaise / 100).toFixed(2)} outstanding` }));
  const methodOptions = [{ value: "CASH", label: "Cash" }, { value: "CARD", label: "Card" }, { value: "UPI", label: "UPI" }, { value: "BANK_TRANSFER", label: "Bank transfer" }, { value: "OTHER", label: "Other" }];
  function chooseInvoice(id: string) {
    const invoice = invoices.find((item) => item.id === id);
    setSelectedInvoiceId(id);
    setAmount(invoice ? (invoice.outstandingInPaise / 100).toFixed(2) : "");
  }
  return <form action={action} className="surface space-y-5 p-6"><div className="grid gap-5 sm:grid-cols-2"><div className="sm:col-span-2"><ThemedSelect name="invoiceId" label="Invoice" options={invoiceOptions} defaultValue={defaultInvoiceId} placeholder="Select outstanding invoice" required searchable emptyMessage="There are no outstanding invoices." onValueChange={chooseInvoice} /><ErrorText state={state} name="invoiceId" /></div><label><span className="mb-2 block text-sm font-semibold">Amount (₹)</span><input name="amountInRupees" type="number" min="0.01" max={selectedInvoice ? (selectedInvoice.outstandingInPaise / 100).toFixed(2) : undefined} step="0.01" required value={amount} onChange={(event) => setAmount(event.target.value)} placeholder={selectedInvoice ? undefined : "Select an invoice first"} className={inputClass} /><span className="mt-1 block text-xs text-[#8a908d]">{selectedInvoice ? `Outstanding amount auto-filled: ₹${(selectedInvoice.outstandingInPaise / 100).toFixed(2)}. Edit it for a partial payment.` : "The outstanding amount will be filled automatically."}</span><ErrorText state={state} name="amountInRupees" /></label><ThemedSelect name="method" label="Method" options={methodOptions} defaultValue="CASH" required /><label><span className="mb-2 block text-sm font-semibold">Reference</span><input name="reference" className={inputClass} /></label><label><span className="mb-2 block text-sm font-semibold">Notes</span><input name="notes" className={inputClass} /></label></div><Message state={state} /><Actions cancel="/billing/payments" label="Record payment" /></form>;
}
