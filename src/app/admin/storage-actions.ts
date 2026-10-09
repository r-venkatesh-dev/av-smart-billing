"use server";

import { revalidatePath } from "next/cache";
import { requireAdminRole } from "@/lib/auth/authorization";
import {
  getR2Config,
  listR2Files,
  deleteR2File,
  getR2PresignedUploadUrl,
  type R2FileItem,
} from "@/lib/r2-storage";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export interface StorageActionResult {
  ok: boolean;
  message: string;
}

export async function checkR2Status(): Promise<{
  configured: boolean;
  bucketName: string | null;
  publicBaseUrl: string | null;
  accountIdMasked: string | null;
}> {
  await requireAdminRole(["OWNER", "ADMIN"]);
  const config = getR2Config();
  if (!config) {
    return {
      configured: false,
      bucketName: null,
      publicBaseUrl: null,
      accountIdMasked: null,
    };
  }

  const masked =
    config.accountId.length > 8
      ? `${config.accountId.substring(0, 4)}••••${config.accountId.substring(config.accountId.length - 4)}`
      : "••••••••";

  return {
    configured: true,
    bucketName: config.bucketName,
    publicBaseUrl: config.publicBaseUrl,
    accountIdMasked: masked,
  };
}

export async function requestPresignedUpload(
  fileName: string,
  contentType: string,
  folder: string = "downloads",
): Promise<{ ok: boolean; uploadUrl?: string; key?: string; publicUrl?: string; message?: string }> {
  const actor = await requireAdminRole(["OWNER", "ADMIN"]);
  try {
    const { uploadUrl, key, publicUrl } = await getR2PresignedUploadUrl({
      fileName,
      contentType,
      folder,
    });

    const supabase = await createSupabaseServerClient();
    await supabase.from("audit_logs").insert({
      actor_id: actor.id,
      action: "R2_UPLOAD_INITIATED",
      entity_type: "storage",
      entity_id: key,
      after_data: { fileName, contentType, folder, key },
    });

    return { ok: true, uploadUrl, key, publicUrl };
  } catch (err) {
    return {
      ok: false,
      message: err instanceof Error ? err.message : "Failed to generate presigned upload URL.",
    };
  }
}

export async function removeStorageFile(key: string): Promise<StorageActionResult> {
  const actor = await requireAdminRole(["OWNER", "ADMIN"]);
  try {
    await deleteR2File(key);

    const supabase = await createSupabaseServerClient();
    await supabase.from("audit_logs").insert({
      actor_id: actor.id,
      action: "R2_FILE_DELETED",
      entity_type: "storage",
      entity_id: key,
      after_data: { key },
    });

    revalidatePath("/admin/storage");
    return { ok: true, message: `File "${key}" was removed from Cloudflare R2.` };
  } catch (err) {
    return {
      ok: false,
      message: err instanceof Error ? err.message : "Failed to delete file from Cloudflare R2.",
    };
  }
}

export async function refreshStorageListing(): Promise<R2FileItem[]> {
  await requireAdminRole(["OWNER", "ADMIN"]);
  return listR2Files();
}
