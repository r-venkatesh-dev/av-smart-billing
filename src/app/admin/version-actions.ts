"use server";

import { revalidatePath } from "next/cache";
import { requireAdminRole } from "@/lib/auth/authorization";
import { createAdminClient } from "@/lib/supabase/admin";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export interface VersionActionResult {
  ok: boolean;
  message: string;
}

export async function createAppVersion(formData: FormData): Promise<VersionActionResult> {
  const actor = await requireAdminRole(["OWNER", "ADMIN"]);
  const platform = String(formData.get("platform") || "android").toLowerCase().trim();
  const latestVersion = String(formData.get("latestVersion") || "").trim();
  const latestBuildNumber = parseInt(String(formData.get("latestBuildNumber") || "0"), 10);
  const minRequiredBuild = parseInt(String(formData.get("minRequiredBuild") || "1"), 10);
  const updateUrl = String(formData.get("updateUrl") || "").trim();
  const releaseNotes = String(formData.get("releaseNotes") || "").trim();
  const isActive = formData.get("isActive") === "on" || formData.get("isActive") === "true";

  if (!["android", "ios"].includes(platform)) {
    return { ok: false, message: "Platform must be either 'android' or 'ios'." };
  }
  if (!latestVersion) {
    return { ok: false, message: "Version string is required (e.g. 1.0.1)." };
  }
  if (isNaN(latestBuildNumber) || latestBuildNumber <= 0) {
    return { ok: false, message: "Latest build number must be a positive integer." };
  }
  if (isNaN(minRequiredBuild) || minRequiredBuild <= 0) {
    return { ok: false, message: "Minimum required build must be a positive integer." };
  }
  if (!updateUrl) {
    return { ok: false, message: "Update URL is required." };
  }

  const admin = createAdminClient();
  const { data, error } = await admin
    .from("app_versions")
    .insert({
      platform,
      latest_version: latestVersion,
      latest_build_number: latestBuildNumber,
      min_required_build: minRequiredBuild,
      update_url: updateUrl,
      release_notes: releaseNotes,
      is_active: isActive,
      updated_at: new Date().toISOString(),
    })
    .select()
    .single();

  if (error) {
    return { ok: false, message: error.message };
  }

  const supabase = await createSupabaseServerClient();
  await supabase.from("audit_logs").insert({
    actor_id: actor.id,
    action: "APP_VERSION_CREATED",
    entity_type: "app_version",
    entity_id: data.id,
    before_data: null,
    after_data: data,
  });

  revalidatePath("/admin/app-versions");
  return { ok: true, message: `Version ${latestVersion} (Build ${latestBuildNumber}) created successfully.` };
}

export async function updateAppVersion(id: string, formData: FormData): Promise<VersionActionResult> {
  const actor = await requireAdminRole(["OWNER", "ADMIN"]);
  const platform = String(formData.get("platform") || "android").toLowerCase().trim();
  const latestVersion = String(formData.get("latestVersion") || "").trim();
  const latestBuildNumber = parseInt(String(formData.get("latestBuildNumber") || "0"), 10);
  const minRequiredBuild = parseInt(String(formData.get("minRequiredBuild") || "1"), 10);
  const updateUrl = String(formData.get("updateUrl") || "").trim();
  const releaseNotes = String(formData.get("releaseNotes") || "").trim();
  const isActive = formData.get("isActive") === "on" || formData.get("isActive") === "true";

  if (!["android", "ios"].includes(platform)) {
    return { ok: false, message: "Platform must be either 'android' or 'ios'." };
  }
  if (!latestVersion) {
    return { ok: false, message: "Version string is required." };
  }
  if (isNaN(latestBuildNumber) || latestBuildNumber <= 0) {
    return { ok: false, message: "Build number must be a positive integer." };
  }
  if (isNaN(minRequiredBuild) || minRequiredBuild <= 0) {
    return { ok: false, message: "Minimum required build must be a positive integer." };
  }
  if (!updateUrl) {
    return { ok: false, message: "Update URL is required." };
  }

  const admin = createAdminClient();
  const before = await admin.from("app_versions").select().eq("id", id).maybeSingle();
  if (before.error || !before.data) {
    return { ok: false, message: before.error?.message || "App version record not found." };
  }

  const { data, error } = await admin
    .from("app_versions")
    .update({
      platform,
      latest_version: latestVersion,
      latest_build_number: latestBuildNumber,
      min_required_build: minRequiredBuild,
      update_url: updateUrl,
      release_notes: releaseNotes,
      is_active: isActive,
      updated_at: new Date().toISOString(),
    })
    .eq("id", id)
    .select()
    .single();

  if (error) {
    return { ok: false, message: error.message };
  }

  const supabase = await createSupabaseServerClient();
  await supabase.from("audit_logs").insert({
    actor_id: actor.id,
    action: "APP_VERSION_UPDATED",
    entity_type: "app_version",
    entity_id: id,
    before_data: before.data,
    after_data: data,
  });

  revalidatePath("/admin/app-versions");
  return { ok: true, message: `Version ${latestVersion} updated successfully.` };
}

export async function deleteAppVersion(id: string): Promise<VersionActionResult> {
  const actor = await requireAdminRole(["OWNER", "ADMIN"]);
  const admin = createAdminClient();
  const before = await admin.from("app_versions").select().eq("id", id).maybeSingle();
  if (before.error || !before.data) {
    return { ok: false, message: before.error?.message || "Version record not found." };
  }

  const { error } = await admin.from("app_versions").delete().eq("id", id);
  if (error) {
    return { ok: false, message: error.message };
  }

  const supabase = await createSupabaseServerClient();
  await supabase.from("audit_logs").insert({
    actor_id: actor.id,
    action: "APP_VERSION_DELETED",
    entity_type: "app_version",
    entity_id: id,
    before_data: before.data,
    after_data: null,
  });

  revalidatePath("/admin/app-versions");
  return { ok: true, message: `Version ${before.data.latest_version} (Build ${before.data.latest_build_number}) was deleted.` };
}

export async function toggleAppVersionActive(id: string, active: boolean): Promise<VersionActionResult> {
  await requireAdminRole(["OWNER", "ADMIN"]);
  const admin = createAdminClient();
  const { error } = await admin
    .from("app_versions")
    .update({ is_active: active, updated_at: new Date().toISOString() })
    .eq("id", id);

  if (error) return { ok: false, message: error.message };

  revalidatePath("/admin/app-versions");
  return { ok: true, message: `Version status updated to ${active ? "Active" : "Inactive"}.` };
}
