"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireAdminRole, ADMIN_WRITE_ROLES } from "@/lib/auth/authorization";
import { createAdminClient } from "@/lib/supabase/admin";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { customerSchema, planSchema, platformSettingsSchema } from "@/lib/validation/admin";
import { generateLicenseSchema } from "@/lib/validation/license";
import { generateLicenseKey, hashLicenseKey, licenseKeyHint } from "@/lib/license-key";
import { encryptLicenseKey } from "@/lib/license-key-vault";
import { rupeesToPaise } from "@/lib/money";

export interface EntityFormState {
  message?: string;
  errors?: Record<string, string[]>;
  licenseKey?: string;
  licenseId?: string;
}

async function recordAudit(action: string, entityType: string, entityId: string, beforeData: unknown, afterData: unknown) {
  const actor = await requireAdminRole(ADMIN_WRITE_ROLES.customers);
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.from("audit_logs").insert({ actor_id: actor.id, action, entity_type: entityType, entity_id: entityId, before_data: beforeData, after_data: afterData });
  if (error) throw new Error(`Audit write failed: ${error.message}`);
}

function customerInput(formData: FormData) {
  return customerSchema.safeParse({ companyName: formData.get("companyName"), contactPerson: formData.get("contactPerson"), email: formData.get("email"), phone: formData.get("phone"), address: formData.get("address"), gstin: formData.get("gstin"), status: formData.get("status") });
}

export async function createCustomer(_state: EntityFormState, formData: FormData): Promise<EntityFormState> {
  await requireAdminRole(ADMIN_WRITE_ROLES.customers);
  const parsed = customerInput(formData);
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.from("customers").insert({ company_name: parsed.data.companyName, contact_person: parsed.data.contactPerson, email: parsed.data.email, phone: parsed.data.phone, address: parsed.data.address, gstin: parsed.data.gstin || null, status: parsed.data.status }).select().single();
  if (error) return { message: error.message };
  await recordAudit("CUSTOMER_CREATED", "customer", data.id, null, data);
  redirect(`/admin/customers/${data.id}`);
}

export async function updateCustomer(id: string, _state: EntityFormState, formData: FormData): Promise<EntityFormState> {
  await requireAdminRole(ADMIN_WRITE_ROLES.customers);
  const parsed = customerInput(formData);
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  const supabase = await createSupabaseServerClient();
  const before = await supabase.from("customers").select().eq("id", id).single();
  if (before.error) return { message: before.error.message };
  const { data, error } = await supabase.from("customers").update({ company_name: parsed.data.companyName, contact_person: parsed.data.contactPerson, email: parsed.data.email, phone: parsed.data.phone, address: parsed.data.address, gstin: parsed.data.gstin || null, status: parsed.data.status }).eq("id", id).select().single();
  if (error) return { message: error.message };
  await recordAudit("CUSTOMER_UPDATED", "customer", id, before.data, data);
  redirect(`/admin/customers/${id}`);
}

export interface DeleteCustomerResult { ok: boolean; mode?: "deleted" | "deactivated"; message: string }

export async function deleteCustomer(id: string): Promise<DeleteCustomerResult> {
  const actor = await requireAdminRole(["OWNER", "ADMIN"]);
  const supabase = await createSupabaseServerClient();
  const customer = await supabase.from("customers").select("id, company_name, status").eq("id", id).maybeSingle();
  if (customer.error) return { ok: false, message: customer.error.message };
  if (!customer.data) return { ok: false, message: "Customer not found." };
  const licenses = await supabase.from("licenses").select("id", { count: "exact", head: true }).eq("customer_id", id);
  if (licenses.error) return { ok: false, message: licenses.error.message };
  let mode: "deleted" | "deactivated";
  if ((licenses.count ?? 0) > 0) {
    const archived = await supabase.from("customers").update({ status: "INACTIVE" }).eq("id", id);
    if (archived.error) return { ok: false, message: archived.error.message };
    mode = "deactivated";
  } else {
    const removed = await supabase.from("customers").delete().eq("id", id);
    if (removed.error) return { ok: false, message: removed.error.message };
    mode = "deleted";
  }
  const audit = await supabase.from("audit_logs").insert({ actor_id: actor.id, action: mode === "deleted" ? "CUSTOMER_DELETED" : "CUSTOMER_DEACTIVATED", entity_type: "customer", entity_id: id, before_data: customer.data, after_data: mode === "deleted" ? null : { ...customer.data, status: "INACTIVE" } });
  if (audit.error) throw new Error(`Audit write failed: ${audit.error.message}`);
  revalidatePath("/admin/customers");
  revalidatePath(`/admin/customers/${id}`);
  return { ok: true, mode, message: mode === "deleted" ? `${customer.data.company_name} was permanently deleted.` : `${customer.data.company_name} has license history, so it was safely deactivated.` };
}

function planInput(formData: FormData) {
  const seen = new Set<string>();
  const features = formData.getAll("features").map(String).map((feature) => feature.trim()).filter((feature) => {
    const normalized = feature.toLocaleLowerCase("en-IN");
    if (!feature || seen.has(normalized)) return false;
    seen.add(normalized);
    return true;
  });
  return planSchema.safeParse({ name: formData.get("name"), description: formData.get("description"), features, allowOnlineBilling: formData.get("allowOnlineBilling") === "on", allowCloudBackup: formData.get("allowCloudBackup") === "on", isPubliclyVisible: formData.get("isPubliclyVisible") === "on", maxDevices: formData.get("maxDevices"), validationWindowDays: formData.get("validationWindowDays"), priceInRupees: formData.get("priceInRupees"), interval: formData.get("interval"), status: formData.get("status") });
}

export async function createPlan(_state: EntityFormState, formData: FormData): Promise<EntityFormState> {
  const actor = await requireAdminRole(ADMIN_WRITE_ROLES.plans);
  const parsed = planInput(formData);
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.from("plans").insert({ name: parsed.data.name, description: parsed.data.description, features: parsed.data.features, allow_online_billing: parsed.data.allowOnlineBilling, allow_cloud_backup: parsed.data.allowCloudBackup, is_publicly_visible: parsed.data.isPubliclyVisible, max_devices: parsed.data.maxDevices, validation_window_days: parsed.data.validationWindowDays, price_in_paise: rupeesToPaise(parsed.data.priceInRupees), interval: parsed.data.interval, status: parsed.data.status }).select().single();
  if (error) return { message: error.message };
  const audit = await supabase.from("audit_logs").insert({ actor_id: actor.id, action: "PLAN_CREATED", entity_type: "plan", entity_id: data.id, after_data: data });
  if (audit.error) throw new Error(`Audit write failed: ${audit.error.message}`);
  revalidatePath("/plans");
  revalidatePath("/subscribe");
  redirect("/admin/plans");
}

export async function updatePlan(id: string, _state: EntityFormState, formData: FormData): Promise<EntityFormState> {
  const actor = await requireAdminRole(ADMIN_WRITE_ROLES.plans);
  const parsed = planInput(formData);
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  const supabase = await createSupabaseServerClient();
  const before = await supabase.from("plans").select().eq("id", id).single();
  if (before.error) return { message: before.error.message };
  const { data, error } = await supabase.from("plans").update({ name: parsed.data.name, description: parsed.data.description, features: parsed.data.features, allow_online_billing: parsed.data.allowOnlineBilling, allow_cloud_backup: parsed.data.allowCloudBackup, is_publicly_visible: parsed.data.isPubliclyVisible, max_devices: parsed.data.maxDevices, validation_window_days: parsed.data.validationWindowDays, price_in_paise: rupeesToPaise(parsed.data.priceInRupees), interval: parsed.data.interval, status: parsed.data.status }).eq("id", id).select().single();
  if (error) return { message: error.message };
  const audit = await supabase.from("audit_logs").insert({ actor_id: actor.id, action: "PLAN_UPDATED", entity_type: "plan", entity_id: id, before_data: before.data, after_data: data });
  if (audit.error) throw new Error(`Audit write failed: ${audit.error.message}`);
  revalidatePath("/plans");
  revalidatePath("/subscribe");
  redirect("/admin/plans");
}

export async function updatePlatformSettings(_state: EntityFormState, formData: FormData): Promise<EntityFormState> {
  const actor = await requireAdminRole(["OWNER", "ADMIN"]);
  const parsed = platformSettingsSchema.safeParse({ defaultValidationWindowDays: formData.get("defaultValidationWindowDays"), expiryWarningDays: formData.get("expiryWarningDays"), licenseIssuer: formData.get("licenseIssuer") });
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.from("platform_settings").update({ default_validation_window_days: parsed.data.defaultValidationWindowDays, expiry_warning_days: parsed.data.expiryWarningDays, license_issuer: parsed.data.licenseIssuer, updated_by: actor.id }).eq("singleton", true);
  if (error) return { message: error.message };
  redirect("/admin/settings?saved=1");
}

export async function createLicense(_state: EntityFormState, formData: FormData): Promise<EntityFormState> {
  const actor = await requireAdminRole(ADMIN_WRITE_ROLES.licenses);
  const expiryInput = String(formData.get("expiresAt") ?? "");
  const expiryDate = /^\d{4}-\d{2}-\d{2}$/.test(expiryInput) ? new Date(`${expiryInput}T23:59:59.999Z`) : new Date(Number.NaN);
  const parsed = generateLicenseSchema.safeParse({ customerId: formData.get("customerId"), planId: formData.get("planId"), expiresAt: Number.isNaN(expiryDate.getTime()) ? "" : expiryDate.toISOString() });
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  const supabase = await createSupabaseServerClient();
  const [customer, plan] = await Promise.all([
    supabase.from("customers").select("id, company_name, status").eq("id", parsed.data.customerId).single(),
    supabase.from("plans").select("id, name, max_devices, validation_window_days, allow_online_billing, allow_cloud_backup, status").eq("id", parsed.data.planId).single(),
  ]);
  if (customer.error || customer.data.status !== "ACTIVE") return { message: "Select an active customer." };
  if (plan.error || plan.data.status !== "ACTIVE") return { message: "Select an active plan." };
  const key = generateLicenseKey();
  const { data, error } = await supabase.from("licenses").insert({ customer_id: customer.data.id, plan_id: plan.data.id, license_key_hash: hashLicenseKey(key), license_key_hint: licenseKeyHint(key), license_key_ciphertext: encryptLicenseKey(key), max_devices: plan.data.max_devices, validation_window_days: plan.data.validation_window_days, allow_online_billing: plan.data.allow_online_billing, allow_cloud_backup: plan.data.allow_cloud_backup, expires_at: parsed.data.expiresAt, created_by: actor.id }).select("id, license_key_hint, status, expires_at").single();
  if (error) return { message: error.message };
  const audit = await supabase.from("audit_logs").insert({ actor_id: actor.id, action: "LICENSE_CREATED", entity_type: "license", entity_id: data.id, after_data: { ...data, customer_id: customer.data.id, plan_id: plan.data.id } });
  if (audit.error) throw new Error(`Audit write failed: ${audit.error.message}`);
  revalidatePath("/admin/licenses");
  return { message: "License created. Copy the key now; it will not be shown again.", licenseKey: key, licenseId: data.id };
}

export interface LicenseMutationResult { ok: boolean; message: string }

export async function changeLicenseStatus(id: string, operation: "SUSPEND" | "REVOKE" | "REACTIVATE"): Promise<LicenseMutationResult> {
  const actor = await requireAdminRole(ADMIN_WRITE_ROLES.licenses);
  const admin = createAdminClient();
  const before = await admin.from("licenses").select("id, status, expires_at, license_key_hint").eq("id", id).maybeSingle();
  if (before.error || !before.data) return { ok: false, message: before.error?.message ?? "License not found." };
  if (operation === "REACTIVATE" && new Date(before.data.expires_at) <= new Date()) return { ok: false, message: "Expired licenses cannot be reactivated. Extend the expiry first." };
  if (before.data.status === "REVOKED") return { ok: false, message: "A revoked license cannot be reactivated." };
  const status = operation === "SUSPEND" ? "SUSPENDED" : operation === "REVOKE" ? "REVOKED" : "ACTIVE";
  const updated = await admin.from("licenses").update({ status }).eq("id", id).select("id, status, expires_at, license_key_hint").single();
  if (updated.error) return { ok: false, message: updated.error.message };
  if (operation === "REVOKE") await admin.from("devices").update({ status: "DEACTIVATED", deactivated_at: new Date().toISOString() }).eq("license_id", id).eq("status", "ACTIVE");
  const supabase = await createSupabaseServerClient();
  await supabase.from("audit_logs").insert({ actor_id: actor.id, action: `LICENSE_${status}`, entity_type: "license", entity_id: id, before_data: before.data, after_data: updated.data });
  revalidatePath("/admin/licenses");
  revalidatePath(`/admin/licenses/${id}`);
  return { ok: true, message: operation === "REVOKE" ? "License revoked and all active devices were blocked." : `License is now ${status.toLowerCase()}.` };
}

export async function deactivateLicenseDevice(licenseId: string, deviceId: string): Promise<LicenseMutationResult> {
  const actor = await requireAdminRole(ADMIN_WRITE_ROLES.devices);
  const admin = createAdminClient();
  const before = await admin.from("devices").select("id, license_id, device_name, status").eq("id", deviceId).eq("license_id", licenseId).maybeSingle();
  if (before.error || !before.data) return { ok: false, message: before.error?.message ?? "Device not found." };
  if (before.data.status !== "ACTIVE") return { ok: false, message: "This device slot is already free." };
  const now = new Date().toISOString();
  const updated = await admin.from("devices").update({ status: "DEACTIVATED", deactivated_at: now }).eq("id", deviceId).select("id, license_id, device_name, status, deactivated_at").single();
  if (updated.error) return { ok: false, message: updated.error.message };
  await admin.from("license_activations").insert({ license_id: licenseId, device_id: deviceId, event: "RESET", success: true, metadata: { actor_id: actor.id, reason: "ADMIN_DEVICE_TRANSFER" } });
  const supabase = await createSupabaseServerClient();
  await supabase.from("audit_logs").insert({ actor_id: actor.id, action: "DEVICE_DEACTIVATED", entity_type: "device", entity_id: deviceId, before_data: before.data, after_data: updated.data });
  revalidatePath(`/admin/licenses/${licenseId}`);
  revalidatePath("/admin/devices");
  return { ok: true, message: `${before.data.device_name} was deactivated. The customer can now activate a replacement device.` };
}
