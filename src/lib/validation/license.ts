import { z } from "zod";

const deviceFingerprint = z.string().trim().min(32).max(512);
const licenseClient = z.enum(["DESKTOP", "MOBILE"]).default("DESKTOP");

export const generateLicenseSchema = z.object({
  customerId: z.uuid(),
  planId: z.uuid(),
  expiresAt: z.iso.datetime().refine((value) => new Date(value).getTime() > Date.now(), "Expiry must be in the future."),
  maxDevices: z.number().int().min(1).max(100).optional(),
});

export const activateLicenseSchema = z.object({
  licenseKey: z.string().trim().regex(/^[A-Z0-9]{4}(?:-[A-Z0-9]{4}){3}$/),
  deviceFingerprint,
  deviceName: z.string().trim().min(1).max(120),
  client: licenseClient,
});

export const validateLicenseSchema = z.object({
  deviceId: z.uuid(),
  deviceFingerprint,
  client: licenseClient,
});

export const licenseActionSchema = z.object({ licenseId: z.uuid() });
export const deviceActionSchema = z.object({ deviceId: z.uuid() });
