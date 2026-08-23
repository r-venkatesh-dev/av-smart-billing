import "server-only";

import { createHmac, timingSafeEqual } from "node:crypto";
import { z } from "zod";

const envSchema = z.object({
  RAZORPAY_KEY_ID: z.string().min(4),
  RAZORPAY_KEY_SECRET: z.string().min(8),
  RAZORPAY_WEBHOOK_SECRET: z.string().min(8),
  SUBSCRIPTION_LICENSE_CREATED_BY: z.uuid(),
});

export function getRazorpayEnv() {
  return envSchema.parse({
    RAZORPAY_KEY_ID: process.env.RAZORPAY_KEY_ID,
    RAZORPAY_KEY_SECRET: process.env.RAZORPAY_KEY_SECRET,
    RAZORPAY_WEBHOOK_SECRET: process.env.RAZORPAY_WEBHOOK_SECRET,
    SUBSCRIPTION_LICENSE_CREATED_BY: process.env.SUBSCRIPTION_LICENSE_CREATED_BY,
  });
}

export type RazorpayPayment = {
  id: string;
  order_id: string;
  amount: number;
  currency: string;
  status: "created" | "authorized" | "captured" | "refunded" | "failed";
};

class RazorpayApiError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

async function razorpayRequest<T>(path: string, init?: RequestInit): Promise<T> {
  const env = getRazorpayEnv();
  const response = await fetch(`https://api.razorpay.com/v1${path}`, {
    ...init,
    cache: "no-store",
    headers: {
      Authorization: `Basic ${Buffer.from(`${env.RAZORPAY_KEY_ID}:${env.RAZORPAY_KEY_SECRET}`).toString("base64")}`,
      "Content-Type": "application/json",
      ...init?.headers,
    },
  });
  const payload = await response.json().catch(() => null) as { error?: { description?: string } } | null;
  if (!response.ok) throw new RazorpayApiError(payload?.error?.description ?? "Razorpay request failed.", response.status);
  return payload as T;
}

export function createRazorpayOrder(input: { amount: number; receipt: string; notes: Record<string, string> }) {
  return razorpayRequest<{ id: string; amount: number; currency: string; status: string }>("/orders", {
    method: "POST",
    body: JSON.stringify({ amount: input.amount, currency: "INR", receipt: input.receipt, notes: input.notes }),
  });
}

export function getRazorpayPayment(paymentId: string) {
  return razorpayRequest<RazorpayPayment>(`/payments/${encodeURIComponent(paymentId)}`);
}

export function captureRazorpayPayment(paymentId: string, amount: number) {
  return razorpayRequest<RazorpayPayment>(`/payments/${encodeURIComponent(paymentId)}/capture`, {
    method: "POST",
    body: JSON.stringify({ amount, currency: "INR" }),
  });
}

function signaturesMatch(expected: string, actual: string) {
  if (!/^[a-f0-9]{64}$/i.test(actual)) return false;
  return timingSafeEqual(Buffer.from(expected, "hex"), Buffer.from(actual, "hex"));
}

export function verifyCheckoutSignature(orderId: string, paymentId: string, signature: string) {
  const expected = createHmac("sha256", getRazorpayEnv().RAZORPAY_KEY_SECRET)
    .update(`${orderId}|${paymentId}`)
    .digest("hex");
  return signaturesMatch(expected, signature);
}

export function verifyWebhookSignature(rawBody: string, signature: string) {
  const expected = createHmac("sha256", getRazorpayEnv().RAZORPAY_WEBHOOK_SECRET)
    .update(rawBody)
    .digest("hex");
  return signaturesMatch(expected, signature);
}

