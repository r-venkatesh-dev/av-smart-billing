import "server-only";

import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";
import { getServerEnv } from "@/lib/env";

function encryptionKey() {
  return Buffer.from(getServerEnv().LICENSE_KEY_ENCRYPTION_KEY, "hex");
}

export interface RenewalPayload {
  licenseId: string;
  expiresAtMs: number;
}

/**
 * Creates an opaque, encrypted, tamper-proof session token for renewal.
 * Uses AES-256-GCM. Does NOT expose license keys, customer names, or phone numbers.
 */
export function createRenewalSessionToken(licenseId: string, ttlSeconds = 3600): string {
  const payload: RenewalPayload = {
    licenseId,
    expiresAtMs: Date.now() + ttlSeconds * 1000,
  };
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", encryptionKey(), iv);
  const serialized = JSON.stringify(payload);
  const encrypted = Buffer.concat([cipher.update(serialized, "utf8"), cipher.final()]);
  return [iv, cipher.getAuthTag(), encrypted].map((part) => part.toString("base64url")).join(".");
}

/**
 * Verifies and decrypts a renewal session token.
 * Returns null if token is invalid, tampered with, or expired.
 */
export function verifyRenewalSessionToken(token: string): RenewalPayload | null {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const [iv, tag, encrypted] = parts.map((part) => Buffer.from(part, "base64url"));
    const decipher = createDecipheriv("aes-256-gcm", encryptionKey(), iv);
    decipher.setAuthTag(tag);
    const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]).toString("utf8");
    const payload = JSON.parse(decrypted) as RenewalPayload;
    if (Date.now() > payload.expiresAtMs) return null;
    return payload;
  } catch {
    return null;
  }
}
