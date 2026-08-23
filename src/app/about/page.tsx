import { Cloud, HeartHandshake, ReceiptText, ShieldCheck } from "lucide-react";
import { PublicPageIntro, PublicSite } from "@/components/public-site";

export const metadata = { title: "About", description: "About AV Smartbilling and our practical billing products for shops and small businesses." };

export default function AboutPage() {
  return <PublicSite><PublicPageIntro eyebrow="About us" title="Built for dependable everyday billing." description="AV Smartbilling helps shop owners handle billing and business records with clear screens, practical workflows, and options that work across phones and computers." /><section className="mx-auto max-w-4xl px-4 py-7 sm:px-5 sm:py-8"><div className="grid gap-3 sm:grid-cols-2">{[
    { icon: ReceiptText, title: "Our product", body: "AV Smartbilling includes billing, products, customers, stock, invoices, reports, discounts, payment records and receipt sharing." },
    { icon: HeartHandshake, title: "Who it serves", body: "The software is designed for independent shops and growing businesses that need an understandable billing experience." },
    { icon: Cloud, title: "How data works", body: "Core mobile billing can work locally. Cloud backup and online billing are optional, controlled features that require internet." },
    { icon: ShieldCheck, title: "How licensing works", body: "Each purchased plan issues a secure activation key with defined device and validation limits. Keys are verified by our server." },
  ].map(({ icon: Icon, title, body }) => <article key={title} className="border border-[#dfe3e1] bg-white p-5"><Icon size={21} className="text-[#057c73]" /><h2 className="mt-3 text-xl">{title}</h2><p className="mt-1 text-sm leading-6 text-[#6d716f]">{body}</p></article>)}</div><div className="mt-5 border-l-2 border-[#057c73] bg-[#e6f2f0] p-4 text-sm leading-6 text-[#475467]">Our goal is straightforward: make daily billing quicker without forcing every shop owner to understand complicated accounting or software terminology.</div></section></PublicSite>;
}

