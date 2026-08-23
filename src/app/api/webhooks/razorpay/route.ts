import { createHash } from "node:crypto";
import { verifyWebhookSignature } from "@/lib/razorpay";
import { createAdminClient } from "@/lib/supabase/admin";

export const runtime = "nodejs";

type PaymentEntity = {
  id?: string;
  order_id?: string;
  amount?: number;
  currency?: string;
  status?: string;
  error_code?: string;
  error_description?: string;
  error_source?: string;
  error_step?: string;
  error_reason?: string;
};

export async function POST(request: Request) {
  const rawBody = await request.text();
  const signature = request.headers.get("x-razorpay-signature") ?? "";
  if (!verifyWebhookSignature(rawBody, signature)) return new Response("Invalid signature", { status: 400 });

  const payload = JSON.parse(rawBody) as {
    event?: string;
    payload?: { payment?: { entity?: PaymentEntity }; order?: { entity?: { id?: string; status?: string } } };
  };
  const eventType = payload.event ?? "unknown";
  const eventId = request.headers.get("x-razorpay-event-id") ?? createHash("sha256").update(rawBody).digest("hex");
  const supabase = createAdminClient();
  const { error: eventError } = await supabase.from("subscription_webhook_events").insert({ razorpay_event_id: eventId, event_type: eventType });
  if (eventError?.code === "23505") return new Response("Already processed", { status: 200 });
  if (eventError) {
    console.error("Razorpay webhook event insert failed", eventError);
    return new Response("Webhook storage failed", { status: 500 });
  }

  try {
    const payment = payload.payload?.payment?.entity;
    const razorpayOrderId = payment?.order_id ?? payload.payload?.order?.entity?.id;
    if (razorpayOrderId && (eventType === "payment.captured" || eventType === "order.paid" || eventType === "payment.failed")) {
      const { data: purchase } = await supabase
        .from("subscription_orders")
        .select("id, amount_in_paise, currency, status")
        .eq("razorpay_order_id", razorpayOrderId)
        .maybeSingle();
      if (purchase) {
        const captured = eventType === "payment.captured" || eventType === "order.paid";
        if (purchase.status !== "PAID") {
          await supabase.from("subscription_orders").update(captured ? {
            status: "PAYMENT_CAPTURED",
            latest_razorpay_payment_id: payment?.id ?? null,
            failure_code: null,
            failure_description: null,
          } : {
            status: "FAILED",
            latest_razorpay_payment_id: payment?.id ?? null,
            failure_code: payment?.error_code ?? "PAYMENT_FAILED",
            failure_description: payment?.error_description ?? "Payment failed.",
          }).eq("id", purchase.id).neq("status", "PAID");
        }
        if (payment?.id) {
          await supabase.from("subscription_payment_attempts").upsert({
            subscription_order_id: purchase.id,
            razorpay_order_id: razorpayOrderId,
            razorpay_payment_id: payment.id,
            status: captured ? "CAPTURED" : "FAILED",
            amount_in_paise: payment.amount ?? Number(purchase.amount_in_paise),
            currency: payment.currency ?? purchase.currency,
            error_code: payment.error_code,
            error_description: payment.error_description,
            error_source: payment.error_source,
            error_step: payment.error_step,
            error_reason: payment.error_reason,
          }, { onConflict: "razorpay_payment_id" });
        }
      }
    }
    await supabase.from("subscription_webhook_events").update({ processed: true, processed_at: new Date().toISOString() }).eq("razorpay_event_id", eventId);
    return new Response("OK", { status: 200 });
  } catch (error) {
    console.error("Razorpay webhook processing failed", error);
    await supabase.from("subscription_webhook_events").update({ processing_error: "Processing failed", processed_at: new Date().toISOString() }).eq("razorpay_event_id", eventId);
    return new Response("Processing failed", { status: 500 });
  }
}

