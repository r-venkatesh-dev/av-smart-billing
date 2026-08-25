import Link from "next/link";
import { Check, MonitorSmartphone, X } from "lucide-react";
import { PublicPageIntro, PublicSite } from "@/components/public-site";
import { formatMoney } from "@/lib/format";
import { createAdminClient } from "@/lib/supabase/admin";

export const metadata = {
  title: "Plans and pricing",
  description: "Compare AV Smartbilling plans, prices, device limits, offline validation, and included features.",
};
export const dynamic = "force-dynamic";

export default async function PublicPlansPage() {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("plans")
    .select("id, name, description, features, allow_online_billing, allow_cloud_backup, allow_reports_exports, is_publicly_visible, max_devices, validation_window_days, price_in_paise, interval, status")
    .or("status.eq.ACTIVE,is_publicly_visible.eq.true")
    .order("price_in_paise");
  const plans = error ? [] : (data ?? []).filter((plan) => (plan.status === "ACTIVE" && Number(plan.price_in_paise) > 0) || (plan.status === "INACTIVE" && plan.is_publicly_visible));

  return (
    <PublicSite>
      <PublicPageIntro
        eyebrow="Plans and pricing"
        title="Choose the plan that fits your shop."
        description="Every public plan includes secure activation and the device/offline limits shown below. Select a plan to continue to the purchase form and Razorpay checkout."
      />
      <section className="mx-auto max-w-6xl px-4 py-7 sm:px-5 sm:py-8">
        {error ? (
          <p className="border border-rose-200 bg-rose-50 p-4 text-sm text-rose-700">Plans are temporarily unavailable. Please try again later.</p>
        ) : plans.length ? (
          <div className="grid items-start gap-4 md:grid-cols-2 xl:grid-cols-3">
            {plans.map((plan) => {
              const purchasable = plan.status === "ACTIVE" && Number(plan.price_in_paise) > 0;
              const features = Array.isArray(plan.features)
                ? plan.features.filter((feature): feature is string => typeof feature === "string")
                : [];
              return (
                <article key={plan.id} className="border border-[#dfe3e1] bg-white p-5">
                  <div className="flex items-start justify-between gap-3">
                    <div><h2 className="text-2xl">{plan.name}</h2><p className="mt-1 text-xs leading-5 text-[#6d716f]">{plan.description}</p></div>
                    <span className="shrink-0 bg-[#e6f2f0] px-2.5 py-1.5 text-[9px] font-bold uppercase tracking-[.1em] text-[#057c73]">{purchasable ? "Available" : "Coming soon"}</span>
                  </div>
                  <p className="mt-4"><strong className="text-3xl tracking-[-.04em]">{formatMoney(Number(plan.price_in_paise))}</strong><span className="text-xs text-[#6d716f]"> / {String(plan.interval).toLowerCase()}</span></p>
                  <div className="my-4 h-px bg-[#dfe3e1]" />
                  <ul className="space-y-2 text-xs leading-5 text-[#475467]">
                    <li className="flex gap-2"><MonitorSmartphone size={15} className="mt-0.5 shrink-0 text-[#057c73]" />Up to {plan.max_devices} device{plan.max_devices === 1 ? "" : "s"}</li>
                    <li className="flex gap-2"><Check size={15} className="mt-0.5 shrink-0 text-[#057c73]" />{plan.validation_window_days}-day offline validation window</li>
                    <li className="flex gap-2"><Check size={15} className="mt-0.5 shrink-0 text-[#057c73]" />Secure signed activation</li>
                    <li className="flex gap-2"><Check size={15} className="mt-0.5 shrink-0 text-[#057c73]" />{plan.allow_online_billing ? "Offline + Online billing included" : "Offline billing only"}</li>
                    <li className="flex gap-2">{plan.allow_cloud_backup ? <Check size={15} className="mt-0.5 shrink-0 text-[#057c73]" /> : <X size={15} className="mt-0.5 shrink-0 text-rose-500" />}{plan.allow_cloud_backup ? "Cloud backup included" : "Cloud backup not included"}</li>
                    <li className="flex gap-2">{plan.allow_reports_exports ? <Check size={15} className="mt-0.5 shrink-0 text-[#057c73]" /> : <X size={15} className="mt-0.5 shrink-0 text-rose-500" />}{plan.allow_reports_exports ? "Reports & exports included" : "Reports & exports not included"}</li>
                    {features.map((feature) => <li key={feature} className="flex gap-2"><Check size={15} className="mt-0.5 shrink-0 text-[#057c73]" />{feature}</li>)}
                  </ul>
                  {purchasable ? <Link href={`/subscribe?plan=${plan.id}`} className="mt-5 flex h-11 items-center justify-center bg-[#057c73] px-4 text-[10px] font-bold uppercase tracking-[.1em] text-white">Choose {plan.name}</Link> : <span className="mt-5 flex h-11 items-center justify-center border border-[#dfe3e1] bg-[#f4f5f4] px-4 text-[10px] font-bold uppercase tracking-[.1em] text-[#8a908d]">Not available for purchase</span>}
                </article>
              );
            })}
          </div>
        ) : (
          <p className="border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">No public purchase plans are currently available.</p>
        )}
        <p className="mt-5 text-center text-xs leading-5 text-[#6d716f]">Need help choosing? Review the product details or contact support before purchasing.</p>
      </section>
    </PublicSite>
  );
}
