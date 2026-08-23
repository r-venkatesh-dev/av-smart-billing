import Link from "next/link";
import {
  ArrowRight,
  Barcode,
  Check,
  Cloud,
  FileText,
  Monitor,
  Printer,
  ShieldCheck,
  Smartphone,
  WifiOff,
} from "lucide-react";
import { PublicSite } from "@/components/public-site";

export const metadata = {
  title: "Billing software for shops",
  description:
    "AV Smartbilling provides practical Android and computer billing, invoices, inventory, reports, thermal printing, and secure licensing for shops.",
};

const highlights = [
  {
    icon: Barcode,
    title: "Fast billing",
    detail: "Barcode scanning, product discounts and customer billing.",
  },
  {
    icon: WifiOff,
    title: "Offline ready",
    detail: "Continue essential shop billing when internet is unavailable.",
  },
  {
    icon: Printer,
    title: "Flexible receipts",
    detail: "Share PDF bills or print A4, 58mm and 80mm receipts.",
  },
  {
    icon: Cloud,
    title: "Optional cloud",
    detail: "Use controlled backup and online billing when your shop needs it.",
  },
];

export default function HomePage() {
  return (
    <PublicSite>
      <section className="border-b border-[#dfe3e1] bg-white">
        <div className="mx-auto grid max-w-6xl gap-7 px-4 py-8 sm:px-5 sm:py-10 lg:grid-cols-[1.15fr_.85fr] lg:items-center">
          <div>
            <p className="text-[10px] font-bold uppercase tracking-[.2em] text-[#057c73]">
              Billing made practical
            </p>
            <h1 className="mt-3 max-w-3xl text-4xl leading-[1.05] tracking-[-.045em] sm:text-5xl">
              Simple billing for busy shop owners.
            </h1>
            <p className="mt-4 max-w-2xl text-sm leading-6 text-[#6d716f] sm:text-base">
              Create bills, manage products and stock, serve customers, review
              reports, and print professional invoices from Android phones or
              computers.
            </p>
            <div className="mt-5 flex flex-wrap gap-3">
              <Link
                href="/subscribe"
                className="focus-ring inline-flex h-11 items-center gap-2 bg-[#057c73] px-5 text-[11px] font-bold uppercase tracking-[.09em] text-white"
              >
                Purchase activation <ArrowRight size={15} />
              </Link>
              <Link
                href="/products"
                className="focus-ring inline-flex h-11 items-center border border-[#057c73] px-5 text-[11px] font-bold uppercase tracking-[.09em] text-[#035f58]"
              >
                Explore products
              </Link>
            </div>
            <div className="mt-5 flex flex-wrap gap-x-5 gap-y-2 text-xs text-[#475467]">
              {[
                "No customer login required",
                "Secure Razorpay checkout",
                "One-time activation key",
              ].map((item) => (
                <span key={item} className="flex items-center gap-1.5">
                  <Check size={14} className="text-[#057c73]" />
                  {item}
                </span>
              ))}
            </div>
          </div>
          <aside className="border border-[#dfe3e1] bg-[#f7f8f7] p-5">
            <div className="flex items-center justify-between border-b border-[#dfe3e1] pb-4">
              <div>
                <p className="text-[10px] font-bold uppercase tracking-[.14em] text-[#6d716f]">
                  Available for
                </p>
                <h2 className="mt-1 text-2xl">Mobile and Computer</h2>
              </div>
              <span className="grid size-11 place-items-center bg-[#e6f2f0] text-[#057c73]">
                <FileText size={23} />
              </span>
            </div>
            <div className="mt-4 grid grid-cols-2 gap-3">
              <div className="bg-white p-4">
                <Smartphone className="text-[#057c73]" size={22} />
                <strong className="mt-3 block text-sm">Android app</strong>
                <span className="mt-1 block text-xs leading-5 text-[#6d716f]">
                  Mobile-first billing at the counter.
                </span>
              </div>
              <div className="bg-white p-4">
                <Monitor className="text-[#057c73]" size={22} />
                <strong className="mt-3 block text-sm">Billing software</strong>
                <span className="mt-1 block text-xs leading-5 text-[#6d716f]">
                  Full workspace for PCs and laptops.
                </span>
              </div>
            </div>
          </aside>
        </div>
      </section>
      <section className="mx-auto max-w-6xl px-4 py-7 sm:px-5 sm:py-8">
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {highlights.map(({ icon: Icon, title, detail }) => (
            <article
              key={title}
              className="border border-[#dfe3e1] bg-white p-4"
            >
              <Icon size={19} className="text-[#057c73]" />
              <h2 className="mt-3 text-lg">{title}</h2>
              <p className="mt-1 text-xs leading-5 text-[#6d716f]">{detail}</p>
            </article>
          ))}
        </div>
        <div className="mt-6 flex flex-col gap-4 border border-[#057c73] bg-[#e6f2f0] p-5 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-start gap-3">
            <ShieldCheck className="mt-0.5 shrink-0 text-[#057c73]" size={22} />
            <div>
              <h2 className="text-xl">Choose a plan and activate securely.</h2>
              <p className="mt-1 text-xs leading-5 text-[#475467]">
                Plan prices come from our billing platform. Payments are
                processed by Razorpay and verified before a license is issued.
              </p>
            </div>
          </div>
          <Link
            href="/plans"
            className="focus-ring shrink-0 bg-[#057c73] px-5 py-3 text-center text-[10px] font-bold uppercase tracking-[.1em] text-white"
          >
            View plans
          </Link>
        </div>
      </section>
    </PublicSite>
  );
}
