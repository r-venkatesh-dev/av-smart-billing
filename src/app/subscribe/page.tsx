import { SubscriptionCheckout } from "@/app/subscribe/subscription-checkout";
import { PublicSite } from "@/components/public-site";
import { createAdminClient } from "@/lib/supabase/admin";

export const metadata = { title: "Purchase activation key" };
export const dynamic = "force-dynamic";

export default async function SubscribePage({ searchParams }: PageProps<"/subscribe">) {
  const requestedPlan = (await searchParams).plan;
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("plans")
    .select(
      "id, name, description, features, allow_online_billing, allow_cloud_backup, is_publicly_visible, max_devices, validation_window_days, price_in_paise, interval, status",
    )
    .or("status.eq.ACTIVE,is_publicly_visible.eq.true")
    .order("price_in_paise");
  const plans = error
    ? []
    : (data ?? []).filter((plan) => (plan.status === "ACTIVE" && Number(plan.price_in_paise) > 0) || (plan.status === "INACTIVE" && plan.is_publicly_visible)).map((plan) => ({
        id: plan.id,
        name: plan.name,
        description: plan.description,
        features: Array.isArray(plan.features) ? plan.features.filter((feature): feature is string => typeof feature === "string") : [],
        allowOnlineBilling: plan.allow_online_billing,
        allowCloudBackup: plan.allow_cloud_backup,
        maxDevices: plan.max_devices,
        validationWindowDays: plan.validation_window_days,
        priceInPaise: Number(plan.price_in_paise),
        interval: plan.interval as "WEEK" | "MONTH" | "QUARTER" | "YEAR",
        purchasable: plan.status === "ACTIVE" && Number(plan.price_in_paise) > 0,
      }));

  const initialPlanId = typeof requestedPlan === "string" && plans.some((plan) => plan.id === requestedPlan && plan.purchasable) ? requestedPlan : undefined;
  return (
    <PublicSite>
      <section className="mx-auto max-w-7xl px-4 py-6 sm:px-5 sm:py-8">
        <div className="mb-5 max-w-3xl">
          <p className="text-[10px] font-bold uppercase tracking-[.18em] text-[#057c73]">
            Get your activation key
          </p>
          <h1 className="mt-2 text-3xl tracking-[-.035em] sm:text-4xl">
            Start billing with confidence.
          </h1>
          <p className="mt-2 text-sm leading-6 text-[#6d716f]">
            Enter your shop details, choose a plan, and complete payment. Your
            activation key will be shown only once after Razorpay confirms the
            payment.
          </p>
        </div>
        <SubscriptionCheckout plans={plans} plansUnavailable={Boolean(error)} initialPlanId={initialPlanId} />
      </section>
    </PublicSite>
  );
}
