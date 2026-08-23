"use server";

import { createClient } from "@supabase/supabase-js";
import { requireAdminRole } from "@/lib/auth/authorization";
import { getPublicEnv } from "@/lib/env";
import { decryptLicenseKey } from "@/lib/license-key-vault";
import { createAdminClient } from "@/lib/supabase/admin";

export interface RevealLicenseKeyResult { ok: boolean; message: string; licenseKey?: string }

export async function revealLicenseKey(licenseId: string, password: string): Promise<RevealLicenseKeyResult> {
  const actor = await requireAdminRole(["OWNER", "ADMIN"]);
  if (!password || password.length > 200) return { ok: false, message: "Enter your admin login password." };

  const env = getPublicEnv();
  const verifier = createClient(env.NEXT_PUBLIC_SUPABASE_URL, env.NEXT_PUBLIC_SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
  const verified = await verifier.auth.signInWithPassword({ email: actor.email, password });
  if (verified.error || verified.data.user?.id !== actor.id) return { ok: false, message: "The admin password is incorrect." };

  const admin = createAdminClient();
  const license = await admin.from("licenses").select("id, license_key_hint, license_key_ciphertext").eq("id", licenseId).maybeSingle();
  if (license.error || !license.data) return { ok: false, message: "License not found." };
  if (!license.data.license_key_ciphertext) return { ok: false, message: "This legacy key was stored as a one-way hash and cannot be recovered." };

  try {
    const licenseKey = decryptLicenseKey(license.data.license_key_ciphertext);
    const audit = await admin.from("audit_logs").insert({ actor_id: actor.id, action: "LICENSE_KEY_REVEALED", entity_type: "license", entity_id: licenseId, after_data: { license_key_hint: license.data.license_key_hint } });
    if (audit.error) return { ok: false, message: "The key was not revealed because the security audit could not be recorded." };
    return { ok: true, message: "Key revealed for this page only.", licenseKey };
  } catch {
    return { ok: false, message: "The encrypted key could not be opened. Check the deployment encryption secret." };
  }
}
