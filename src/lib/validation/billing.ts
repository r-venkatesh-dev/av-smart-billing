import { z } from "zod";
import { optionalMobileNumber, requiredMobileNumber } from "@/lib/validation/common";

const optionalEmail = z.string().trim().refine((value) => !value || z.email().safeParse(value).success, "Enter a valid email or leave it blank.");
const optionalGstin = z.string().trim().toUpperCase().refine((value) => !value || /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/.test(value), "Enter a valid GSTIN or leave it blank.");

export const billingBusinessSchema = z.object({
  companyName: z.string().trim().min(2).max(180), contactPerson: z.string().trim().max(120), email: optionalEmail,
  phone: optionalMobileNumber, address: z.string().trim().max(500), gstin: optionalGstin,
  currencyCode: z.string().trim().toUpperCase().regex(/^[A-Z]{3}$/), invoicePrefix: z.string().trim().toUpperCase().regex(/^[A-Z0-9-]{1,12}$/),
  lowStockThreshold: z.coerce.number().min(0).max(100000000),
  stateCode: z.string().trim().refine((value) => !value || /^[0-9]{2}$/.test(value), "Enter a two-digit GST state code."),
  invoiceTerms: z.string().trim().max(1500), invoiceFooter: z.string().trim().max(500), thermalPaperWidth: z.coerce.number().refine((value) => value === 58 || value === 80, "Choose 58mm or 80mm."),
});

export const billingCustomerSchema = z.object({
  name: z.string().trim().min(2).max(180), email: optionalEmail, phone: optionalMobileNumber, address: z.string().trim().max(500), gstin: optionalGstin,
});

export const billingProductSchema = z.object({
  name: z.string().trim().min(2).max(180), sku: z.string().trim().min(1).max(80).toUpperCase(),
  barcode: z.string().trim().max(80).refine((value) => !value || /^[A-Za-z0-9._/-]{4,80}$/.test(value), "Use 4–80 barcode characters: letters, numbers, dot, slash, underscore or hyphen."),
  category: z.string().trim().max(120), hsnSac: z.string().trim().toUpperCase().max(20), description: z.string().trim().max(500), unit: z.string().trim().min(1).max(24),
  purchasePriceInRupees: z.string().trim().regex(/^\d+(?:\.\d{1,2})?$/, "Enter a valid purchase price."),
  priceInRupees: z.string().trim().regex(/^\d+(?:\.\d{1,2})?$/, "Enter a valid selling price."), taxRatePercent: z.string().trim().regex(/^\d+(?:\.\d{1,2})?$/, "Enter a valid percentage.").refine((value) => Number(value) <= 100, "Tax cannot exceed 100%."), stockQuantity: z.coerce.number().min(0).max(100000000),
  lowStockThreshold: z.preprocess((value) => value === "" ? null : value, z.coerce.number().min(0).max(100000000).nullable()),
  status: z.enum(["ACTIVE", "INACTIVE"]),
});

export const billingInvoiceSchema = z.object({
  customerId: z.string().uuid().or(z.literal("WALK_IN")), walkInName: z.string().trim().max(180), walkInPhone: z.string().trim().max(10),
  productId: z.string().uuid(), quantity: z.coerce.number().positive().max(1000000), dueAt: z.string().trim().refine((value) => !value || (/^\d{4}-\d{2}-\d{2}$/.test(value) && new Date(`${value}T23:59:59.999Z`).getTime() > Date.now()), "Due date cannot be in the past."), notes: z.string().trim().max(1000),
}).superRefine((value, context) => {
  if (value.customerId !== "WALK_IN") return;
  if (value.walkInName.length < 2) context.addIssue({ code: "custom", path: ["walkInName"], message: "Enter the walk-in customer's name." });
  if (!requiredMobileNumber.safeParse(value.walkInPhone).success) context.addIssue({ code: "custom", path: ["walkInPhone"], message: "Enter a valid 10-digit mobile number." });
});

export const billingPaymentSchema = z.object({
  invoiceId: z.string().uuid(), amountInRupees: z.string().trim().regex(/^\d+(?:\.\d{1,2})?$/, "Enter a valid payment amount.").refine((value) => Number(value) > 0, "Payment must be positive."), method: z.enum(["CASH", "CARD", "UPI", "BANK_TRANSFER", "OTHER"]), reference: z.string().trim().max(120), notes: z.string().trim().max(1000),
});

export const billingPosSchema = z.object({
  customerId: z.string().uuid().nullable(),
  walkInName: z.string().trim().max(180),
  walkInPhone: z.string().trim().max(10),
  items: z.array(z.object({
    productId: z.string().uuid(),
    quantity: z.coerce.number().positive().max(1000000),
    discountPercent: z.coerce.number().min(0).max(100),
  })).min(1).max(200),
  paymentMethod: z.enum(["CASH", "CARD", "UPI", "BANK_TRANSFER", "OTHER", "CREDIT"]),
  amountReceivedInRupees: z.string().trim().regex(/^\d+(?:\.\d{1,2})?$/, "Enter a valid amount received."),
  reference: z.string().trim().max(120),
  taxType: z.enum(["INTRA_STATE", "INTER_STATE"]),
}).superRefine((value, context) => {
  if (value.customerId) return;
  if (value.walkInName.length < 2) context.addIssue({ code: "custom", path: ["walkInName"], message: "Enter the walk-in customer's name." });
  if (!requiredMobileNumber.safeParse(value.walkInPhone).success) context.addIssue({ code: "custom", path: ["walkInPhone"], message: "Enter a valid 10-digit mobile number." });
});

export const billingStockAdjustmentSchema = z.object({
  productId: z.string().uuid(),
  movementType: z.enum(["PURCHASE", "RETURN", "ADJUSTMENT"]),
  quantity: z.coerce.number().min(0).max(100000000),
  reference: z.string().trim().max(120),
  notes: z.string().trim().max(500),
});
