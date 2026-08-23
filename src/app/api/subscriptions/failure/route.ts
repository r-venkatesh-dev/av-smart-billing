import { createAdminClient } from "@/lib/supabase/admin";
import { subscriptionFailureSchema } from "@/lib/validation/subscription";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const parsed = subscriptionFailureSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return Response.json({ ok: false }, { status: 400 });
  const input = parsed.data;
  const supabase = createAdminClient();
  const { data: purchase } = await supabase.from("subscription_orders").select("id, amount_in_paise, currency, status, razorpay_order_id").eq("id", input.subscriptionOrderId).maybeSingle();
  if (!purchase || purchase.status === "PAID") return Response.json({ ok: true });

  const status = input.cancelled ? "CANCELLED" : "FAILED";
  await supabase.from("subscription_orders").update({
    status,
    latest_razorpay_payment_id: input.razorpayPaymentId || null,
    failure_code: input.error?.code ?? (input.cancelled ? "CHECKOUT_CLOSED" : "PAYMENT_FAILED"),
    failure_description: input.error?.description ?? (input.cancelled ? "Customer closed checkout." : "Payment failed."),
  }).eq("id", purchase.id).neq("status", "PAID");
  await supabase.from("subscription_payment_attempts").insert({
    subscription_order_id: purchase.id,
    razorpay_order_id: input.razorpayOrderId ?? purchase.razorpay_order_id,
    razorpay_payment_id: input.razorpayPaymentId || null,
    status: input.cancelled ? "CANCELLED" : "FAILED",
    amount_in_paise: Number(purchase.amount_in_paise),
    currency: purchase.currency,
    error_code: input.error?.code,
    error_description: input.error?.description,
    error_source: input.error?.source,
    error_step: input.error?.step,
    error_reason: input.error?.reason,
  });
  return Response.json({ ok: true }, { headers: { "Cache-Control": "no-store" } });
}

