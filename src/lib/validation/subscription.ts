import { z } from "zod";

const gstin = z.string().trim().toUpperCase().max(15).refine(
  (value) => value === "" || /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/.test(value),
  "Enter a valid GSTIN.",
);

export const subscriptionOrderSchema = z.object({
  planId: z.uuid(),
  companyName: z.string().trim().min(2).max(180),
  contactPerson: z.string().trim().min(2).max(120),
  email: z.email().trim().toLowerCase().max(254),
  phone: z.string().trim().regex(/^[6-9][0-9]{9}$/, "Enter a valid 10-digit mobile number."),
  address: z.string().trim().min(5).max(500),
  gstin,
});

export const subscriptionVerificationSchema = z.object({
  subscriptionOrderId: z.uuid(),
  razorpayOrderId: z.string().min(5).max(100),
  razorpayPaymentId: z.string().min(5).max(100),
  razorpaySignature: z.string().regex(/^[a-f0-9]{64}$/i),
});

export const subscriptionFailureSchema = z.object({
  subscriptionOrderId: z.uuid(),
  razorpayOrderId: z.string().max(100).optional(),
  razorpayPaymentId: z.string().max(100).optional(),
  cancelled: z.boolean().default(false),
  error: z.object({
    code: z.string().max(100).optional(),
    description: z.string().max(500).optional(),
    source: z.string().max(100).optional(),
    step: z.string().max(100).optional(),
    reason: z.string().max(100).optional(),
  }).optional(),
});

