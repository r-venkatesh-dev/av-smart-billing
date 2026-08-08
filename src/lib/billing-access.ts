import "server-only";

import { cookies } from "next/headers";
import { getCurrentAdmin, type AdminRole } from "@/lib/auth/authorization";
import { verifyLicenseGrant, type LicenseGrant } from "@/lib/license-signing";
import { createAdminClient } from "@/lib/supabase/admin";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const LICENSE_COOKIE = "avsb_license";

export async function getLicensedSession(): Promise<LicenseGrant | null> {
  const token = (await cookies()).get(LICENSE_COOKIE)?.value;
  if (!token) return null;
  try {
    const grant = await verifyLicenseGrant(token);
    const admin = createAdminClient();
    const [license, device] = await Promise.all([
      admin.from("licenses").select("status, expires_at, customers(status), plans(status)").eq("id", grant.licenseId).maybeSingle(),
      admin.from("devices").select("status, license_id").eq("id", grant.deviceId).maybeSingle(),
    ]);
    const customer = Array.isArray(license.data?.customers) ? license.data.customers[0] : license.data?.customers;
    const plan = Array.isArray(license.data?.plans) ? license.data.plans[0] : license.data?.plans;
    if (!license.data || license.data.status !== "ACTIVE" || new Date(license.data.expires_at) <= new Date() || customer?.status !== "ACTIVE" || plan?.status !== "ACTIVE" || !device.data || device.data.status !== "ACTIVE" || device.data.license_id !== grant.licenseId) return null;
    return grant;
  } catch {
    return null;
  }
}

export async function getBillingAccess() {
  const admin = await getCurrentAdmin();
  if (admin) return { kind: "admin" as const, actorId: admin.id, displayName: admin.fullName, role: admin.role, licenseId: null };
  const license = await getLicensedSession();
  if (!license) return null;
  const privileged = createAdminClient();
  const row = await privileged.from("licenses").select("created_by").eq("id", license.licenseId).single();
  if (row.error) return null;
  return { kind: "license" as const, actorId: row.data.created_by, displayName: license.customerName, role: "LICENSED" as const, licenseId: license.licenseId };
}

export async function requireBillingAccess(allowedAdminRoles?: readonly AdminRole[]) {
  const access = await getBillingAccess();
  if (!access) throw new Error("Billing authorization required");
  if (access.kind === "admin" && allowedAdminRoles && !allowedAdminRoles.includes(access.role)) throw new Error("Insufficient permissions");
  return access;
}

export async function createBillingDataClient() {
  const access = await requireBillingAccess();
  return access.kind === "license" ? createAdminClient() : createSupabaseServerClient();
}
