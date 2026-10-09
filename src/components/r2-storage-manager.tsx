"use client";

import { useState, useTransition, useRef } from "react";
import {
  UploadCloud,
  FileCode,
  HardDrive,
  Copy,
  Check,
  Trash2,
  Download,
  AlertTriangle,
  Loader2,
  Search,
  ExternalLink,
  ShieldCheck,
  CheckCircle2,
  FolderOpen,
  Info,
} from "lucide-react";
import type { R2FileItem } from "@/lib/r2-storage";
import {
  requestPresignedUpload,
  removeStorageFile,
  refreshStorageListing,
} from "@/app/admin/storage-actions";
import { useAdminBusy } from "@/components/admin-busy-overlay";

function formatBytes(bytes: number) {
  if (bytes === 0) return "0 B";
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB", "TB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`;
}

export function R2StorageManager({
  initialFiles,
  isConfigured,
  bucketName,
  publicBaseUrl,
  accountIdMasked,
  connectionError,
}: {
  initialFiles: R2FileItem[];
  isConfigured: boolean;
  bucketName: string | null;
  publicBaseUrl: string | null;
  accountIdMasked: string | null;
  connectionError?: string | null;
}) {
  const [files, setFiles] = useState<R2FileItem[]>(initialFiles);
  const [filter, setFilter] = useState<"all" | "windows" | "mac" | "android">("all");
  const [query, setQuery] = useState("");
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

  // Upload state
  const [isUploading, setIsUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [uploadStatusText, setUploadStatusText] = useState("");
  const [uploadError, setUploadError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  // Delete modal state
  const [deletingFile, setDeletingFile] = useState<R2FileItem | null>(null);
  const [isDeleting, startDeleteTransition] = useTransition();
  const { runWithBusy } = useAdminBusy();

  const filteredFiles = files.filter((f) => {
    if (filter !== "all" && f.category !== filter) return false;
    if (query.trim() && !f.name.toLowerCase().includes(query.toLowerCase())) return false;
    return true;
  });

  const totalSize = files.reduce((acc, f) => acc + f.size, 0);
  const windowsCount = files.filter((f) => f.category === "windows").length;
  const macCount = files.filter((f) => f.category === "mac").length;
  const androidCount = files.filter((f) => f.category === "android").length;

  function copyUrl(url: string, key: string) {
    navigator.clipboard.writeText(url);
    setCopiedKey(key);
    setTimeout(() => setCopiedKey(null), 2500);
  }

  async function handleFileSelect(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;

    setIsUploading(true);
    setUploadProgress(0);
    setUploadError(null);
    setUploadStatusText(`Preparing upload for ${file.name}…`);

    try {
      // 1. Get presigned upload URL from server
      const presignedRes = await requestPresignedUpload(
        file.name,
        file.type || "application/octet-stream",
        "downloads",
      );

      if (!presignedRes.ok || !presignedRes.uploadUrl) {
        throw new Error(presignedRes.message || "Could not generate upload authorization.");
      }

      setUploadStatusText(`Uploading ${file.name} directly to Cloudflare R2…`);

      // 2. Direct upload to Cloudflare R2 using XMLHttpRequest to monitor progress
      await new Promise<void>((resolve, reject) => {
        const xhr = new XMLHttpRequest();
        xhr.open("PUT", presignedRes.uploadUrl!, true);
        xhr.setRequestHeader("Content-Type", file.type || "application/octet-stream");

        xhr.upload.onprogress = (e) => {
          if (e.lengthComputable) {
            const percent = Math.round((e.loaded / e.total) * 100);
            setUploadProgress(percent);
          }
        };

        xhr.onload = () => {
          if (xhr.status >= 200 && xhr.status < 300) {
            resolve();
          } else {
            reject(new Error(`R2 upload rejected with status ${xhr.status} ${xhr.statusText}`));
          }
        };

        xhr.onerror = () => reject(new Error("Network error during upload to Cloudflare R2."));
        xhr.onabort = () => reject(new Error("Upload aborted."));

        xhr.send(file);
      });

      setUploadStatusText("Upload complete! Refreshing storage inventory…");
      const updated = await refreshStorageListing();
      setFiles(updated);
    } catch (err) {
      setUploadError(err instanceof Error ? err.message : "Failed to upload file to R2.");
    } finally {
      setIsUploading(false);
      setUploadProgress(0);
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  }

  function confirmDelete() {
    if (!deletingFile) return;
    const fileToDelete = deletingFile;
    startDeleteTransition(async () => {
      try {
        await runWithBusy(async () => {
          const res = await removeStorageFile(fileToDelete.key);
          if (res.ok) {
            setFiles((prev) => prev.filter((f) => f.key !== fileToDelete.key));
            setDeletingFile(null);
          } else {
            alert(res.message);
          }
        }, `Deleting ${fileToDelete.name} from R2…`);
      } catch (err) {
        alert(err instanceof Error ? err.message : "Deletion failed.");
      }
    });
  }

  return (
    <div className="space-y-7">
      {/* Header and Action */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <span className="text-[11px] font-bold uppercase tracking-[.18em] text-[#057c73]">
            Object Storage
          </span>
          <h1 className="font-serif text-2xl font-bold tracking-tight text-[#111322] sm:text-3xl">
            Cloudflare R2 Files
          </h1>
          <p className="mt-1 text-sm text-[#667085]">
            Maintain and distribute official desktop software installer binaries (.exe, .dmg) and mobile APK packages.
          </p>
        </div>

        {isConfigured ? (
          <div>
            <input
              type="file"
              ref={fileInputRef}
              onChange={handleFileSelect}
              className="hidden"
              accept=".exe,.msi,.dmg,.pkg,.zip,.apk,.aab"
            />
            <button
              type="button"
              disabled={isUploading}
              onClick={() => fileInputRef.current?.click()}
              className="focus-ring inline-flex items-center gap-2 rounded-xl bg-[#057c73] px-4 py-2.5 text-xs font-bold uppercase tracking-wider text-white shadow-sm transition hover:bg-[#04675f] disabled:opacity-60"
            >
              <UploadCloud size={16} />
              Upload Installer File
            </button>
          </div>
        ) : null}
      </div>

      {/* Configuration Status Banner */}
      {!isConfigured ? (
        <div className="surface rounded-2xl border border-amber-200 bg-amber-50/70 p-6 text-amber-900 shadow-sm">
          <div className="flex items-start gap-3.5">
            <div className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-amber-100 text-amber-700">
              <AlertTriangle size={20} />
            </div>
            <div className="space-y-2">
              <h2 className="text-base font-bold text-amber-950">Cloudflare R2 Storage Credentials Required</h2>
              <p className="text-xs leading-relaxed text-amber-800">
                To enable direct file upload and management for Windows (.exe) and Mac (.dmg) releases, configure your Cloudflare R2 credentials in your server environment:
              </p>
              <div className="rounded-xl border border-amber-200 bg-white/80 p-4 font-mono text-xs text-slate-800">
                <p><span className="text-[#057c73]">R2_ACCOUNT_ID</span>=your_cloudflare_account_id</p>
                <p><span className="text-[#057c73]">R2_ACCESS_KEY_ID</span>=your_r2_access_key_id</p>
                <p><span className="text-[#057c73]">R2_SECRET_ACCESS_KEY</span>=your_r2_secret_access_key</p>
                <p><span className="text-[#057c73]">R2_BUCKET_NAME</span>=av-smartbilling-downloads</p>
                <p className="text-slate-400 mt-2"># Public downloads URL (already configured):</p>
                <p><span className="text-[#5b4df5]">NEXT_PUBLIC_DOWNLOADS_BASE_URL</span>=https://pub-51a0e58578b448948e5647729cfd26e7.r2.dev/downloads</p>
              </div>
              <p className="text-[11px] text-amber-700">
                💡 In Cloudflare Dashboard, go to <strong>R2 Object Storage → Manage R2 API Tokens → Create API token</strong> with Object Read &amp; Write permissions.
              </p>
            </div>
          </div>
        </div>
      ) : connectionError ? (
        <div className="surface rounded-2xl border border-rose-200 bg-rose-50/80 p-5 text-rose-950 shadow-sm">
          <div className="flex items-start gap-3.5">
            <div className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-rose-100 text-rose-700">
              <AlertTriangle size={20} />
            </div>
            <div className="space-y-1.5">
              <h2 className="text-sm font-bold text-rose-950">Cloudflare R2 Connection Failed</h2>
              <p className="text-xs text-rose-800 leading-relaxed">{connectionError}</p>
              <p className="text-[11px] text-rose-700 pt-1">
                Make sure the bucket name is spelled exactly as shown in your Cloudflare dashboard (e.g. <code className="rounded bg-rose-100/70 px-1 py-0.5 font-mono">av-smartbilling</code>) and the account ID is 32 hexadecimal characters.
              </p>
            </div>
          </div>
        </div>
      ) : (
        <div className="surface flex flex-wrap items-center justify-between gap-4 rounded-xl border border-[#eaecf0] bg-white px-5 py-3 text-xs text-[#475467]">
          <div className="flex flex-wrap items-center gap-6">
            <span className="inline-flex items-center gap-1.5 font-semibold text-emerald-700">
              <CheckCircle2 size={15} className="text-emerald-500" />
              Connected to Cloudflare R2
            </span>
            <span>
              <strong>Bucket:</strong> <code className="rounded bg-slate-100 px-1 py-0.5 text-slate-800">{bucketName}</code>
            </span>
            <span>
              <strong>Account:</strong> <code className="rounded bg-slate-100 px-1 py-0.5 text-slate-800">{accountIdMasked}</code>
            </span>
          </div>
          <div className="flex items-center gap-1.5 truncate text-[11px] text-[#667085]">
            <span>Public CDN:</span>
            <a
              href={publicBaseUrl || "#"}
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center gap-1 font-mono text-[#057c73] hover:underline"
            >
              {publicBaseUrl}
              <ExternalLink size={11} />
            </a>
          </div>
        </div>
      )}

      {/* KPI Cards */}
      <div className="grid gap-4 sm:grid-cols-4">
        <div className="surface p-5">
          <div className="flex items-center justify-between text-[#667085]">
            <span className="text-xs font-semibold uppercase tracking-wider">Total Hosted Files</span>
            <span className="grid size-8 place-items-center rounded-lg bg-teal-50 text-[#057c73]">
              <HardDrive size={16} />
            </span>
          </div>
          <strong className="mt-2 block text-2xl font-bold text-[#101828]">{files.length}</strong>
          <span className="text-[11px] text-[#667085]">Total volume: {formatBytes(totalSize)}</span>
        </div>

        <div className="surface p-5">
          <div className="flex items-center justify-between text-[#667085]">
            <span className="text-xs font-semibold uppercase tracking-wider">Windows Installers</span>
            <span className="grid size-8 place-items-center rounded-lg bg-blue-50 text-blue-600">
              <FileCode size={16} />
            </span>
          </div>
          <strong className="mt-2 block text-2xl font-bold text-blue-600">{windowsCount}</strong>
          <span className="text-[11px] text-[#667085]">.exe &amp; .msi binaries</span>
        </div>

        <div className="surface p-5">
          <div className="flex items-center justify-between text-[#667085]">
            <span className="text-xs font-semibold uppercase tracking-wider">macOS Installers</span>
            <span className="grid size-8 place-items-center rounded-lg bg-indigo-50 text-indigo-600">
              <FileCode size={16} />
            </span>
          </div>
          <strong className="mt-2 block text-2xl font-bold text-indigo-600">{macCount}</strong>
          <span className="text-[11px] text-[#667085]">.dmg &amp; .pkg binaries</span>
        </div>

        <div className="surface p-5">
          <div className="flex items-center justify-between text-[#667085]">
            <span className="text-xs font-semibold uppercase tracking-wider">Mobile APK Packages</span>
            <span className="grid size-8 place-items-center rounded-lg bg-emerald-50 text-emerald-600">
              <FileCode size={16} />
            </span>
          </div>
          <strong className="mt-2 block text-2xl font-bold text-emerald-600">{androidCount}</strong>
          <span className="text-[11px] text-[#667085]">Android distribution</span>
        </div>
      </div>

      {/* Upload Progress Bar if active */}
      {isUploading ? (
        <div className="surface rounded-2xl border border-teal-200 bg-teal-50/50 p-5 shadow-sm animate-in fade-in duration-150">
          <div className="flex items-center justify-between text-xs font-bold text-[#057c73]">
            <span className="inline-flex items-center gap-2">
              <Loader2 size={16} className="animate-spin text-[#057c73]" />
              {uploadStatusText}
            </span>
            <span>{uploadProgress}%</span>
          </div>
          <div className="mt-3 h-2 w-full overflow-hidden rounded-full bg-teal-100">
            <div
              className="h-full bg-gradient-to-r from-[#057c73] to-[#38d4c7] transition-all duration-200"
              style={{ width: `${uploadProgress}%` }}
            />
          </div>
        </div>
      ) : null}

      {uploadError ? (
        <div className="surface rounded-2xl border border-rose-200 bg-rose-50 p-4 text-xs font-semibold text-rose-800">
          ❌ {uploadError}
        </div>
      ) : null}

      {/* Inventory Filters & Search */}
      <div className="surface overflow-hidden rounded-2xl border border-[#eaecf0] shadow-sm">
        <div className="flex flex-col gap-3 border-b border-[#eaecf0] bg-[#fafbfc] p-4 sm:flex-row sm:items-center sm:justify-between">
          {/* Category Tabs */}
          <div className="flex items-center gap-1">
            <button
              type="button"
              onClick={() => setFilter("all")}
              className={`rounded-lg px-3 py-1.5 text-xs font-bold transition ${
                filter === "all"
                  ? "bg-[#171b36] text-white"
                  : "text-[#667085] hover:bg-slate-200 hover:text-[#101828]"
              }`}
            >
              All ({files.length})
            </button>
            <button
              type="button"
              onClick={() => setFilter("windows")}
              className={`rounded-lg px-3 py-1.5 text-xs font-bold transition ${
                filter === "windows"
                  ? "bg-blue-600 text-white"
                  : "text-[#667085] hover:bg-slate-200 hover:text-[#101828]"
              }`}
            >
              Windows ({windowsCount})
            </button>
            <button
              type="button"
              onClick={() => setFilter("mac")}
              className={`rounded-lg px-3 py-1.5 text-xs font-bold transition ${
                filter === "mac"
                  ? "bg-indigo-600 text-white"
                  : "text-[#667085] hover:bg-slate-200 hover:text-[#101828]"
              }`}
            >
              macOS ({macCount})
            </button>
            <button
              type="button"
              onClick={() => setFilter("android")}
              className={`rounded-lg px-3 py-1.5 text-xs font-bold transition ${
                filter === "android"
                  ? "bg-emerald-600 text-white"
                  : "text-[#667085] hover:bg-slate-200 hover:text-[#101828]"
              }`}
            >
              Android ({androidCount})
            </button>
          </div>

          {/* Search box */}
          <div className="relative w-full sm:w-64">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#98a2b3]" />
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Filter file name…"
              className="focus-ring h-9 w-full rounded-xl border border-[#dfe3eb] bg-white pl-8 pr-3 text-xs text-[#101828]"
            />
          </div>
        </div>

        {/* Files Table */}
        <div className="overflow-x-auto">
          <table className="w-full min-w-[900px] text-left text-sm">
            <thead className="bg-[#f8f9fc] text-[11px] font-bold uppercase tracking-wider text-[#667085]">
              <tr>
                <th className="px-6 py-3.5">File Name &amp; Key</th>
                <th className="px-6 py-3.5">Platform</th>
                <th className="px-6 py-3.5">Size</th>
                <th className="px-6 py-3.5">Last Modified</th>
                <th className="px-6 py-3.5 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#eaecf0]">
              {filteredFiles.map((file) => {
                const isCopied = copiedKey === file.key;
                return (
                  <tr key={file.key} className="transition hover:bg-[#fafbff]">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <span
                          className={`grid size-9 shrink-0 place-items-center rounded-xl font-bold ${
                            file.category === "windows"
                              ? "bg-blue-50 text-blue-600"
                              : file.category === "mac"
                              ? "bg-indigo-50 text-indigo-600"
                              : file.category === "android"
                              ? "bg-emerald-50 text-emerald-600"
                              : "bg-slate-100 text-slate-600"
                          }`}
                        >
                          <FileCode size={18} />
                        </span>
                        <div className="min-w-0">
                          <p className="truncate font-semibold text-[#101828]">{file.name}</p>
                          <p className="font-mono text-[11px] text-[#667085]">{file.key}</p>
                        </div>
                      </div>
                    </td>

                    <td className="px-6 py-4">
                      <span
                        className={`inline-flex items-center rounded-md px-2 py-0.5 text-xs font-bold uppercase tracking-wider ${
                          file.category === "windows"
                            ? "bg-blue-50 text-blue-700"
                            : file.category === "mac"
                            ? "bg-indigo-50 text-indigo-700"
                            : file.category === "android"
                            ? "bg-emerald-50 text-emerald-700"
                            : "bg-slate-100 text-slate-700"
                        }`}
                      >
                        {file.category}
                      </span>
                    </td>

                    <td className="px-6 py-4 font-mono text-xs font-semibold text-[#344054]">
                      {formatBytes(file.size)}
                    </td>

                    <td className="px-6 py-4 text-xs text-[#667085]">
                      {new Date(file.lastModified).toLocaleDateString("en-IN", {
                        day: "2-digit",
                        month: "short",
                        year: "numeric",
                        hour: "2-digit",
                        minute: "2-digit",
                      })}
                    </td>

                    <td className="px-6 py-4 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        {/* Copy Link Button */}
                        <button
                          type="button"
                          onClick={() => copyUrl(file.publicUrl, file.key)}
                          title="Copy public download link"
                          className="focus-ring inline-flex items-center gap-1.5 rounded-lg border border-[#dfe3eb] bg-white px-2.5 py-1.5 text-xs font-semibold text-[#344054] transition hover:bg-[#f8f9fc]"
                        >
                          {isCopied ? (
                            <>
                              <Check size={13} className="text-emerald-600" />
                              <span className="text-emerald-700">Copied!</span>
                            </>
                          ) : (
                            <>
                              <Copy size={13} />
                              <span>Copy URL</span>
                            </>
                          )}
                        </button>

                        {/* Direct Download Button */}
                        <a
                          href={file.publicUrl}
                          download={file.name}
                          target="_blank"
                          rel="noreferrer"
                          title="Download file"
                          className="focus-ring rounded-lg border border-[#dfe3eb] bg-white p-1.5 text-[#475467] transition hover:bg-[#f8f9fc] hover:text-[#101828]"
                        >
                          <Download size={14} />
                        </a>

                        {/* Delete Button */}
                        <button
                          type="button"
                          onClick={() => setDeletingFile(file)}
                          title="Delete file from R2"
                          className="focus-ring rounded-lg border border-rose-200 p-1.5 text-rose-600 transition hover:bg-rose-50 hover:border-rose-300"
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        {!filteredFiles.length ? (
          <div className="p-12 text-center text-sm text-[#667085]">
            <FolderOpen className="mx-auto mb-3 size-10 text-[#d0d5dd]" />
            <p className="font-semibold text-[#344054]">No files found matching criteria.</p>
            <p className="mt-1 text-xs">
              {files.length === 0
                ? "Click \"Upload Installer File\" above to upload your first Windows (.exe) or Mac (.dmg) installer."
                : "Try adjusting your search filter."}
            </p>
          </div>
        ) : null}
      </div>

      {/* Delete Confirmation Modal */}
      {deletingFile ? (
        <div
          role="dialog"
          aria-modal="true"
          className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm animate-in fade-in duration-150"
        >
          <div className="surface w-full max-w-md overflow-hidden rounded-2xl border border-[#eaecf0] bg-white p-6 shadow-2xl">
            <div className="flex items-start gap-4">
              <div className="flex size-11 shrink-0 items-center justify-center rounded-xl bg-rose-50 text-rose-600">
                <AlertTriangle size={22} />
              </div>
              <div className="flex-1">
                <h3 className="text-base font-bold text-[#101828]">Delete R2 Installer File</h3>
                <p className="mt-1.5 text-xs leading-relaxed text-[#667085]">
                  Are you sure you want to permanently delete{" "}
                  <strong className="text-[#344054] font-mono break-all">{deletingFile.name}</strong> from Cloudflare R2?
                </p>
                <div className="mt-3 rounded-xl bg-amber-50 p-3 text-xs text-amber-800 border border-amber-200">
                  ⚠️ Existing users or download links targeting this file will receive a 404 Not Found error once deleted.
                </div>
              </div>
            </div>

            <div className="mt-6 flex justify-end gap-3 border-t border-[#f2f4f7] pt-4">
              <button
                type="button"
                disabled={isDeleting}
                onClick={() => setDeletingFile(null)}
                className="focus-ring rounded-xl border border-[#d0d5dd] px-4 py-2.5 text-xs font-semibold text-[#344054] transition hover:bg-[#f9fafb]"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={isDeleting}
                onClick={confirmDelete}
                className="focus-ring inline-flex items-center gap-2 rounded-xl bg-rose-600 px-4 py-2.5 text-xs font-bold uppercase tracking-wider text-white shadow-sm transition hover:bg-rose-700 disabled:opacity-60"
              >
                {isDeleting ? (
                  <>
                    <Loader2 size={14} className="animate-spin" />
                    Deleting…
                  </>
                ) : (
                  "Yes, Delete from R2"
                )}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
