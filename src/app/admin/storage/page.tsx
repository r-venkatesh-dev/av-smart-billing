import { listR2Files, getR2Config } from "@/lib/r2-storage";
import { checkR2Status } from "@/app/admin/storage-actions";
import { R2StorageManager } from "@/components/r2-storage-manager";
import { requireAdminRole } from "@/lib/auth/authorization";

export const metadata = { title: "Cloudflare R2 Storage" };

export default async function StoragePage() {
  await requireAdminRole(["OWNER", "ADMIN"]);
  const status = await checkR2Status();
  const files = status.configured ? await listR2Files() : [];

  return (
    <R2StorageManager
      initialFiles={files}
      isConfigured={status.configured}
      bucketName={status.bucketName}
      publicBaseUrl={status.publicBaseUrl}
      accountIdMasked={status.accountIdMasked}
    />
  );
}
