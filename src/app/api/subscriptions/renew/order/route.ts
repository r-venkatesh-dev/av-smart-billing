import type { NextRequest } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { verifyRenewalSessionToken } from "@/lib/renewal-token";
import { createRazorpayOrder, getRazorpayEnv } from "@/lib/razorpay";
import { z } from "zod";

export const runtime = "nodejs";

const schema = z.object({
  token: z.string(),
});

export async function POST(request: NextRequest) {
  const body = await request.json().catch(() => null);
  const parsed = schema.safeParse(body);
  if (!parsed.success) {
    return Response.json({ ok: false, message: "Invalid renewal session." }, { status: 400 });
  }

  const payload = verifyRenewalSessionToken(parsed.data.token);
  if (!payload) {
    return Response.json({ ok: false, message: "Renewal session expired. Please refresh the page." }, { status: 401 });
  }

  const supabase = createAdminClient();
  const { data: license, error } = await supabase
    .from("licenses")
    .select(`
      id,
      status,
      expires_at,
      license_key_hint,
      plans (
        id,
        name,
        price_in_paise,
        interval
      ),
      customers (
        company_name,
        contact_person,
        phone,
        email
      )
    `)
    .eq("id", payload.licenseId)
    .single();

  if (error || !license) {
    return Response.json({ ok: false, message: "License record not found." }, { status: 404 });
  }

  const plan = Array.isArray(license.plans) ? license.plans[0] : license.plans;
  const customer = Array.isArray(license.customers) ? license.customers[0] : license.customers;

  if (!plan || !customer) {
    return Response.json({ ok: false, message: "Plan details missing." }, { status: 500 });
  }

  const amountInPaise = Number(plan.price_in_paise);
  if (amountInPaise <= 0) {
    return Response.json({ ok: false, message: "This plan does not require online payment." }, { status: 400 });
  }

  try {
    const razorpayEnv = getRazorpayEnv();
    const shortId = license.id.replace(/-/g, "").slice(0, 8);
    const receipt = `rnw_${shortId}_${Date.now()}`.slice(0, 40);

    const razorpayOrder = await createRazorpayOrder({
      amount: amountInPaise,
      receipt,
      notes: {
        renewal_license_id: license.id,
        plan_id: plan.id,
        customer_email: customer.email,
        company_name: customer.company_name,
      },
    });

    return Response.json({
      ok: true,
      keyId: razorpayEnv.RAZORPAY_KEY_ID,
      razorpayOrderId: razorpayOrder.id,
      amount: razorpayOrder.amount,
      currency: razorpayOrder.currency,
      planName: plan.name,
      prefill: {
        name: customer.contact_person,
        email: customer.email,
        contact: customer.phone,
      },
    }, { headers: { "Cache-Control": "no-store" } });
  } catch (error) {
    console.error("Renewal Razorpay order creation failed", error);
    return Response.json({
      ok: false,
      message: "Unable to connect to payment gateway. Please try again or contact support.",
    }, { status: 500 });
  }
}
