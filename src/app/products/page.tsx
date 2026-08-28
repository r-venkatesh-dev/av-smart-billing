import Link from "next/link";
import { Check, Download, Monitor, Smartphone } from "lucide-react";
import { GooglePlayIcon } from "@/components/platform-icons";
import { PublicSite } from "@/components/public-site";
import { publicDownloads } from "@/lib/public-downloads";

export const metadata = { title: "Billing products" };

const products = [
  { icon: Smartphone, name: "AV Smartbilling Mobile", description: "Fast, offline-first billing for Android phones and shop counters.", features: ["Barcode scanning and quick billing", "A4, WhatsApp and thermal bill sharing", "Products, customers, reports and stock alerts", "Optional cloud backup and online mode"], kind: "mobile" },
  { icon: Monitor, name: "AV Smartbilling Software", description: "A complete billing workspace for PCs and laptops.", features: ["Professional invoices and payment tracking", "Customer and inventory management", "Business reports and exports", "Secure license and device control"], kind: "desktop" },
] as const;

export default function ProductsPage() {
  return <PublicSite>
    <section className="mx-auto max-w-6xl px-4 py-7 sm:px-5 sm:py-9">
      <div className="max-w-3xl"><p className="text-[10px] font-bold uppercase tracking-[.18em] text-[#057c73]">Billing made practical</p><h1 className="mt-2 text-3xl tracking-[-.035em] sm:text-4xl">Choose the right billing experience for your shop.</h1><p className="mt-2 text-sm leading-6 text-[#6d716f]">Use the mobile app at the counter or manage billing from a computer. Both products are designed for simple daily use and dependable business records.</p></div>
      <div className="mt-6 grid gap-4 lg:grid-cols-2">{products.map((product) => { const Icon = product.icon; return <article key={product.name} className="flex flex-col border border-[#dfe3e1] bg-white p-5"><div className="flex items-center gap-3"><span className="grid size-10 shrink-0 place-items-center bg-[#e6f2f0] text-[#057c73]"><Icon size={21} /></span><div><h2 className="text-xl">{product.name}</h2><p className="mt-0.5 text-xs leading-5 text-[#6d716f]">{product.description}</p></div></div><ul className="mt-4 grid flex-1 gap-2 text-xs sm:grid-cols-2">{product.features.map((feature) => <li key={feature} className="flex gap-2"><Check size={15} className="mt-0.5 shrink-0 text-[#057c73]" />{feature}</li>)}</ul><div className="mt-5 border-t border-[#eef0f4] pt-4">{product.kind === "mobile" ? <a href={publicDownloads.playStoreUrl} target="_blank" rel="noreferrer" aria-label="Get AV Smartbilling on Google Play" className="focus-ring inline-flex min-h-12 items-center gap-3 rounded-md bg-[#171a1f] px-5 text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-black hover:shadow-md"><GooglePlayIcon className="size-7 shrink-0" /><span className="text-left"><small className="block text-[8px] font-medium uppercase tracking-[.14em] text-white/75">Get it on</small><strong className="block text-base leading-5">Google Play</strong></span></a> : <Link href="/downloads" className="focus-ring inline-flex min-h-12 items-center gap-2 bg-[#057c73] px-5 text-[10px] font-bold uppercase tracking-[.1em] text-white"><Download size={17} />Download software</Link>}</div></article>; })}</div>
      <div className="mt-6 flex flex-col gap-3 border border-[#057c73] bg-[#e6f2f0] p-5 sm:flex-row sm:items-center sm:justify-between"><div><h2 className="text-xl">Ready to activate?</h2><p className="mt-1 text-xs leading-5 text-[#6d716f]">Purchase a plan securely and receive your activation key after payment verification.</p></div><Link href="/plans" className="shrink-0 bg-[#057c73] px-5 py-3 text-center text-[10px] font-bold uppercase tracking-[.1em] text-white">View plans and purchase</Link></div>
    </section>
  </PublicSite>;
}
