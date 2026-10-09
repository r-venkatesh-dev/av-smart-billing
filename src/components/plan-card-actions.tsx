"use client";

import { useState, useTransition } from "react";
import Link from "next/link";
import { Trash2, AlertTriangle, Loader2 } from "lucide-react";
import { deletePlan } from "@/app/admin/actions";
import { useAdminBusy } from "@/components/admin-busy-overlay";

export function PlanCardActions({
  planId,
  planName,
}: {
  planId: string;
  planName: string;
}) {
  const [showConfirm, setShowConfirm] = useState(false);
  const [isPending, startTransition] = useTransition();
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const { runWithBusy } = useAdminBusy();

  function handleDelete() {
    startTransition(async () => {
      try {
        setErrorMessage(null);
        await runWithBusy(async () => {
          const res = await deletePlan(planId);
          if (!res.ok) {
            setErrorMessage(res.message);
          } else {
            setShowConfirm(false);
          }
        }, `Deleting plan "${planName}"…`);
      } catch (err) {
        setErrorMessage(err instanceof Error ? err.message : "Failed to delete plan.");
      }
    });
  }

  return (
    <div className="mt-7 flex items-center gap-2">
      <Link
        href={`/admin/plans/${planId}/edit`}
        className="focus-ring flex-1 rounded-xl border border-[#dfe3eb] py-2.5 text-center text-sm font-semibold text-[#475467] transition hover:bg-[#f8f9fc]"
      >
        Edit plan
      </Link>
      <button
        type="button"
        onClick={() => {
          setErrorMessage(null);
          setShowConfirm(true);
        }}
        title={`Delete plan ${planName}`}
        className="focus-ring rounded-xl border border-rose-200 p-2.5 text-rose-600 transition hover:bg-rose-50 hover:border-rose-300"
      >
        <Trash2 size={18} />
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
                <h3 className="text-base font-bold text-[#101828]">Delete Plan</h3>
                <p className="mt-1.5 text-xs leading-relaxed text-[#667085]">
                  Are you sure you want to delete the plan{" "}
                  <strong className="text-[#344054]">&ldquo;{planName}&rdquo;</strong>?
                </p>
                <div className="mt-3 rounded-xl bg-slate-50 p-3 text-xs text-[#475467] border border-[#e4e7ec]">
                  ℹ️ If any existing licenses are using this plan, it will be safely retired and hidden from public purchases to ensure active customers are not disrupted.
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
                  "Yes, Delete Plan"
                )}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
