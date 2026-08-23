import Link from "next/link";
import { ReceiptIndianRupee, ShieldCheck } from "lucide-react";
import { SubscriptionCheckout } from "@/app/subscribe/subscription-checkout";
import { createAdminClient } from "@/lib/supabase/admin";

export const metadata = { title: "Purchase activation key" };
export const dynamic = "force-dynamic";

export default async function SubscribePage() {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("plans")
    .select("id, name, description, max_devices, validation_window_days, price_in_paise, interval")
    .eq("status", "ACTIVE")
    .gt("price_in_paise", 0)
    .order("price_in_paise");
  const plans = error ? [] : (data ?? []).map((plan) => ({
    id: plan.id,
    name: plan.name,
    description: plan.description,
    maxDevices: plan.max_devices,
    validationWindowDays: plan.validation_window_days,
    priceInPaise: Number(plan.price_in_paise),
    interval: plan.interval as "MONTH" | "YEAR",
  }));

  return <main className="min-h-screen bg-[#f7f8f7]">
    <header className="border-b border-[#dfe3e1] bg-white px-5 py-4"><div className="mx-auto flex max-w-6xl items-center justify-between"><Link href="/products" className="flex items-center gap-3"><span className="grid size-10 place-items-center bg-[#057c73] text-white"><ReceiptIndianRupee size={22} /></span><span><strong className="block text-sm">AV Smartbilling</strong><small className="text-[10px] uppercase tracking-[.15em] text-[#6d716f]">Secure subscription</small></span></Link><span className="hidden items-center gap-2 text-xs text-[#6d716f] sm:flex"><ShieldCheck size={16} className="text-[#057c73]" />Payment verified securely</span></div></header>
    <div className="mx-auto max-w-6xl px-5 py-9 sm:py-14"><div className="mb-9 max-w-3xl"><p className="text-[11px] font-bold uppercase tracking-[.18em] text-[#057c73]">Get your activation key</p><h1 className="mt-3 text-4xl tracking-[-.035em] sm:text-5xl">Start billing with confidence.</h1><p className="mt-4 text-sm leading-7 text-[#6d716f]">Enter your shop details, choose a plan, and complete payment. Your activation key will be shown only once after Razorpay confirms the payment.</p></div><SubscriptionCheckout plans={plans} plansUnavailable={Boolean(error)} /></div>
  </main>;
}

