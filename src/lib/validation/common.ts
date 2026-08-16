import { z } from "zod";

const mobileNumberMessage = "Enter a valid 10-digit mobile number.";

export const requiredMobileNumber = z
  .string()
  .trim()
  .regex(/^\d{10}$/, mobileNumberMessage);

export const optionalMobileNumber = z
  .string()
  .trim()
  .refine((value) => !value || /^\d{10}$/.test(value), mobileNumberMessage);
