import "server-only";

import { requireAdminRole } from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

function assertQuery<T>(data: T | null, error: { message: string } | null): T {
  if (error) throw new Error(`Supabase query failed: ${error.message}`);
  if (data === null) throw new Error("Supabase query returned no data");
  return data;
}

function one<T>(value: T | T[] | null): T | null {
  return Array.isArray(value) ? value[0] ?? null : value;
}

export async function listAdminCustomers() {
  await requireAdminRole();
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("customers")
    .select("id, company_name, contact_person, email, phone, address, gstin, status, created_at, licenses(count)")
    .order("created_at", { ascending: false });

  return assertQuery(data, error).map((row) => ({
    id: row.id,
    companyName: row.company_name,
    contactPerson: row.contact_person,
    email: row.email,
    phone: row.phone,
    address: row.address,
    gstin: row.gstin,
    status: row.status,
    createdAt: row.created_at,
    licenseCount: one(row.licenses)?.count ?? 0,
  }));
}

export async function getAdminCustomer(id: string) {
  await requireAdminRole();
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("customers")
    .select("id, company_name, contact_person, email, phone, address, gstin, status, created_at, licenses(id, license_key_hint, status, expires_at, plans(name))")
    .eq("id", id)
    .maybeSingle();

  if (error) throw new Error(`Supabase query failed: ${error.message}`);
  if (!data) return null;
  return {
    id: data.id,
    companyName: data.company_name,
    contactPerson: data.contact_person,
    email: data.email,
    phone: data.phone,
    address: data.address,
    gstin: data.gstin,
    status: data.status,
    createdAt: data.created_at,
    licenses: (data.licenses ?? []).map((license) => ({
      id: license.id,
      maskedKey: license.license_key_hint,
      status: license.status,
      expiresAt: license.expires_at,
      planName: one(license.plans)?.name ?? "Unknown plan",
    })),
  };
}

export async function listAdminPlans() {
  await requireAdminRole();
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("plans")
    .select("id, name, description, features, allow_online_billing, allow_cloud_backup, allow_reports_exports, is_publicly_visible, max_devices, validation_window_days, price_in_paise, interval, status")
    .order("price_in_paise");
  return assertQuery(data, error).map((row) => ({
    id: row.id,
    name: row.name,
    description: row.description,
    features: Array.isArray(row.features) ? row.features.filter((feature): feature is string => typeof feature === "string") : [],
    allowOnlineBilling: row.allow_online_billing,
    allowCloudBackup: row.allow_cloud_backup,
    allowReportsExports: row.allow_reports_exports,
    isPubliclyVisible: row.is_publicly_visible,
    maxDevices: row.max_devices,
    validationWindowDays: row.validation_window_days,
    priceInPaise: Number(row.price_in_paise),
    interval: row.interval,
    status: row.status,
  }));
}

export async function listAdminSubscriptionOrders() {
  await requireAdminRole();
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("subscription_orders")
    .select("id, company_name, contact_person, email, phone, gstin, plan_name, amount_in_paise, currency, status, razorpay_order_id, latest_razorpay_payment_id, failure_code, failure_description, paid_at, created_at, customer_id, license_id, subscription_payment_attempts(count)")
    .order("created_at", { ascending: false });
  return assertQuery(data, error).map((row) => ({
    id: row.id,
    companyName: row.company_name,
    contactPerson: row.contact_person,
    email: row.email,
    phone: row.phone,
    gstin: row.gstin,
    planName: row.plan_name,
    amountInPaise: Number(row.amount_in_paise),
    currency: row.currency,
    status: row.status,
    razorpayOrderId: row.razorpay_order_id,
    razorpayPaymentId: row.latest_razorpay_payment_id,
    failureCode: row.failure_code,
    failureDescription: row.failure_description,
    paidAt: row.paid_at,
    createdAt: row.created_at,
    customerId: row.customer_id,
    licenseId: row.license_id,
    attemptCount: one(row.subscription_payment_attempts)?.count ?? 0,
  }));
}

export async function listAdminLicenses(limit?: number) {
  await requireAdminRole();
  const supabase = await createSupabaseServerClient();
  let query = supabase
    .from("licenses")
    .select("id, license_key_hint, license_key_ciphertext, max_devices, validation_window_days, status, expires_at, last_validated_at, created_at, customers(id, company_name), plans(id, name), devices(status)")
    .order("created_at", { ascending: false });
  if (limit) query = query.limit(limit);
  const { data, error } = await query;
  const expiringCutoff = new Date();
  expiringCutoff.setDate(expiringCutoff.getDate() + 30);
  return assertQuery(data, error).map((row) => ({
    id: row.id,
    maskedKey: row.license_key_hint,
    recoverableKey: Boolean(row.license_key_ciphertext),
    maxDevices: row.max_devices,
    validationWindowDays: row.validation_window_days,
    status: row.status,
    expiresAt: row.expires_at,
    lastValidatedAt: row.last_validated_at,
    createdAt: row.created_at,
    customerId: one(row.customers)?.id ?? "",
    customerName: one(row.customers)?.company_name ?? "Unknown customer",
    planId: one(row.plans)?.id ?? "",
    planName: one(row.plans)?.name ?? "Unknown plan",
    activeDevices: (row.devices ?? []).filter((device) => device.status === "ACTIVE").length,
    isExpiringSoon: row.status === "ACTIVE" && new Date(row.expires_at) <= expiringCutoff,
  }));
}

export async function getAdminLicense(id: string) {
  await requireAdminRole();
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("licenses")
    .select("id, license_key_hint, license_key_ciphertext, max_devices, validation_window_days, status, expires_at, last_validated_at, created_at, customers(company_name), plans(name), devices(id, device_name, fingerprint_hint, status, activated_at, last_validated_at)")
    .eq("id", id)
    .maybeSingle();
  if (error) throw new Error(`Supabase query failed: ${error.message}`);
  if (!data) return null;
  return {
    id: data.id,
    maskedKey: data.license_key_hint,
    recoverableKey: Boolean(data.license_key_ciphertext),
    maxDevices: data.max_devices,
    validationWindowDays: data.validation_window_days,
    status: data.status,
    expiresAt: data.expires_at,
    lastValidatedAt: data.last_validated_at,
    createdAt: data.created_at,
    customerName: one(data.customers)?.company_name ?? "Unknown customer",
    planName: one(data.plans)?.name ?? "Unknown plan",
    devices: (data.devices ?? []).map((device) => ({
      id: device.id,
      name: device.device_name,
      fingerprintPreview: device.fingerprint_hint,
      status: device.status,
      activatedAt: device.activated_at,
      lastValidatedAt: device.last_validated_at,
    })),
  };
}

export async function listAdminDevices() {
  await requireAdminRole();
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("devices")
    .select("id, device_name, fingerprint_hint, status, activated_at, last_validated_at, licenses(id, license_key_hint, customers(company_name))")
    .order("last_validated_at", { ascending: false });
  return assertQuery(data, error).map((row) => {
    const license = one(row.licenses);
    return {
      id: row.id,
      name: row.device_name,
      fingerprintPreview: row.fingerprint_hint,
      status: row.status,
      activatedAt: row.activated_at,
      lastValidatedAt: row.last_validated_at,
      licenseId: license?.id ?? "",
      maskedKey: license?.license_key_hint ?? "",
      customerName: one(license?.customers ?? null)?.company_name ?? "Unknown customer",
    };
  });
}

export async function getPlatformSettings() {
  await requireAdminRole();
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.from("platform_settings").select("default_validation_window_days, expiry_warning_days, license_issuer, updated_at").eq("singleton", true).single();
  if (error) throw new Error(`Supabase query failed: ${error.message}`);
  return { defaultValidationWindowDays: data.default_validation_window_days, expiryWarningDays: data.expiry_warning_days, licenseIssuer: data.license_issuer, updatedAt: data.updated_at };
}

async function countRows(table: "customers" | "licenses" | "devices", filter?: { status?: string; expiresFrom?: string; expiresTo?: string }) {
  const supabase = await createSupabaseServerClient();
  let query = supabase.from(table).select("id", { count: "exact", head: true });
  if (filter?.status) query = query.eq("status", filter.status);
  if (filter?.expiresFrom) query = query.gte("expires_at", filter.expiresFrom);
  if (filter?.expiresTo) query = query.lte("expires_at", filter.expiresTo);
  const { count, error } = await query;
  if (error) throw new Error(`Supabase count failed: ${error.message}`);
  return count ?? 0;
}

export async function getAdminDashboard() {
  await requireAdminRole();
  const now = new Date();
  const thirtyDays = new Date(now);
  thirtyDays.setDate(thirtyDays.getDate() + 30);
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
  const sixMonthsStart = new Date(now.getFullYear(), now.getMonth() - 5, 1).toISOString();
  const supabase = await createSupabaseServerClient();

  const [customerCount, activeLicenseCount, activeDeviceCount, expiringCount, recentLicenses, licenseGrowth, customerGrowth] = await Promise.all([
    countRows("customers"),
    countRows("licenses", { status: "ACTIVE" }),
    countRows("devices", { status: "ACTIVE" }),
    countRows("licenses", { status: "ACTIVE", expiresFrom: now.toISOString(), expiresTo: thirtyDays.toISOString() }),
    listAdminLicenses(5),
    supabase.from("licenses").select("created_at, status").gte("created_at", sixMonthsStart),
    supabase.from("customers").select("created_at").gte("created_at", sixMonthsStart),
  ]);
  if (licenseGrowth.error) throw new Error(`Supabase query failed: ${licenseGrowth.error.message}`);
  if (customerGrowth.error) throw new Error(`Supabase query failed: ${customerGrowth.error.message}`);

  const months = Array.from({ length: 6 }, (_, offset) => {
    const date = new Date(now.getFullYear(), now.getMonth() - 5 + offset, 1);
    return { key: `${date.getFullYear()}-${date.getMonth()}`, label: date.toLocaleDateString("en-IN", { month: "short" }), licenses: 0, customers: 0 };
  });
  for (const row of licenseGrowth.data ?? []) {
    const date = new Date(row.created_at);
    const bucket = months.find((month) => month.key === `${date.getFullYear()}-${date.getMonth()}`);
    if (bucket) bucket.licenses += 1;
  }
  for (const row of customerGrowth.data ?? []) {
    const date = new Date(row.created_at);
    const bucket = months.find((month) => month.key === `${date.getFullYear()}-${date.getMonth()}`);
    if (bucket) bucket.customers += 1;
  }

  const newCustomersThisMonth = (customerGrowth.data ?? []).filter((row) => row.created_at >= monthStart).length;
  return { customerCount, activeLicenseCount, activeDeviceCount, expiringCount, newCustomersThisMonth, recentLicenses, months };
}
