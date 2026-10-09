import type { NextRequest } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { verifyRenewalSessionToken } from "@/lib/renewal-token";
import { captureRazorpayPayment, getRazorpayPayment, verifyCheckoutSignature } from "@/lib/razorpay";
import { z } from "zod";

export const runtime = "nodejs";

const verifySchema = z.object({
  token: z.string(),
  razorpayOrderId: z.string().optional(),
  razorpayPaymentId: z.string().optional(),
  razorpaySignature: z.string().optional(),
  isFree: z.boolean().optional(),
});

function calculateExtendedExpiry(currentExpiryIso: string, interval: string): Date {
  const now = new Date();
  const currentExpiry = new Date(currentExpiryIso);
  const baseDate = currentExpiry > now ? currentExpiry : now;
  const newExpiry = new Date(baseDate);

  if (interval === "WEEK") {
    newExpiry.setDate(newExpiry.getDate() + 7);
  } else if (interval === "MONTH") {
    newExpiry.setMonth(newExpiry.getMonth() + 1);
  } else if (interval === "QUARTER") {
    newExpiry.setMonth(newExpiry.getMonth() + 3);
  } else {
    // Default to YEAR
    newExpiry.setFullYear(newExpiry.getFullYear() + 1);
  }

  return newExpiry;
}

export async function POST(request: NextRequest) {
  const body = await request.json().catch(() => null);
  const parsed = verifySchema.safeParse(body);
  if (!parsed.success) {
    return Response.json({ ok: false, message: "Invalid payment payload." }, { status: 400 });
  }

  const { token, razorpayOrderId, razorpayPaymentId, razorpaySignature, isFree } = parsed.data;

  // 1. Verify renewal token
  const payload = verifyRenewalSessionToken(token);
  if (!payload) {
    return Response.json({
      ok: false,
      message: "Renewal session expired. Please refresh the page and try again.",
    }, { status: 401 });
  }

  const supabase = createAdminClient();

  // 2. Get license and plan details
  const { data: license, error: licenseError } = await supabase
    .from("licenses")
    .select(`
      id,
      status,
      expires_at,
      license_key_hint,
      customer_id,
      plan_id,
      plans (
        id,
        name,
        interval,
        price_in_paise
      ),
      customers (
        company_name,
        contact_person,
        email,
        phone
      )
    `)
    .eq("id", payload.licenseId)
    .single();

  if (licenseError || !license) {
    return Response.json({ ok: false, message: "License record not found." }, { status: 404 });
  }

  const plan = Array.isArray(license.plans) ? license.plans[0] : license.plans;
  const customer = Array.isArray(license.customers) ? license.customers[0] : license.customers;

  if (!plan) {
    return Response.json({ ok: false, message: "Plan details missing." }, { status: 500 });
  }

  // Handle Free Plan renewal without payment gateway
  if (isFree && Number(plan.price_in_paise) === 0) {
    const newExpiry = calculateExtendedExpiry(license.expires_at, plan.interval);
    const { error: updateError } = await supabase
      .from("licenses")
      .update({
        expires_at: newExpiry.toISOString(),
        status: "ACTIVE",
        updated_at: new Date().toISOString(),
      })
      .eq("id", license.id);

    if (updateError) {
      return Response.json({ ok: false, message: updateError.message }, { status: 500 });
    }

    await supabase.from("audit_logs").insert({
      action: "LICENSE_RENEWED_FREE",
      entity_type: "license",
      entity_id: license.id,
      before_data: { expires_at: license.expires_at, status: license.status },
      after_data: { expires_at: newExpiry.toISOString(), status: "ACTIVE" },
    });

    return Response.json({
      ok: true,
      message: "License successfully renewed!",
      licenseKeyHint: license.license_key_hint,
      companyName: customer?.company_name,
      newExpiry: newExpiry.toISOString(),
      planName: plan.name,
    }, { headers: { "Cache-Control": "no-store" } });
  }

  // Verify paid orders
  if (!razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
    return Response.json({ ok: false, message: "Payment details missing." }, { status: 400 });
  }

  // 3. Verify Razorpay signature
  if (!verifyCheckoutSignature(razorpayOrderId, razorpayPaymentId, razorpaySignature)) {
    return Response.json({
      ok: false,
      message: "Payment signature verification failed. Please contact support if money was debited.",
    }, { status: 400 });
  }



  try {
    // 4. Verify payment with Razorpay
    let payment = await getRazorpayPayment(razorpayPaymentId);
    const expectedAmount = Number(plan.price_in_paise);

    if (payment.amount !== expectedAmount) {
      return Response.json({ ok: false, message: "Payment amount does not match plan price." }, { status: 400 });
    }

    if (payment.status === "authorized") {
      try {
        payment = await captureRazorpayPayment(payment.id, expectedAmount);
      } catch {
        payment = await getRazorpayPayment(payment.id);
      }
    }

    if (payment.status !== "captured") {
      return Response.json({
        ok: false,
        message: "Payment is still processing. Please check your bank before trying again.",
      }, { status: 409 });
    }

    // 5. Calculate new expiry preserving remaining days!
    const newExpiry = calculateExtendedExpiry(license.expires_at, plan.interval);

    // 6. Update the EXISTING license in database (NO NEW KEY GENERATED)
    const { error: updateError } = await supabase
      .from("licenses")
      .update({
        expires_at: newExpiry.toISOString(),
        status: "ACTIVE",
        updated_at: new Date().toISOString(),
      })
      .eq("id", license.id);

    if (updateError) {
      console.error("License update error", updateError);
      return Response.json({
        ok: false,
        message: "Payment received, but extending license in database failed. Please contact support with payment ID: " + payment.id,
      }, { status: 500 });
    }

    // 7. Insert audit log
    await supabase.from("audit_logs").insert({
      action: "LICENSE_RENEWED_ONLINE",
      entity_type: "license",
      entity_id: license.id,
      before_data: {
        expires_at: license.expires_at,
        status: license.status,
      },
      after_data: {
        expires_at: newExpiry.toISOString(),
        status: "ACTIVE",
        razorpay_payment_id: payment.id,
        razorpay_order_id: razorpayOrderId,
        amount_in_paise: expectedAmount,
      },
    });

    return Response.json({
      ok: true,
      message: "License successfully renewed!",
      licenseKeyHint: license.license_key_hint,
      companyName: customer?.company_name,
      newExpiry: newExpiry.toISOString(),
      planName: plan.name,
      paymentId: payment.id,
    }, { headers: { "Cache-Control": "no-store" } });
  } catch (error) {
    console.error("Renewal verification failed", error);
    return Response.json({
      ok: false,
      message: error instanceof Error ? error.message : "Payment verification failed. Please contact support.",
    }, { status: 500 });
  }
}
