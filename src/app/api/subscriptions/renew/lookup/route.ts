import type { NextRequest } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { createRenewalSessionToken, verifyRenewalSessionToken } from "@/lib/renewal-token";
import { hashLicenseKey } from "@/lib/license-key";
import { z } from "zod";

export const runtime = "nodejs";

const lookupSchema = z.object({
  token: z.string().optional(),
  licenseKey: z.string().trim().optional(),
  phone: z.string().trim().optional(),
});

function maskPhone(phone: string) {
  const digits = phone.replace(/\D/g, "");
  if (digits.length < 4) return "••••";
  return `••••••${digits.slice(-4)}`;
}

export async function POST(request: NextRequest) {
  const body = await request.json().catch(() => null);
  const parsed = lookupSchema.safeParse(body);
  if (!parsed.success) {
    return Response.json({ ok: false, message: "Invalid lookup query." }, { status: 400 });
  }

  const { token, licenseKey, phone } = parsed.data;
  const supabase = createAdminClient();

  let licenseId: string | null = null;

  if (token) {
    const payload = verifyRenewalSessionToken(token);
    if (!payload) {
      return Response.json({ ok: false, message: "Renewal session has expired or is invalid. Please look up using your license key or phone." }, { status: 401 });
    }
    licenseId = payload.licenseId;
  } else if (licenseKey) {
    const rawKey = licenseKey.trim();
    const cleanChars = rawKey.replace(/[^A-Za-z0-9]/g, "").toUpperCase();
    const keyHash = hashLicenseKey(cleanChars);

    let { data: license } = await supabase
      .from("licenses")
      .select("id")
      .eq("license_key_hash", keyHash)
      .maybeSingle();

    // Fallback: Check if user pasted the masked hint (e.g. 8GYP-••••-••••-ANM5)
    if (!license) {
      const hintMatch = await supabase
        .from("licenses")
        .select("id")
        .eq("license_key_hint", rawKey.toUpperCase())
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (hintMatch.data) {
        license = hintMatch.data;
      }
    }

    if (!license) {
      return Response.json({ ok: false, message: "No license found matching this key. Please check the characters or try looking up with your phone number." }, { status: 404 });
    }
    licenseId = license.id;
  } else if (phone) {
    const digits = phone.replace(/\D/g, "");
    if (digits.length < 5) {
      return Response.json({ ok: false, message: "Please enter a valid mobile number." }, { status: 400 });
    }
    const last10 = digits.length >= 10 ? digits.slice(-10) : digits;

    // Look up ALL customers matching this phone number (exact or last 10 digits)
    const { data: matchingCustomers } = await supabase
      .from("customers")
      .select("id")
      .or(`phone.eq.${digits},phone.ilike.%${last10}%`);

    const customerIds = (matchingCustomers ?? []).map((c) => c.id);
    if (customerIds.length === 0) {
      return Response.json({ ok: false, message: "No registered customer found with this mobile number." }, { status: 404 });
    }

    // Find licenses across ALL matching customer accounts
    const { data: licenses } = await supabase
      .from("licenses")
      .select("id, status, expires_at, created_at")
      .in("customer_id", customerIds)
      .order("expires_at", { ascending: false });

    if (!licenses || licenses.length === 0) {
      return Response.json({ ok: false, message: "No license associated with this customer phone." }, { status: 404 });
    }

    // Prioritize active license with the latest expiry date
    const activeLicense = licenses.find((l) => l.status === "ACTIVE") || licenses[0];
    licenseId = activeLicense.id;
  } else {
    return Response.json({ ok: false, message: "Please provide a token, license key, or registered phone number." }, { status: 400 });
  }

  // Fetch full details of the license
  const { data: license, error } = await supabase
    .from("licenses")
    .select(`
      id,
      status,
      expires_at,
      license_key_hint,
      plans (
        id,
        name,
        description,
        price_in_paise,
        interval,
        allow_online_billing,
        allow_cloud_backup,
        allow_reports_exports,
        max_devices
      ),
      customers (
        company_name,
        contact_person,
        phone,
        email
      )
    `)
    .eq("id", licenseId)
    .single();

  if (error || !license) {
    return Response.json({ ok: false, message: "License record could not be loaded." }, { status: 404 });
  }

  const plan = Array.isArray(license.plans) ? license.plans[0] : license.plans;
  const customer = Array.isArray(license.customers) ? license.customers[0] : license.customers;

  if (!plan || !customer) {
    return Response.json({ ok: false, message: "License metadata is incomplete." }, { status: 500 });
  }

  const expiresAt = new Date(license.expires_at);
  const now = new Date();
  const diffDays = Math.ceil((expiresAt.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
  const isExpired = expiresAt < now;

  // Generate encrypted token for checkout
  const sessionToken = createRenewalSessionToken(license.id, 3600);

  return Response.json({
    ok: true,
    token: sessionToken,
    details: {
      licenseKeyHint: license.license_key_hint,
      companyName: customer.company_name,
      contactPerson: customer.contact_person,
      phoneMasked: maskPhone(customer.phone),
      planName: plan.name,
      planInterval: plan.interval,
      priceInPaise: Number(plan.price_in_paise),
      expiresAt: license.expires_at,
      isExpired,
      daysRemaining: Math.max(0, diffDays),
      maxDevices: plan.max_devices,
      allowCloudBackup: plan.allow_cloud_backup,
      allowOnlineBilling: plan.allow_online_billing,
      allowReportsExports: plan.allow_reports_exports,
    },
  }, { headers: { "Cache-Control": "no-store" } });
}
