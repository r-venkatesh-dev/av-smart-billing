import { createHash, randomBytes } from "node:crypto";

const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

export function generateLicenseKey(): string {
  const bytes = randomBytes(16);
  const characters = Array.from(bytes, (byte) => ALPHABET[byte % ALPHABET.length]);
  return Array.from({ length: 4 }, (_, index) => characters.slice(index * 4, index * 4 + 4).join("")).join("-");
}

export function hashLicenseKey(key: string): string {
  return createHash("sha256").update(key.replaceAll("-", "").toUpperCase()).digest("hex");
}

export function licenseKeyHint(key: string): string {
  const groups = key.split("-");
  return `${groups[0]}-••••-••••-${groups[3]}`;
}
