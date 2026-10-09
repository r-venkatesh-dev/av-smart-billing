"use client";

import { useState, useTransition } from "react";
import { Trash2, AlertTriangle, Loader2, CalendarPlus } from "lucide-react";
import { deleteLicense } from "@/app/admin/actions";
import { useAdminBusy } from "@/components/admin-busy-overlay";
import { RenewLicenseDialog } from "@/components/renew-license-dialog";

export function LicenseRowActions({
  licenseId,
  licenseKey,
  customerName,
}: {
  licenseId: string;
  licenseKey: string;
  customerName: string;
}) {
  const [showConfirm, setShowConfirm] = useState(false);
  const [showRenew, setShowRenew] = useState(false);
  const [isPending, startTransition] = useTransition();
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const { runWithBusy } = useAdminBusy();

  function handleDelete() {
    startTransition(async () => {
      try {
        setErrorMessage(null);
        await runWithBusy(async () => {
          const res = await deleteLicense(licenseId);
          if (!res.ok) {
            setErrorMessage(res.message);
          } else {
            setShowConfirm(false);
          }
        }, `Deleting license ${licenseKey}…`);
      } catch (err) {
        setErrorMessage(err instanceof Error ? err.message : "Failed to delete license.");
      }
    });
  }

  return (
    <>
      <div className="flex items-center gap-1">
        <button
          type="button"
          onClick={() => setShowRenew(true)}
          title={`Renew / Extend license ${licenseKey}`}
          className="focus-ring rounded-lg p-1.5 text-[#057c73] transition hover:bg-[#e6f4f2] hover:text-[#04675f]"
        >
          <CalendarPlus size={16} />
        </button>
        <button
          type="button"
          onClick={() => {
            setErrorMessage(null);
            setShowConfirm(true);
          }}
          title={`Delete license ${licenseKey}`}
          className="focus-ring rounded-lg p-1.5 text-[#98a2b3] transition hover:bg-rose-50 hover:text-rose-600"
        >
          <Trash2 size={16} />
        </button>
      </div>

      <RenewLicenseDialog
        licenseId={licenseId}
        licenseKey={licenseKey}
        customerName={customerName}
        isOpen={showRenew}
        onClose={() => setShowRenew(false)}
      />

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
                <h3 className="text-base font-bold text-[#101828]">Delete License</h3>
                <p className="mt-1.5 text-xs leading-relaxed text-[#667085]">
                  Are you sure you want to permanently delete license{" "}
                  <strong className="font-mono text-[#344054]">{licenseKey}</strong> for{" "}
                  <strong className="text-[#344054]">{customerName}</strong>?
                </p>
                <div className="mt-3 rounded-xl bg-amber-50 p-3 text-xs text-amber-800 border border-amber-200">
                  ⚠️ This action cannot be undone. Active devices using this license key will be disconnected immediately.
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
                  "Yes, Delete License"
                )}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}
