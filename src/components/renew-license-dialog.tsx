"use client";

import { useState, useTransition } from "react";
import { CalendarPlus, X, Check, AlertTriangle } from "lucide-react";
import { renewAdminLicense } from "@/app/admin/actions";
import { useAdminBusy } from "@/components/admin-busy-overlay";

export function RenewLicenseDialog({
  licenseId,
  licenseKey,
  customerName,
  isOpen,
  onClose,
}: {
  licenseId: string;
  licenseKey: string;
  customerName: string;
  isOpen: boolean;
  onClose: () => void;
}) {
  const [duration, setDuration] = useState<number>(12); // months: 1, 3, 6, 12, 0 (custom)
  const [customDate, setCustomDate] = useState("");
  const [isPending, startTransition] = useTransition();
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const { runWithBusy } = useAdminBusy();

  if (!isOpen) return null;

  function handleRenew() {
    startTransition(async () => {
      try {
        setErrorMessage(null);
        setSuccessMessage(null);
        await runWithBusy(async () => {
          const res = await renewAdminLicense(
            licenseId,
            duration,
            duration === 0 ? customDate : undefined
          );
          if (!res.ok) {
            setErrorMessage(res.message);
          } else {
            setSuccessMessage(res.message);
            setTimeout(() => {
              onClose();
            }, 1200);
          }
        }, `Renewing license ${licenseKey}…`);
      } catch (err) {
        setErrorMessage(err instanceof Error ? err.message : "Failed to renew license.");
      }
    });
  }

  return (
    <div
      role="dialog"
      aria-modal="true"
      className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm animate-in fade-in duration-150"
    >
      <div className="surface w-full max-w-md overflow-hidden rounded-2xl border border-[#eaecf0] bg-white p-6 shadow-2xl">
        <div className="flex items-center justify-between border-b border-[#eaecf0] pb-4">
          <div className="flex items-center gap-3">
            <div className="flex size-10 items-center justify-center rounded-xl bg-[#e6f4f2] text-[#057c73]">
              <CalendarPlus size={20} />
            </div>
            <div>
              <h3 className="font-serif text-lg font-bold text-[#111322]">Renew License</h3>
              <p className="text-xs text-[#667085]">{customerName} &bull; <code className="font-mono text-slate-700">{licenseKey}</code></p>
            </div>
          </div>
          <button
            type="button"
            disabled={isPending}
            onClick={onClose}
            className="rounded-lg p-1.5 text-[#98a2b3] transition hover:bg-slate-100"
          >
            <X size={18} />
          </button>
        </div>

        <div className="mt-5 space-y-4">
          <p className="text-xs text-[#475467]">
            Select the extension duration. If the license is active, the period is added to the current expiry date; if expired, it extends from today.
          </p>

          <div className="grid grid-cols-2 gap-2.5">
            {[
              { label: "1 Month (30 Days)", months: 1 },
              { label: "3 Months (Quarterly)", months: 3 },
              { label: "6 Months (Half-Year)", months: 6 },
              { label: "1 Year (Annual)", months: 12, recommended: true },
            ].map((option) => (
              <button
                key={option.months}
                type="button"
                onClick={() => setDuration(option.months)}
                className={`relative flex flex-col items-start rounded-xl border p-3 text-left transition ${
                  duration === option.months
                    ? "border-[#057c73] bg-[#057c73]/5 text-[#057c73] ring-1 ring-[#057c73]"
                    : "border-[#e2e8f0] bg-white text-[#334155] hover:bg-slate-50"
                }`}
              >
                {option.recommended ? (
                  <span className="mb-1 rounded bg-[#057c73] px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wider text-white">
                    Standard
                  </span>
                ) : null}
                <span className="text-xs font-bold">{option.label}</span>
              </button>
            ))}
          </div>

          <div className="pt-1">
            <button
              type="button"
              onClick={() => setDuration(0)}
              className={`w-full rounded-xl border p-3 text-left text-xs font-semibold transition ${
                duration === 0
                  ? "border-[#057c73] bg-[#057c73]/5 text-[#057c73] ring-1 ring-[#057c73]"
                  : "border-[#e2e8f0] bg-white text-[#334155] hover:bg-slate-50"
              }`}
            >
              Custom Expiry Date…
            </button>
            {duration === 0 ? (
              <div className="mt-2.5">
                <label className="text-[11px] font-bold uppercase tracking-wider text-[#475467]">
                  Target Expiry Date
                </label>
                <input
                  type="date"
                  value={customDate}
                  min={new Date().toISOString().split("T")[0]}
                  onChange={(e) => setCustomDate(e.target.value)}
                  className="focus-ring mt-1 block w-full rounded-xl border border-[#d0d5dd] bg-white px-3.5 py-2.5 text-xs text-[#111322] shadow-sm"
                />
              </div>
            ) : null}
          </div>

          {errorMessage ? (
            <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-xs text-rose-800">
              <AlertTriangle size={15} className="shrink-0 text-rose-600" />
              <span>{errorMessage}</span>
            </div>
          ) : null}

          {successMessage ? (
            <div className="flex items-center gap-2 rounded-xl border border-emerald-200 bg-emerald-50 p-3 text-xs text-emerald-800">
              <Check size={15} className="shrink-0 text-emerald-600" />
              <span>{successMessage}</span>
            </div>
          ) : null}
        </div>

        <div className="mt-6 flex items-center justify-end gap-3 border-t border-[#eaecf0] pt-4">
          <button
            type="button"
            disabled={isPending}
            onClick={onClose}
            className="focus-ring rounded-xl border border-[#d0d5dd] bg-white px-4 py-2 text-xs font-bold uppercase tracking-wider text-[#344054] transition hover:bg-slate-50 disabled:opacity-60"
          >
            Cancel
          </button>
          <button
            type="button"
            disabled={isPending || (duration === 0 && !customDate)}
            onClick={handleRenew}
            className="focus-ring inline-flex items-center gap-2 rounded-xl bg-[#057c73] px-4 py-2 text-xs font-bold uppercase tracking-wider text-white shadow-sm transition hover:bg-[#04675f] disabled:opacity-60"
          >
            <Check size={14} />
            Confirm Renewal
          </button>
        </div>
      </div>
    </div>
  );
}
