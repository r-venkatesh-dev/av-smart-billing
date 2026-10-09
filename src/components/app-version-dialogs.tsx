"use client";

import { useState, useTransition } from "react";
import {
  Plus,
  Pencil,
  Trash2,
  AlertTriangle,
  Loader2,
  Smartphone,
  CheckCircle2,
  XCircle,
} from "lucide-react";
import {
  createAppVersion,
  updateAppVersion,
  deleteAppVersion,
  toggleAppVersionActive,
} from "@/app/admin/version-actions";
import { useAdminBusy } from "@/components/admin-busy-overlay";

export interface AppVersionItem {
  id: string;
  platform: "android" | "ios";
  latestVersion: string;
  latestBuildNumber: number;
  minRequiredBuild: number;
  releaseNotes: string;
  updateUrl: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export function CreateVersionButton() {
  const [open, setOpen] = useState(false);
  const [isPending, startTransition] = useTransition();
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const { runWithBusy } = useAdminBusy();

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    startTransition(async () => {
      try {
        setErrorMessage(null);
        await runWithBusy(async () => {
          const res = await createAppVersion(formData);
          if (!res.ok) {
            setErrorMessage(res.message);
          } else {
            setOpen(false);
          }
        }, "Registering new mobile app version…");
      } catch (err) {
        setErrorMessage(err instanceof Error ? err.message : "Failed to create app version.");
      }
    });
  }

  return (
    <>
      <button
        type="button"
        onClick={() => {
          setErrorMessage(null);
          setOpen(true);
        }}
        className="focus-ring inline-flex items-center gap-2 rounded-xl bg-[#057c73] px-4 py-2.5 text-xs font-bold uppercase tracking-wider text-white shadow-sm transition hover:bg-[#04675f]"
      >
        <Plus size={16} />
        New App Version
      </button>

      {open ? (
        <div
          role="dialog"
          aria-modal="true"
          className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm animate-in fade-in duration-150"
        >
          <div className="surface w-full max-w-lg overflow-hidden rounded-2xl border border-[#eaecf0] bg-white p-6 shadow-2xl">
            <div className="flex items-center justify-between border-b border-[#f2f4f7] pb-4">
              <div className="flex items-center gap-2.5">
                <div className="flex size-9 items-center justify-center rounded-xl bg-teal-50 text-[#057c73]">
                  <Smartphone size={18} />
                </div>
                <div>
                  <h3 className="text-base font-bold text-[#101828]">New App Version</h3>
                  <p className="text-xs text-[#667085]">Publish or prepare an update for the mobile app</p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setOpen(false)}
                className="rounded-lg p-1 text-[#98a2b3] hover:bg-[#f2f4f7] hover:text-[#344054]"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleSubmit} className="mt-5 space-y-4">
              {errorMessage ? (
                <div className="rounded-xl bg-rose-50 p-3 text-xs font-semibold text-rose-700">
                  {errorMessage}
                </div>
              ) : null}

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="mb-1 block text-xs font-bold uppercase text-[#475467]">
                    Platform
                  </label>
                  <select
                    name="platform"
                    defaultValue="android"
                    className="focus-ring h-10 w-full rounded-xl border border-[#dfe3eb] bg-white px-3 text-sm text-[#101828]"
                  >
                    <option value="android">Android (Google Play)</option>
                    <option value="ios">iOS (App Store)</option>
                  </select>
                </div>

                <div>
                  <label className="mb-1 block text-xs font-bold uppercase text-[#475467]">
                    Version Name
                  </label>
                  <input
                    type="text"
                    name="latestVersion"
                    required
                    placeholder="e.g. 1.0.1"
                    className="focus-ring h-10 w-full rounded-xl border border-[#dfe3eb] bg-white px-3 text-sm text-[#101828]"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="mb-1 block text-xs font-bold uppercase text-[#475467]">
                    Latest Build #
                  </label>
                  <input
                    type="number"
                    name="latestBuildNumber"
                    required
                    min={1}
                    placeholder="e.g. 7"
                    className="focus-ring h-10 w-full rounded-xl border border-[#dfe3eb] bg-white px-3 text-sm text-[#101828]"
                  />
                  <p className="mt-1 text-[11px] text-[#667085]">Increment per release</p>
                </div>

                <div>
                  <label className="mb-1 block text-xs font-bold uppercase text-[#475467]">
                    Min Required Build #
                  </label>
                  <input
                    type="number"
                    name="minRequiredBuild"
                    required
                    min={1}
                    defaultValue={1}
                    className="focus-ring h-10 w-full rounded-xl border border-[#dfe3eb] bg-white px-3 text-sm text-[#101828]"
                  />
                  <p className="mt-1 text-[11px] text-[#667085]">Builds below this are forced to update</p>
                </div>
              </div>

              <div>
                <label className="mb-1 block text-xs font-bold uppercase text-[#475467]">
                  Update / Store URL
                </label>
                <input
                  type="url"
                  name="updateUrl"
                  required
                  defaultValue="https://play.google.com/store/apps/details?id=in.avsmartbilling.mobile"
                  className="focus-ring h-10 w-full rounded-xl border border-[#dfe3eb] bg-white px-3 text-sm text-[#101828]"
                />
              </div>

              <div>
                <label className="mb-1 block text-xs font-bold uppercase text-[#475467]">
                  Release Notes
                </label>
                <textarea
                  name="releaseNotes"
                  rows={3}
                  placeholder="What's new in this version (e.g. Added cloud restore, performance improvements, bug fixes)…"
                  className="focus-ring w-full rounded-xl border border-[#dfe3eb] bg-white p-3 text-sm text-[#101828]"
                />
              </div>

              <div className="flex items-center gap-2 pt-1">
                <input
                  type="checkbox"
                  id="create-isActive"
                  name="isActive"
                  defaultChecked
                  className="size-4 rounded border-[#dfe3eb] text-[#057c73] focus:ring-[#057c73]"
                />
                <label htmlFor="create-isActive" className="text-xs font-semibold text-[#344054] cursor-pointer">
                  Activate this release immediately (mobile apps checking for updates will see this version)
                </label>
              </div>

              <div className="flex justify-end gap-3 border-t border-[#f2f4f7] pt-4">
                <button
                  type="button"
                  disabled={isPending}
                  onClick={() => setOpen(false)}
                  className="focus-ring rounded-xl border border-[#d0d5dd] px-4 py-2.5 text-xs font-semibold text-[#344054] transition hover:bg-[#f9fafb]"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isPending}
                  className="focus-ring inline-flex items-center gap-2 rounded-xl bg-[#057c73] px-5 py-2.5 text-xs font-bold uppercase tracking-wider text-white shadow-sm transition hover:bg-[#04675f] disabled:opacity-60"
                >
                  {isPending ? (
                    <>
                      <Loader2 size={14} className="animate-spin" />
                      Creating…
                    </>
                  ) : (
                    "Create Version"
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </>
  );
}

export function EditVersionButton({ item }: { item: AppVersionItem }) {
  const [open, setOpen] = useState(false);
  const [isPending, startTransition] = useTransition();
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const { runWithBusy } = useAdminBusy();

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    startTransition(async () => {
      try {
        setErrorMessage(null);
        await runWithBusy(async () => {
          const res = await updateAppVersion(item.id, formData);
          if (!res.ok) {
            setErrorMessage(res.message);
          } else {
            setOpen(false);
          }
        }, `Updating ${item.platform} version ${item.latestVersion}…`);
      } catch (err) {
        setErrorMessage(err instanceof Error ? err.message : "Failed to update app version.");
      }
    });
  }

  return (
    <>
      <button
        type="button"
        onClick={() => {
          setErrorMessage(null);
          setOpen(true);
        }}
        title="Edit version"
        className="focus-ring rounded-lg p-1.5 text-[#667085] transition hover:bg-slate-100 hover:text-[#101828]"
      >
        <Pencil size={15} />
      </button>

      {open ? (
        <div
          role="dialog"
          aria-modal="true"
          className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm animate-in fade-in duration-150"
        >
          <div className="surface w-full max-w-lg overflow-hidden rounded-2xl border border-[#eaecf0] bg-white p-6 shadow-2xl">
            <div className="flex items-center justify-between border-b border-[#f2f4f7] pb-4">
              <div className="flex items-center gap-2.5">
                <div className="flex size-9 items-center justify-center rounded-xl bg-indigo-50 text-indigo-600">
                  <Pencil size={18} />
                </div>
                <div>
                  <h3 className="text-base font-bold text-[#101828]">Edit App Version</h3>
                  <p className="text-xs text-[#667085]">{item.platform.toUpperCase()} — {item.latestVersion} (Build {item.latestBuildNumber})</p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setOpen(false)}
                className="rounded-lg p-1 text-[#98a2b3] hover:bg-[#f2f4f7] hover:text-[#344054]"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleSubmit} className="mt-5 space-y-4">
              {errorMessage ? (
                <div className="rounded-xl bg-rose-50 p-3 text-xs font-semibold text-rose-700">
                  {errorMessage}
                </div>
              ) : null}

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="mb-1 block text-xs font-bold uppercase text-[#475467]">
                    Platform
                  </label>
                  <select
                    name="platform"
                    defaultValue={item.platform}
                    className="focus-ring h-10 w-full rounded-xl border border-[#dfe3eb] bg-white px-3 text-sm text-[#101828]"
                  >
                    <option value="android">Android (Google Play)</option>
                    <option value="ios">iOS (App Store)</option>
                  </select>
                </div>

                <div>
                  <label className="mb-1 block text-xs font-bold uppercase text-[#475467]">
                    Version Name
                  </label>
                  <input
                    type="text"
                    name="latestVersion"
                    required
                    defaultValue={item.latestVersion}
                    className="focus-ring h-10 w-full rounded-xl border border-[#dfe3eb] bg-white px-3 text-sm text-[#101828]"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="mb-1 block text-xs font-bold uppercase text-[#475467]">
                    Latest Build #
                  </label>
                  <input
                    type="number"
                    name="latestBuildNumber"
                    required
                    min={1}
                    defaultValue={item.latestBuildNumber}
                    className="focus-ring h-10 w-full rounded-xl border border-[#dfe3eb] bg-white px-3 text-sm text-[#101828]"
                  />
                </div>

                <div>
                  <label className="mb-1 block text-xs font-bold uppercase text-[#475467]">
                    Min Required Build #
                  </label>
                  <input
                    type="number"
                    name="minRequiredBuild"
                    required
                    min={1}
                    defaultValue={item.minRequiredBuild}
                    className="focus-ring h-10 w-full rounded-xl border border-[#dfe3eb] bg-white px-3 text-sm text-[#101828]"
                  />
                </div>
              </div>

              <div>
                <label className="mb-1 block text-xs font-bold uppercase text-[#475467]">
                  Update / Store URL
                </label>
                <input
                  type="url"
                  name="updateUrl"
                  required
                  defaultValue={item.updateUrl}
                  className="focus-ring h-10 w-full rounded-xl border border-[#dfe3eb] bg-white px-3 text-sm text-[#101828]"
                />
              </div>

              <div>
                <label className="mb-1 block text-xs font-bold uppercase text-[#475467]">
                  Release Notes
                </label>
                <textarea
                  name="releaseNotes"
                  rows={3}
                  defaultValue={item.releaseNotes}
                  className="focus-ring w-full rounded-xl border border-[#dfe3eb] bg-white p-3 text-sm text-[#101828]"
                />
              </div>

              <div className="flex items-center gap-2 pt-1">
                <input
                  type="checkbox"
                  id={`edit-isActive-${item.id}`}
                  name="isActive"
                  defaultChecked={item.isActive}
                  className="size-4 rounded border-[#dfe3eb] text-[#057c73] focus:ring-[#057c73]"
                />
                <label htmlFor={`edit-isActive-${item.id}`} className="text-xs font-semibold text-[#344054] cursor-pointer">
                  Active (served as the official update to app clients)
                </label>
              </div>

              <div className="flex justify-end gap-3 border-t border-[#f2f4f7] pt-4">
                <button
                  type="button"
                  disabled={isPending}
                  onClick={() => setOpen(false)}
                  className="focus-ring rounded-xl border border-[#d0d5dd] px-4 py-2.5 text-xs font-semibold text-[#344054] transition hover:bg-[#f9fafb]"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isPending}
                  className="focus-ring inline-flex items-center gap-2 rounded-xl bg-[#5b4df5] px-5 py-2.5 text-xs font-bold uppercase tracking-wider text-white shadow-sm transition hover:bg-[#4b3de5] disabled:opacity-60"
                >
                  {isPending ? (
                    <>
                      <Loader2 size={14} className="animate-spin" />
                      Saving…
                    </>
                  ) : (
                    "Save Changes"
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </>
  );
}

export function DeleteVersionButton({ item }: { item: AppVersionItem }) {
  const [showConfirm, setShowConfirm] = useState(false);
  const [isPending, startTransition] = useTransition();
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const { runWithBusy } = useAdminBusy();

  function handleDelete() {
    startTransition(async () => {
      try {
        setErrorMessage(null);
        await runWithBusy(async () => {
          const res = await deleteAppVersion(item.id);
          if (!res.ok) {
            setErrorMessage(res.message);
          } else {
            setShowConfirm(false);
          }
        }, `Deleting ${item.platform} version ${item.latestVersion}…`);
      } catch (err) {
        setErrorMessage(err instanceof Error ? err.message : "Failed to delete version.");
      }
    });
  }

  return (
    <>
      <button
        type="button"
        onClick={() => {
          setErrorMessage(null);
          setShowConfirm(true);
        }}
        title={`Delete version ${item.latestVersion}`}
        className="focus-ring rounded-lg p-1.5 text-[#98a2b3] transition hover:bg-rose-50 hover:text-rose-600"
      >
        <Trash2 size={15} />
      </button>

      {showConfirm ? (
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
                <h3 className="text-base font-bold text-[#101828]">Delete App Version</h3>
                <p className="mt-1.5 text-xs leading-relaxed text-[#667085]">
                  Are you sure you want to delete{" "}
                  <strong className="text-[#344054] capitalize">{item.platform}</strong> version{" "}
                  <strong className="text-[#344054]">{item.latestVersion}</strong> (Build {item.latestBuildNumber})?
                </p>
                <div className="mt-3 rounded-xl bg-amber-50 p-3 text-xs text-amber-800 border border-amber-200">
                  ⚠️ This removes this release entry from the database. Mobile devices will fall back to other active versions or defaults.
                </div>
                {errorMessage ? (
                  <p className="mt-3 rounded-lg bg-rose-50 p-2.5 text-xs font-semibold text-rose-700">
                    {errorMessage}
                  </p>
                ) : null}
              </div>
            </div>

            <div className="mt-6 flex justify-end gap-3 border-t border-[#f2f4f7] pt-4">
              <button
                type="button"
                disabled={isPending}
                onClick={() => setShowConfirm(false)}
                className="focus-ring rounded-xl border border-[#d0d5dd] px-4 py-2.5 text-xs font-semibold text-[#344054] transition hover:bg-[#f9fafb]"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={isPending}
                onClick={handleDelete}
                className="focus-ring inline-flex items-center gap-2 rounded-xl bg-rose-600 px-4 py-2.5 text-xs font-bold uppercase tracking-wider text-white shadow-sm transition hover:bg-rose-700 disabled:opacity-60"
              >
                {isPending ? (
                  <>
                    <Loader2 size={14} className="animate-spin" />
                    Deleting…
                  </>
                ) : (
                  "Yes, Delete Version"
                )}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}

export function ToggleActiveButton({ item }: { item: AppVersionItem }) {
  const [isPending, startTransition] = useTransition();
  const { runWithBusy } = useAdminBusy();

  function handleToggle() {
    startTransition(async () => {
      await runWithBusy(
        async () => toggleAppVersionActive(item.id, !item.isActive),
        `${item.isActive ? "Deactivating" : "Activating"} version ${item.latestVersion}…`,
      );
    });
  }

  return (
    <button
      type="button"
      disabled={isPending}
      onClick={handleToggle}
      className={`focus-ring inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-bold transition ${
        item.isActive
          ? "bg-emerald-50 text-emerald-700 hover:bg-emerald-100"
          : "bg-slate-100 text-slate-500 hover:bg-slate-200"
      }`}
    >
      {item.isActive ? (
        <>
          <CheckCircle2 size={12} className="text-emerald-600" />
          Active
        </>
      ) : (
        <>
          <XCircle size={12} className="text-slate-400" />
          Inactive
        </>
      )}
    </button>
  );
}
