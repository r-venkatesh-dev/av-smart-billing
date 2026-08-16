import "server-only";

import { createPrivateKey, createPublicKey } from "node:crypto";
import { jwtVerify, SignJWT } from "jose";
import { getServerEnv } from "@/lib/env";

export interface LicenseGrant {
  licenseId: string;
  deviceId: string;
  customerName: string;
  planName: string;
  expiresAt: string;
  validationWindowDays: number;
  maxDevices: number;
}

export type LicenseClient = "DESKTOP" | "MOBILE";

function audienceFor(client: LicenseClient) {
  return client === "MOBILE" ? "av-smartbilling-mobile" : "av-smartbilling-desktop";
}

function privateKey() {
  const der = Buffer.from(getServerEnv().LICENSE_SIGNING_PRIVATE_KEY, "base64url");
  return createPrivateKey({ key: der, type: "pkcs8", format: "der" });
}

export async function signLicenseGrant(grant: LicenseGrant, client: LicenseClient = "DESKTOP") {
  const env = getServerEnv();
  const key = privateKey();
  const now = Date.now();
  const licenseExpiry = new Date(grant.expiresAt).getTime();
  const offlineExpiry = now + grant.validationWindowDays * 86_400_000;
  const validUntil = new Date(Math.min(licenseExpiry, offlineExpiry));
  const token = await new SignJWT({
    type: "av-smartbilling-license",
    licenseId: grant.licenseId,
    deviceId: grant.deviceId,
    customerName: grant.customerName,
    planName: grant.planName,
    maxDevices: grant.maxDevices,
    licenseExpiresAt: grant.expiresAt,
  })
    .setProtectedHeader({ alg: "EdDSA", kid: env.LICENSE_SIGNING_KEY_ID, typ: "JWT" })
    .setIssuer(env.LICENSE_ISSUER)
    .setAudience(audienceFor(client))
    .setSubject(grant.licenseId)
    .setJti(crypto.randomUUID())
    .setIssuedAt()
    .setExpirationTime(Math.floor(validUntil.getTime() / 1000))
    .sign(key);
  const publicDer = createPublicKey(key).export({ type: "spki", format: "der" });
  return { token, validUntil: validUntil.toISOString(), publicKey: Buffer.from(publicDer).toString("base64url"), keyId: env.LICENSE_SIGNING_KEY_ID, issuer: env.LICENSE_ISSUER };
}

export async function verifyLicenseGrant(token: string, client: LicenseClient = "DESKTOP"): Promise<LicenseGrant> {
  const env = getServerEnv();
  const { payload } = await jwtVerify(token, createPublicKey(privateKey()), { issuer: env.LICENSE_ISSUER, audience: audienceFor(client), algorithms: ["EdDSA"] });
  if (payload.type !== "av-smartbilling-license" || !payload.licenseId || !payload.deviceId || !payload.customerName || !payload.planName || !payload.licenseExpiresAt) throw new Error("Invalid license grant");
  return { licenseId: String(payload.licenseId), deviceId: String(payload.deviceId), customerName: String(payload.customerName), planName: String(payload.planName), expiresAt: String(payload.licenseExpiresAt), validationWindowDays: 0, maxDevices: Number(payload.maxDevices) };
}
