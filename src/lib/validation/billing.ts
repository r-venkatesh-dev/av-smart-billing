import { z } from "zod";

const optionalEmail = z.string().trim().refine((value) => !value || z.email().safeParse(value).success, "Enter a valid email or leave it blank.");
const optionalGstin = z.string().trim().toUpperCase().refine((value) => !value || /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/.test(value), "Enter a valid GSTIN or leave it blank.");

export const billingBusinessSchema = z.object({
  companyName: z.string().trim().min(2).max(180), contactPerson: z.string().trim().max(120), email: optionalEmail,
  phone: z.string().trim().max(40), address: z.string().trim().max(500), gstin: optionalGstin,
  currencyCode: z.string().trim().toUpperCase().regex(/^[A-Z]{3}$/), invoicePrefix: z.string().trim().toUpperCase().regex(/^[A-Z0-9-]{1,12}$/),
  lowStockThreshold: z.coerce.number().min(0).max(100000000),
});

export const billingCustomerSchema = z.object({
  name: z.string().trim().min(2).max(180), email: optionalEmail, phone: z.string().trim().max(40), address: z.string().trim().max(500), gstin: optionalGstin,
});

export const billingProductSchema = z.object({
  name: z.string().trim().min(2).max(180), sku: z.string().trim().min(1).max(80).toUpperCase(), description: z.string().trim().max(500), unit: z.string().trim().min(1).max(24),
  priceInRupees: z.string().trim().regex(/^\d+(?:\.\d{1,2})?$/, "Enter a valid rupee amount."), taxRatePercent: z.string().trim().regex(/^\d+(?:\.\d{1,2})?$/, "Enter a valid percentage.").refine((value) => Number(value) <= 100, "Tax cannot exceed 100%."), stockQuantity: z.coerce.number().min(0).max(100000000),
  status: z.enum(["ACTIVE", "INACTIVE"]),
});

export const billingInvoiceSchema = z.object({
  customerId: z.string().uuid().or(z.literal("WALK_IN")), walkInName: z.string().trim().max(180), walkInPhone: z.string().trim().max(40),
  productId: z.string().uuid(), quantity: z.coerce.number().positive().max(1000000), dueAt: z.string().trim(), notes: z.string().trim().max(1000),
}).superRefine((value, context) => {
  if (value.customerId !== "WALK_IN") return;
  if (value.walkInName.length < 2) context.addIssue({ code: "custom", path: ["walkInName"], message: "Enter the walk-in customer's name." });
  if (value.walkInPhone.length < 5) context.addIssue({ code: "custom", path: ["walkInPhone"], message: "Enter the walk-in customer's mobile number." });
});

export const billingPaymentSchema = z.object({
  invoiceId: z.string().uuid(), amountInRupees: z.string().trim().regex(/^\d+(?:\.\d{1,2})?$/, "Enter a valid payment amount.").refine((value) => Number(value) > 0, "Payment must be positive."), method: z.enum(["CASH", "CARD", "UPI", "BANK_TRANSFER", "OTHER"]), reference: z.string().trim().max(120), notes: z.string().trim().max(1000),
});
