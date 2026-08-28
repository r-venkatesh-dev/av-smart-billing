import { generateLicenseKey, hashLicenseKey, licenseKeyHint } from "@/lib/license-key";
import { encryptLicenseKey } from "@/lib/license-key-vault";
import { createRazorpayOrder, getRazorpayEnv, getSubscriptionLicenseCreatedBy } from "@/lib/razorpay";
import { createAdminClient } from "@/lib/supabase/admin";
import { subscriptionOrderSchema } from "@/lib/validation/subscription";

export const runtime = "nodejs";

function expiryFor(interval: string) {
  const expiry = new Date();
  if (interval === "WEEK") expiry.setDate(expiry.getDate() + 7);
  else if (interval === "MONTH") expiry.setMonth(expiry.getMonth() + 1);
  else if (interval === "QUARTER") expiry.setMonth(expiry.getMonth() + 3);
  else if (interval === "YEAR") expiry.setFullYear(expiry.getFullYear() + 1);
  else throw new Error("Unsupported plan interval");
  return expiry.toISOString();
}

export async function POST(request: Request) {
  const parsed = subscriptionOrderSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) {
    return Response.json({ ok: false, message: "Please check the customer and plan details.", errors: parsed.error.flatten().fieldErrors }, { status: 400 });
  }

  const supabase = createAdminClient();
  const recentCutoff = new Date(Date.now() - 15 * 60 * 1000).toISOString();
  const [recentEmailOrders, recentPhoneOrders] = await Promise.all([
    supabase.from("subscription_orders").select("id", { count: "exact", head: true }).eq("email", parsed.data.email).gte("created_at", recentCutoff),
    supabase.from("subscription_orders").select("id", { count: "exact", head: true }).eq("phone", parsed.data.phone).gte("created_at", recentCutoff),
  ]);
  if ((recentEmailOrders.count ?? 0) >= 5 || (recentPhoneOrders.count ?? 0) >= 5) {
    return Response.json({ ok: false, message: "Too many payment attempts. Please wait 15 minutes and try again." }, { status: 429 });
  }
  const { data: plan, error: planError } = await supabase
    .from("plans")
    .select("id, name, description, price_in_paise, interval, status")
    .eq("id", parsed.data.planId)
    .eq("status", "ACTIVE")
    .maybeSingle();
  if (planError) {
    console.error("Subscription plan lookup failed", planError);
    return Response.json({ ok: false, message: "Plans are temporarily unavailable." }, { status: 500 });
  }
  if (!plan || Number(plan.price_in_paise) < 0) {
    return Response.json({ ok: false, message: "The selected plan is not available for online purchase." }, { status: 409 });
  }

  const purchase = {
    plan_id: plan.id,
    company_name: parsed.data.companyName,
    contact_person: parsed.data.contactPerson,
    email: parsed.data.email,
    phone: parsed.data.phone,
    address: parsed.data.address,
    gstin: parsed.data.gstin || null,
    plan_name: plan.name,
    amount_in_paise: Number(plan.price_in_paise),
    status: "CREATED",
  };
  const { data: orderRecord, error: insertError } = await supabase
    .from("subscription_orders")
    .insert(purchase)
    .select("id")
    .single();
  if (insertError) {
    console.error("Subscription order insert failed", insertError);
    return Response.json({ ok: false, message: "Unable to start this purchase. Please try again." }, { status: 500 });
  }

  if (purchase.amount_in_paise === 0) {
    try {
      const key = generateLicenseKey();
      const expiresAt = expiryFor(plan.interval);
      const { data: completion, error: completionError } = await supabase.rpc("finalize_free_subscription", {
        p_subscription_order_id: orderRecord.id,
        p_license_key_hash: hashLicenseKey(key),
        p_license_key_hint: licenseKeyHint(key),
        p_license_key_ciphertext: encryptLicenseKey(key),
        p_expires_at: expiresAt,
        p_created_by: getSubscriptionLicenseCreatedBy(),
      });
      if (completionError) throw new Error(completionError.message);
      const result = Array.isArray(completion) ? completion[0] : completion;
      if (!result?.license_id || result.already_completed) {
        return Response.json({ ok: false, message: "The activation key for this free plan was already issued. Contact support if you did not save it." }, { status: 409 });
      }
      return Response.json({
        ok: true,
        requiresPayment: false,
        licenseKey: key,
        expiresAt,
        planName: plan.name,
      }, { headers: { "Cache-Control": "no-store" } });
    } catch (error) {
      console.error("Free subscription finalization failed", error);
      await supabase.from("subscription_orders").update({
        status: "FAILED",
        failure_code: "FREE_LICENSE_CREATION_FAILED",
        failure_description: "Unable to create the free-plan license.",
      }).eq("id", orderRecord.id).eq("status", "CREATED");
      return Response.json({ ok: false, message: "Unable to generate the activation key. Please try again or contact support." }, { status: 500 });
    }
  }

  try {
    const razorpayOrder = await createRazorpayOrder({
      amount: purchase.amount_in_paise,
      receipt: `sub_${orderRecord.id.replaceAll("-", "").slice(0, 28)}`,
      notes: { subscription_order_id: orderRecord.id, plan_id: plan.id },
    });
    const { error } = await supabase.from("subscription_orders").update({
      razorpay_order_id: razorpayOrder.id,
      status: "PAYMENT_PENDING",
    }).eq("id", orderRecord.id).eq("status", "CREATED");
    if (error) throw new Error(error.message);

    return Response.json({
      ok: true,
      requiresPayment: true,
      keyId: getRazorpayEnv().RAZORPAY_KEY_ID,
      subscriptionOrderId: orderRecord.id,
      razorpayOrderId: razorpayOrder.id,
      amount: purchase.amount_in_paise,
      currency: "INR",
      planName: plan.name,
      description: plan.description,
      prefill: { name: parsed.data.contactPerson, email: parsed.data.email, contact: parsed.data.phone },
    }, { headers: { "Cache-Control": "no-store" } });
  } catch (error) {
    console.error("Razorpay order creation failed", error);
    await supabase.from("subscription_orders").update({ status: "FAILED", failure_code: "ORDER_CREATION_FAILED", failure_description: "Unable to create Razorpay order." }).eq("id", orderRecord.id);
    return Response.json({ ok: false, message: "Payment service is unavailable. No money was charged." }, { status: 503 });
  }
}
