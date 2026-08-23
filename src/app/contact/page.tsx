import Link from "next/link";
import { CircleHelp, CreditCard, KeyRound, MessageSquareText } from "lucide-react";
import { PublicContactDetails, PublicPageIntro, PublicSite } from "@/components/public-site";

export const metadata = { title: "Contact and support", description: "Contact AV Smartbilling for purchase, payment, activation, and product support." };

export default function ContactPage() {
  return <PublicSite><PublicPageIntro eyebrow="Contact and support" title="Tell us what you need help with." description="For faster assistance, include the relevant order, payment, or masked license information. Never send card details, UPI PINs, passwords, or your complete activation key." /><section className="mx-auto grid max-w-4xl gap-4 px-4 py-7 sm:px-5 sm:py-8 md:grid-cols-[1fr_1.1fr]"><div className="border border-[#dfe3e1] bg-white p-5"><MessageSquareText size={22} className="text-[#057c73]" /><h2 className="mt-3 text-xl">Business contact</h2><div className="mt-3"><PublicContactDetails /></div></div><div className="grid gap-3">{[
    { icon: CreditCard, title: "Payment support", body: "Share the Razorpay payment ID, amount, date and the mobile number used during checkout." },
    { icon: KeyRound, title: "Activation support", body: "Share your shop name, plan name, device name and only the masked key shown in the admin record." },
    { icon: CircleHelp, title: "Product support", body: "Describe the screen, action and error message. A screenshot is helpful, but remove private customer information first." },
  ].map(({ icon: Icon, title, body }) => <article key={title} className="border border-[#dfe3e1] bg-white p-4"><div className="flex gap-3"><Icon size={19} className="mt-0.5 shrink-0 text-[#057c73]" /><div><h2 className="text-lg">{title}</h2><p className="mt-1 text-xs leading-5 text-[#6d716f]">{body}</p></div></div></article>)}<Link href="/subscribe" className="bg-[#057c73] px-4 py-3 text-center text-[10px] font-bold uppercase tracking-[.1em] text-white">View plans and purchase</Link></div></section></PublicSite>;
}

