import { z } from "zod";
import { requiredMobileNumber } from "@/lib/validation/common";

const optionalGstin = z.string().trim().toUpperCase().refine(
  (value) => !value || /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/.test(value),
  "Enter a valid GSTIN or leave it blank.",
);

export const customerSchema = z.object({
  companyName: z.string().trim().min(2).max(180),
  contactPerson: z.string().trim().min(2).max(120),
  email: z.email().trim().toLowerCase(),
  phone: requiredMobileNumber,
  address: z.string().trim().min(3).max(500),
  gstin: optionalGstin,
  status: z.enum(["ACTIVE", "INACTIVE"]),
});

export const planSchema = z.object({
  name: z.string().trim().min(2).max(80),
  description: z.string().trim().max(500),
  maxDevices: z.coerce.number().int().min(1).max(100),
  validationWindowDays: z.coerce.number().int().min(1).max(365),
  priceInRupees: z.string().trim().regex(/^\d+(?:\.\d{1,2})?$/, "Enter a valid rupee amount with up to two decimals."),
  interval: z.enum(["MONTH", "YEAR"]),
  status: z.enum(["ACTIVE", "INACTIVE"]),
});

export const platformSettingsSchema = z.object({
  defaultValidationWindowDays: z.coerce.number().int().min(1).max(365),
  expiryWarningDays: z.coerce.number().int().min(1).max(365),
  licenseIssuer: z.url().refine((value) => value.startsWith("https://"), "Use an HTTPS issuer URL."),
});
