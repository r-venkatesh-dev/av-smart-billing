import { captureRazorpayPayment, getRazorpayPayment, getSubscriptionLicenseCreatedBy, verifyCheckoutSignature } from "@/lib/razorpay";
import { generateLicenseKey, hashLicenseKey, licenseKeyHint } from "@/lib/license-key";
import { encryptLicenseKey } from "@/lib/license-key-vault";
import { createAdminClient } from "@/lib/supabase/admin";
import { subscriptionVerificationSchema } from "@/lib/validation/subscription";

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
  const parsed = subscriptionVerificationSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return Response.json({ ok: false, message: "Invalid payment response." }, { status: 400 });
  const input = parsed.data;
  if (!verifyCheckoutSignature(input.razorpayOrderId, input.razorpayPaymentId, input.razorpaySignature)) {
    return Response.json({ ok: false, message: "Payment verification failed. Please contact support if money was deducted." }, { status: 400 });
  }

  const supabase = createAdminClient();
  const { data: purchase, error } = await supabase
    .from("subscription_orders")
    .select("id, plan_id, amount_in_paise, currency, status, razorpay_order_id, plans(interval)")
    .eq("id", input.subscriptionOrderId)
    .maybeSingle();
  if (error || !purchase || purchase.razorpay_order_id !== input.razorpayOrderId) {
    return Response.json({ ok: false, message: "This subscription order could not be verified." }, { status: 404 });
  }
  if (purchase.status === "PAID") {
    return Response.json({ ok: false, message: "The activation key for this payment was already issued. Contact support if you did not save it." }, { status: 409 });
  }

  try {
    let payment = await getRazorpayPayment(input.razorpayPaymentId);
    const amount = Number(purchase.amount_in_paise);
    if (payment.order_id !== input.razorpayOrderId || payment.amount !== amount || payment.currency !== purchase.currency) {
      return Response.json({ ok: false, message: "Payment details do not match this subscription." }, { status: 400 });
    }
    if (payment.status === "authorized") {
      try {
        payment = await captureRazorpayPayment(payment.id, amount);
      } catch {
        payment = await getRazorpayPayment(payment.id);
      }
    }
    if (payment.status !== "captured") {
      return Response.json({ ok: false, message: "Payment is still processing. Please contact support before trying another payment." }, { status: 409 });
    }

    await supabase.from("subscription_orders").update({
      status: "PAYMENT_CAPTURED",
      latest_razorpay_payment_id: payment.id,
    }).eq("id", purchase.id).in("status", ["PAYMENT_PENDING", "PAYMENT_CAPTURED"]);

    const key = generateLicenseKey();
    const relation = Array.isArray(purchase.plans) ? purchase.plans[0] : purchase.plans;
    const expiresAt = expiryFor(relation?.interval ?? "YEAR");
    const { data: completion, error: completionError } = await supabase.rpc("finalize_subscription_purchase", {
      p_subscription_order_id: purchase.id,
      p_razorpay_order_id: input.razorpayOrderId,
      p_razorpay_payment_id: payment.id,
      p_license_key_hash: hashLicenseKey(key),
      p_license_key_hint: licenseKeyHint(key),
      p_expires_at: expiresAt,
      p_created_by: getSubscriptionLicenseCreatedBy(),
    });
    if (completionError) throw new Error(completionError.message);
    const result = Array.isArray(completion) ? completion[0] : completion;
    if (result?.already_completed) {
      return Response.json({ ok: false, message: "The activation key for this payment was already issued. Contact support if you did not save it." }, { status: 409 });
    }
    const protectedKey = await supabase.from("licenses").update({ license_key_ciphertext: encryptLicenseKey(key) }).eq("id", result?.license_id).is("license_key_ciphertext", null);
    if (protectedKey.error) throw new Error(protectedKey.error.message);
    return Response.json({ ok: true, licenseKey: key, expiresAt }, { headers: { "Cache-Control": "no-store" } });
  } catch (verificationError) {
    console.error("Subscription payment finalization failed", verificationError);
    return Response.json({ ok: false, message: "Payment was received but license creation needs attention. Please contact support and do not pay again." }, { status: 500 });
  }
}
