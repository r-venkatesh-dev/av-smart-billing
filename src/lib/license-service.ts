import "server-only";

import { createHash } from "node:crypto";
import { createAdminClient } from "@/lib/supabase/admin";
import { hashLicenseKey } from "@/lib/license-key";
import { signLicenseGrant, type LicenseClient, type LicenseGrant } from "@/lib/license-signing";

export class LicenseLifecycleError extends Error {
  constructor(message: string, public readonly status = 400) {
    super(message);
    this.name = "LicenseLifecycleError";
  }
}

function fingerprintHash(value: string) {
  return createHash("sha256").update(value).digest("hex");
}

function fingerprintHint(value: string) {
  return `••••${fingerprintHash(value).slice(-12)}`;
}

function grant(row: Record<string, unknown>): LicenseGrant {
  return {
    licenseId: String(row.license_id),
    deviceId: String(row.device_id),
    customerName: String(row.customer_name),
    planName: String(row.plan_name),
    expiresAt: String(row.expires_at),
    validationWindowDays: Number(row.validation_window_days),
    maxDevices: Number(row.max_devices),
    allowOnlineBilling: row.allow_online_billing !== false,
    allowCloudBackup: row.allow_cloud_backup !== false,
    allowReportsExports: row.allow_reports_exports !== false,
  };
}

async function addEntitlements(supabase: ReturnType<typeof createAdminClient>, row: Record<string, unknown>) {
  const license = await supabase.from("licenses").select("allow_online_billing, allow_cloud_backup, allow_reports_exports, plans(allow_online_billing, allow_cloud_backup, allow_reports_exports)").eq("id", String(row.license_id)).single();
  if (license.error) throw new LicenseLifecycleError("Unable to read the license capabilities.", 500);
  const plan = Array.isArray(license.data.plans) ? license.data.plans[0] : license.data.plans;
  return {
    ...row,
    allow_online_billing: license.data.allow_online_billing && plan?.allow_online_billing === true,
    allow_cloud_backup: license.data.allow_cloud_backup && plan?.allow_cloud_backup === true,
    allow_reports_exports: license.data.allow_reports_exports && plan?.allow_reports_exports === true,
  };
}

async function ensureLicensedBillingWorkspace(supabase: ReturnType<typeof createAdminClient>, licenseGrant: LicenseGrant) {
  const existingBusiness = await supabase.from("billing_businesses").select("id").eq("license_id", licenseGrant.licenseId).maybeSingle();
  if (existingBusiness.data) return;
  const source = await supabase.from("licenses").select("created_by, customers(company_name, contact_person, email, phone, address, gstin)").eq("id", licenseGrant.licenseId).single();
  const customer = Array.isArray(source.data?.customers) ? source.data.customers[0] : source.data?.customers;
  if (source.error || !customer) throw new LicenseLifecycleError("Unable to provision the licensed billing workspace.", 500);
  const provisioned = await supabase.from("billing_businesses").insert({ license_id: licenseGrant.licenseId, created_by: source.data.created_by, company_name: customer.company_name, contact_person: customer.contact_person, email: customer.email, phone: customer.phone, address: customer.address, gstin: customer.gstin }).select("id").single();
  if (provisioned.error && provisioned.error.code !== "23505") throw new LicenseLifecycleError("Unable to provision the licensed billing workspace.", 500);
}

async function recordRejectedActivation(keyHash: string, message: string, ipAddress: string | null, userAgent: string | null) {
  const supabase = createAdminClient();
  const license = await supabase.from("licenses").select("id").eq("license_key_hash", keyHash).maybeSingle();
  if (!license.data) return;
  await supabase.from("license_activations").insert({ license_id: license.data.id, event: "REJECTED", success: false, failure_code: message.slice(0, 120).toUpperCase().replaceAll(/[^A-Z0-9]+/g, "_"), ip_address: ipAddress, user_agent: userAgent });
}

export async function activateLicense(input: { licenseKey: string; deviceFingerprint: string; deviceName: string; client: LicenseClient; ipAddress: string | null; userAgent: string | null }) {
  const supabase = createAdminClient();
  const keyHash = hashLicenseKey(input.licenseKey);
  await supabase.from("licenses").update({ status: "EXPIRED" }).eq("license_key_hash", keyHash).eq("status", "ACTIVE").lte("expires_at", new Date().toISOString());
  const { data, error } = await supabase.rpc("activate_license", {
    p_license_key_hash: keyHash,
    p_fingerprint_hash: fingerprintHash(input.deviceFingerprint),
    p_fingerprint_hint: fingerprintHint(input.deviceFingerprint),
    p_device_name: input.deviceName,
    p_ip_address: input.ipAddress,
    p_user_agent: input.userAgent,
  });
  if (error || !data?.[0]) {
    const message = error?.message ?? "Activation failed";
    await recordRejectedActivation(keyHash, message, input.ipAddress, input.userAgent);
    throw new LicenseLifecycleError(message === "Invalid license key" ? message : message.replace(/^.*?: /, ""), message === "Invalid license key" ? 404 : 409);
  }
  const licenseGrant = grant(await addEntitlements(supabase, data[0] as Record<string, unknown>));
  await ensureLicensedBillingWorkspace(supabase, licenseGrant);
  return { grant: licenseGrant, signed: await signLicenseGrant(licenseGrant, input.client) };
}

export async function validateActivatedLicense(input: { deviceId: string; deviceFingerprint: string; client: LicenseClient; ipAddress: string | null; userAgent: string | null }) {
  const supabase = createAdminClient();
  const device = await supabase.from("devices").select("license_id").eq("id", input.deviceId).maybeSingle();
  if (device.data) await supabase.from("licenses").update({ status: "EXPIRED" }).eq("id", device.data.license_id).eq("status", "ACTIVE").lte("expires_at", new Date().toISOString());
  const { data, error } = await supabase.rpc("validate_license", {
    p_device_id: input.deviceId,
    p_fingerprint_hash: fingerprintHash(input.deviceFingerprint),
    p_ip_address: input.ipAddress,
    p_user_agent: input.userAgent,
  });
  if (error || !data?.[0]) throw new LicenseLifecycleError(error?.message ?? "License validation failed", 409);
  const licenseGrant = grant(await addEntitlements(supabase, data[0] as Record<string, unknown>));
  await ensureLicensedBillingWorkspace(supabase, licenseGrant);
  return { grant: licenseGrant, signed: await signLicenseGrant(licenseGrant, input.client) };
}
