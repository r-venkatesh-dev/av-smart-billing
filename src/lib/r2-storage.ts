import "server-only";

import {
  S3Client,
  ListObjectsV2Command,
  DeleteObjectCommand,
  PutObjectCommand,
  HeadObjectCommand,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

export interface R2Config {
  accountId: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucketName: string;
  publicBaseUrl: string;
}

export interface R2FileItem {
  key: string;
  name: string;
  size: number;
  lastModified: string;
  etag: string;
  category: "windows" | "mac" | "android" | "other";
  publicUrl: string;
}

/**
 * Resolves R2 configuration from environment variables.
 */
export function getR2Config(): R2Config | null {
  const accountId =
    process.env.R2_ACCOUNT_ID?.trim() ||
    process.env.CLOUDFLARE_ACCOUNT_ID?.trim();
  const accessKeyId = process.env.R2_ACCESS_KEY_ID?.trim();
  const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY?.trim();
  const bucketName =
    process.env.R2_BUCKET_NAME?.trim() || "av-smartbilling-downloads";
  const publicBaseUrl =
    process.env.NEXT_PUBLIC_DOWNLOADS_BASE_URL?.trim().replace(/\/+$/, "") ||
    "https://pub-51a0e58578b448948e5647729cfd26e7.r2.dev/downloads";

  if (!accountId || !accessKeyId || !secretAccessKey) {
    return null;
  }

  return {
    accountId,
    accessKeyId,
    secretAccessKey,
    bucketName,
    publicBaseUrl,
  };
}

export function createR2Client(config: R2Config): S3Client {
  return new S3Client({
    region: "auto",
    endpoint: `https://${config.accountId}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: config.accessKeyId,
      secretAccessKey: config.secretAccessKey,
    },
  });
}

function classifyCategory(fileName: string): "windows" | "mac" | "android" | "other" {
  const lower = fileName.toLowerCase();
  if (lower.endsWith(".exe") || lower.endsWith(".msi")) return "windows";
  if (lower.endsWith(".dmg") || lower.endsWith(".pkg") || lower.includes("mac") || lower.includes("darwin")) return "mac";
  if (lower.endsWith(".apk") || lower.endsWith(".aab")) return "android";
  return "other";
}

/**
 * Lists all installer and distribution files in the R2 bucket.
 */
export async function listR2Files(prefix: string = ""): Promise<R2FileItem[]> {
  const config = getR2Config();
  if (!config) return [];

  const client = createR2Client(config);
  const command = new ListObjectsV2Command({
    Bucket: config.bucketName,
    Prefix: prefix,
  });

  const response = await client.send(command);
  const contents = response.Contents || [];

  return contents
    .filter((item) => item.Key && !item.Key.endsWith("/"))
    .map((item) => {
      const key = item.Key!;
      const name = key.split("/").pop() || key;
      const cleanBase = config.publicBaseUrl.replace(/\/+$/, "");
      
      // If the publicBaseUrl already ends with '/downloads' and the key starts with 'downloads/', avoid duplicate
      let relativeKey = key;
      if (cleanBase.endsWith("/downloads") && relativeKey.startsWith("downloads/")) {
        relativeKey = relativeKey.substring("downloads/".length);
      }

      const publicUrl = `${cleanBase}/${encodeURIComponent(relativeKey)}`;

      return {
        key,
        name,
        size: item.Size || 0,
        lastModified: item.LastModified?.toISOString() || new Date().toISOString(),
        etag: (item.ETag || "").replace(/"/g, ""),
        category: classifyCategory(name),
        publicUrl,
      };
    })
    .sort((a, b) => new Date(b.lastModified).getTime() - new Date(a.lastModified).getTime());
}

/**
 * Generates a presigned PUT URL allowing large files (100MB+) to be uploaded directly
 * from the browser to Cloudflare R2 without passing through the Next.js web server.
 */
export async function getR2PresignedUploadUrl({
  fileName,
  contentType,
  folder = "downloads",
}: {
  fileName: string;
  contentType: string;
  folder?: string;
}): Promise<{ uploadUrl: string; key: string; publicUrl: string }> {
  const config = getR2Config();
  if (!config) {
    throw new Error(
      "Cloudflare R2 is not configured. Please supply R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, and R2_SECRET_ACCESS_KEY in environment variables.",
    );
  }

  const cleanFileName = fileName.replace(/[^a-zA-Z0-9.\-_]/g, "_");
  const key = folder ? `${folder.replace(/\/+$/, "")}/${cleanFileName}` : cleanFileName;

  const client = createR2Client(config);
  const command = new PutObjectCommand({
    Bucket: config.bucketName,
    Key: key,
    ContentType: contentType || "application/octet-stream",
  });

  const uploadUrl = await getSignedUrl(client, command, { expiresIn: 3600 });
  const cleanBase = config.publicBaseUrl.replace(/\/+$/, "");
  let relativeKey = key;
  if (cleanBase.endsWith("/downloads") && relativeKey.startsWith("downloads/")) {
    relativeKey = relativeKey.substring("downloads/".length);
  }
  const publicUrl = `${cleanBase}/${encodeURIComponent(relativeKey)}`;

  return { uploadUrl, key, publicUrl };
}

/**
 * Uploads a file buffer directly to R2 (for smaller files).
 */
export async function uploadR2File({
  key,
  body,
  contentType,
}: {
  key: string;
  body: Uint8Array | Buffer;
  contentType: string;
}): Promise<{ ok: boolean; key: string; publicUrl: string }> {
  const config = getR2Config();
  if (!config) {
    throw new Error("Cloudflare R2 credentials are missing.");
  }

  const client = createR2Client(config);
  const command = new PutObjectCommand({
    Bucket: config.bucketName,
    Key: key,
    Body: body,
    ContentType: contentType,
  });

  await client.send(command);

  const cleanBase = config.publicBaseUrl.replace(/\/+$/, "");
  let relativeKey = key;
  if (cleanBase.endsWith("/downloads") && relativeKey.startsWith("downloads/")) {
    relativeKey = relativeKey.substring("downloads/".length);
  }
  const publicUrl = `${cleanBase}/${encodeURIComponent(relativeKey)}`;

  return { ok: true, key, publicUrl };
}

/**
 * Deletes an object from the Cloudflare R2 bucket.
 */
export async function deleteR2File(key: string): Promise<boolean> {
  const config = getR2Config();
  if (!config) {
    throw new Error("Cloudflare R2 credentials are missing.");
  }

  const client = createR2Client(config);
  const command = new DeleteObjectCommand({
    Bucket: config.bucketName,
    Key: key,
  });

  await client.send(command);
  return true;
}
