import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft, CreditCard } from "lucide-react";
import { PrintInvoiceButton } from "@/components/print-invoice-button";
import { StatusBadge } from "@/components/ui";
import { getBillingInvoice } from "@/data/billing";
import { formatDate, formatMoney } from "@/lib/format";

function quantity(value: number) {
  return new Intl.NumberFormat("en-IN", { maximumFractionDigits: 3 }).format(value);
}

export default async function Page({ params, searchParams }: PageProps<"/billing/invoices/[id]">) {
  const [{ id }, query] = await Promise.all([params, searchParams]);
  const { business, invoice } = await getBillingInvoice(id);
  if (!business || !invoice) notFound();
  const autoPrint = query.print === "1";
  const customer = invoice.customer;

  return <div className="mx-auto max-w-5xl space-y-5">
    <div className="screen-only flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <Link href="/billing/invoices" className="focus-ring inline-flex items-center gap-2 text-[11px] font-bold uppercase tracking-[.1em] text-[#057c73]"><ArrowLeft size={15} />All invoices</Link>
      <div className="flex flex-wrap gap-3">{invoice.balanceInPaise > 0 && invoice.status !== "CANCELLED" ? <Link href={`/billing/payments/new?invoiceId=${invoice.id}`} className="focus-ring inline-flex h-11 items-center justify-center gap-2 border border-[#dfe3e1] bg-white px-5 text-[11px] font-bold uppercase tracking-[.1em]"><CreditCard size={16} />Record payment</Link> : null}<PrintInvoiceButton autoPrint={autoPrint} /></div>
    </div>

    <article className="invoice-print-sheet surface bg-white px-5 py-7 sm:px-10 sm:py-10">
      <header className="flex flex-col gap-8 border-b-2 border-[#26272a] pb-8 sm:flex-row sm:items-start sm:justify-between">
        <div><p className="text-[10px] font-bold uppercase tracking-[.22em] text-[#057c73]">AV Smartbilling</p><h1 className="mt-2 text-3xl">{business.companyName}</h1><div className="mt-3 max-w-sm whitespace-pre-line text-xs leading-5 text-[#6d716f]">{business.address || "Business address not configured"}</div><p className="mt-2 text-xs text-[#6d716f]">{[business.phone, business.email].filter(Boolean).join(" · ")}</p>{business.gstin ? <p className="mt-1 text-xs font-semibold">GSTIN: {business.gstin}</p> : null}</div>
        <div className="sm:text-right"><p className="text-[11px] font-bold uppercase tracking-[.18em] text-[#6d716f]">Tax invoice</p><p className="mt-2 font-mono text-xl font-bold">{invoice.invoiceNumber}</p><div className="mt-3"><StatusBadge status={invoice.status} /></div></div>
      </header>

      <section className="grid gap-7 border-b border-[#dfe3e1] py-7 sm:grid-cols-2">
        <div><p className="text-[10px] font-bold uppercase tracking-[.16em] text-[#8a908d]">Bill to</p><h2 className="mt-2 text-xl">{customer.name}</h2><div className="mt-2 text-xs leading-5 text-[#6d716f]"><p className="whitespace-pre-line">{customer.address}</p><p>{[customer.phone, customer.email].filter(Boolean).join(" · ")}</p>{customer.gstin ? <p className="font-semibold text-[#26272a]">GSTIN: {customer.gstin}</p> : null}</div></div>
        <dl className="grid grid-cols-2 gap-5 sm:text-right"><div><dt className="text-[10px] font-bold uppercase tracking-[.14em] text-[#8a908d]">Invoice date</dt><dd className="mt-1 text-sm font-semibold">{formatDate(invoice.issuedAt)}</dd></div><div><dt className="text-[10px] font-bold uppercase tracking-[.14em] text-[#8a908d]">Due date</dt><dd className="mt-1 text-sm font-semibold">{invoice.dueAt ? formatDate(invoice.dueAt) : "On receipt"}</dd></div></dl>
      </section>

      <div className="my-7 overflow-x-auto"><table className="w-full min-w-[680px] text-left text-xs"><thead><tr className="border-b-2 border-[#26272a] text-[10px] uppercase tracking-[.12em] text-[#6d716f]"><th className="py-3 pr-4">Item</th><th className="px-3 py-3">SKU</th><th className="px-3 py-3 text-right">Qty</th><th className="px-3 py-3 text-right">Rate</th><th className="px-3 py-3 text-right">Tax</th><th className="py-3 pl-3 text-right">Amount</th></tr></thead><tbody>{invoice.items.map((item) => <tr key={item.id} className="border-b border-[#dfe3e1]"><td className="py-4 pr-4"><strong className="block text-sm">{item.description}</strong><span className="text-[#8a908d]">per {item.unit}</span></td><td className="px-3 py-4 font-mono text-[#6d716f]">{item.sku}</td><td className="px-3 py-4 text-right">{quantity(item.quantity)}</td><td className="px-3 py-4 text-right">{formatMoney(item.unitPriceInPaise)}</td><td className="px-3 py-4 text-right">{item.taxRateBasisPoints / 100}%</td><td className="py-4 pl-3 text-right font-semibold">{formatMoney(item.subtotalInPaise + item.taxInPaise)}</td></tr>)}</tbody></table></div>

      <section className="flex flex-col gap-7 border-b border-[#dfe3e1] pb-7 sm:flex-row sm:items-start sm:justify-between"><div className="max-w-md">{invoice.notes ? <><p className="text-[10px] font-bold uppercase tracking-[.16em] text-[#8a908d]">Notes</p><p className="mt-2 whitespace-pre-line text-xs leading-5 text-[#6d716f]">{invoice.notes}</p></> : null}</div><dl className="w-full max-w-xs space-y-3 text-sm"><div className="flex justify-between"><dt className="text-[#6d716f]">Subtotal</dt><dd>{formatMoney(invoice.subtotalInPaise)}</dd></div><div className="flex justify-between"><dt className="text-[#6d716f]">Tax</dt><dd>{formatMoney(invoice.taxInPaise)}</dd></div><div className="flex justify-between border-t-2 border-[#26272a] pt-3 text-lg font-bold"><dt>Total</dt><dd>{formatMoney(invoice.totalInPaise)}</dd></div><div className="flex justify-between text-emerald-700"><dt>Paid</dt><dd>- {formatMoney(invoice.paidInPaise)}</dd></div><div className="flex justify-between bg-[#e6f2f0] px-3 py-2 font-bold text-[#035f58]"><dt>Balance due</dt><dd>{formatMoney(invoice.balanceInPaise)}</dd></div></dl></section>

      {invoice.payments.length ? <section className="mt-7"><h2 className="text-lg">Payment history</h2><div className="mt-3 overflow-x-auto"><table className="w-full min-w-[560px] text-left text-xs"><thead className="text-[10px] uppercase tracking-[.12em] text-[#8a908d]"><tr><th className="py-2">Date</th><th className="py-2">Method</th><th className="py-2">Reference</th><th className="py-2 text-right">Amount</th></tr></thead><tbody>{invoice.payments.map((payment) => <tr key={payment.id} className="border-t border-[#dfe3e1]"><td className="py-3">{formatDate(payment.paidAt)}</td><td className="py-3">{payment.method.replaceAll("_", " ")}</td><td className="py-3 text-[#6d716f]">{payment.reference || "—"}</td><td className="py-3 text-right font-semibold">{formatMoney(payment.amountInPaise)}</td></tr>)}</tbody></table></div></section> : null}

      <footer className="mt-10 flex items-end justify-between border-t border-[#dfe3e1] pt-5 text-[10px] text-[#8a908d]"><p>Generated by AV Smartbilling</p><p className="text-right">Thank you for your business.</p></footer>
    </article>
  </div>;
}
