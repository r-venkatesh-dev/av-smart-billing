import { listR2Files } from "@/lib/r2-storage";
import { checkR2Status } from "@/app/admin/storage-actions";
import { R2StorageManager } from "@/components/r2-storage-manager";
import { requireAdminRole } from "@/lib/auth/authorization";

export const metadata = { title: "Cloudflare R2 Storage" };

export default async function StoragePage() {
  await requireAdminRole(["OWNER", "ADMIN"]);
  const status = await checkR2Status();
  let files: Awaited<ReturnType<typeof listR2Files>> = [];
  let connectionError: string | null = null;

  if (status.configured) {
    try {
      files = await listR2Files();
    } catch (err: unknown) {
      const errorObj = err as { Code?: string; message?: string };
      if (errorObj?.Code === "NoSuchBucket") {
        connectionError = `Bucket "${status.bucketName}" was not found. Please verify the exact bucket name in Cloudflare R2 (check for typos like "av-smartbilling" vs "av-smarbilling") or ensure your API Token has permission for this bucket.`;
      } else {
        connectionError = errorObj?.message || "Failed to connect to Cloudflare R2.";
      }
    }
  }

  return (
    <R2StorageManager
      initialFiles={files}
      isConfigured={status.configured}
      bucketName={status.bucketName}
      publicBaseUrl={status.publicBaseUrl}
      accountIdMasked={status.accountIdMasked}
      connectionError={connectionError}
    />
  );
}
