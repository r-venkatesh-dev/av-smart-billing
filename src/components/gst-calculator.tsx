"use client";

import { useId, useMemo, useState } from "react";
import {
  Check,
  Copy,
  Info,
  RotateCcw,
} from "lucide-react";
import { formatMoney } from "@/lib/format";

const GST_SLABS = [0, 5, 12, 18, 28];

export function GstCalculator() {
  const [amountStr, setAmountStr] = useState<string>("1000");
  const [gstRate, setGstRate] = useState<number>(18);
  const [isInclusive, setIsInclusive] = useState<boolean>(false);
  const [taxType, setTaxType] = useState<"INTRA" | "INTER">("INTRA");
  const [copied, setCopied] = useState<boolean>(false);
  const amountInputId = useId();
  const gstRateInputId = useId();

  const amount = Math.max(0, parseFloat(amountStr) || 0);

  const result = useMemo(() => {
    const rate = Math.max(0, gstRate || 0);

    if (isInclusive) {
      // Amount includes GST: Base = Amount / (1 + Rate / 100)
      const baseAmount = rate === 0 ? amount : (amount * 100) / (100 + rate);
      const totalGst = amount - baseAmount;
      const cgst = totalGst / 2;
      const sgst = totalGst / 2;
      const igst = totalGst;
      const finalAmount = amount;

      return {
        baseAmount,
        totalGst,
        cgst,
        sgst,
        igst,
        finalAmount,
        effectiveRate: rate,
      };
    } else {
      // Amount excludes GST: Total = Base + (Base * Rate / 100)
      const baseAmount = amount;
      const totalGst = (amount * rate) / 100;
      const cgst = totalGst / 2;
      const sgst = totalGst / 2;
      const igst = totalGst;
      const finalAmount = baseAmount + totalGst;

      return {
        baseAmount,
        totalGst,
        cgst,
        sgst,
        igst,
        finalAmount,
        effectiveRate: rate,
      };
    }
  }, [amount, gstRate, isInclusive]);

  function handleQuickAdd(val: number) {
    const current = parseFloat(amountStr) || 0;
    setAmountStr(String(Math.round(current + val)));
  }

  function handleReset() {
    setAmountStr("");
    setGstRate(18);
    setIsInclusive(false);
  }

  function handleCopy() {
    const text = [
      `GST Calculation (${isInclusive ? "GST Inclusive" : "GST Exclusive"}):`,
      `Base / Net Amount: ₹${result.baseAmount.toFixed(2)}`,
      `GST Rate: ${result.effectiveRate}%`,
      taxType === "INTRA"
        ? `CGST (${(result.effectiveRate / 2).toFixed(1)}%): ₹${result.cgst.toFixed(2)}\nSGST (${(result.effectiveRate / 2).toFixed(1)}%): ₹${result.sgst.toFixed(2)}`
        : `IGST (${result.effectiveRate}%): ₹${result.igst.toFixed(2)}`,
      `Total GST: ₹${result.totalGst.toFixed(2)}`,
      `Total Final Amount: ₹${result.finalAmount.toFixed(2)}`,
    ].join("\n");

    navigator.clipboard.writeText(text).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }).catch(() => {});
  }

  return (
    <div className="mx-auto max-w-4xl space-y-6">
      {/* Top calculation mode toggle */}
      <div className="surface p-4 sm:p-6">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 className="text-base font-bold text-[#171b36]">Calculation Method</h2>
            <p className="text-xs text-[#667085]">
              Choose whether the entered price already includes GST or excludes GST.
            </p>
          </div>
          <div className="inline-flex rounded-xl border border-[#dfe3eb] bg-[#f8f9fa] p-1">
            <button
              type="button"
              onClick={() => setIsInclusive(false)}
              className={`rounded-lg px-4 py-2 text-xs font-bold transition ${
                !isInclusive
                  ? "bg-[#057c73] text-white shadow-sm"
                  : "text-[#475467] hover:text-[#171b36]"
              }`}
            >
              GST Exclusive (+ Add GST)
            </button>
            <button
              type="button"
              onClick={() => setIsInclusive(true)}
              className={`rounded-lg px-4 py-2 text-xs font-bold transition ${
                isInclusive
                  ? "bg-[#057c73] text-white shadow-sm"
                  : "text-[#475467] hover:text-[#171b36]"
              }`}
            >
              GST Inclusive (− Remove GST)
            </button>
          </div>
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-[1.1fr_1fr]">
        {/* Input parameters */}
        <div className="surface space-y-5 p-6">
          <div>
            <label htmlFor={amountInputId} className="block text-xs font-bold uppercase tracking-wider text-[#475467]">
              {isInclusive ? "Total Amount (₹ with GST)" : "Base Price / Amount (₹)"}
            </label>
            <div className="relative mt-2">
              <span className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3.5 text-base font-semibold text-[#667085]">
                ₹
              </span>
              <input
                id={amountInputId}
                type="number"
                min="0"
                step="any"
                value={amountStr}
                onChange={(e) => setAmountStr(e.target.value)}
                placeholder="0.00"
                className="focus-ring h-12 w-full rounded-xl border border-[#dfe3eb] bg-white pl-8 pr-4 text-base font-semibold outline-none"
              />
            </div>
            {/* Quick add chips */}
            <div className="mt-2.5 flex flex-wrap gap-1.5">
              {[100, 500, 1000, 5000, 10000].map((quick) => (
                <button
                  key={quick}
                  type="button"
                  onClick={() => handleQuickAdd(quick)}
                  className="rounded-lg border border-[#e4e7ec] bg-[#f8f9fa] px-2.5 py-1 text-[11px] font-semibold text-[#475467] transition hover:border-[#057c73] hover:text-[#057c73]"
                >
                  +{quick}
                </button>
              ))}
            </div>
          </div>

          <div>
            <label htmlFor={gstRateInputId} className="block text-xs font-bold uppercase tracking-wider text-[#475467]">
              GST Rate Slab (%)
            </label>
            {/* Common standard slabs */}
            <div className="mt-2 grid grid-cols-5 gap-2">
              {GST_SLABS.map((rate) => (
                <button
                  key={rate}
                  type="button"
                  onClick={() => setGstRate(rate)}
                  className={`flex h-11 flex-col items-center justify-center rounded-xl border text-xs font-bold transition ${
                    gstRate === rate
                      ? "border-[#057c73] bg-[#e6f2f0] text-[#035f58]"
                      : "border-[#dfe3eb] bg-white text-[#344054] hover:bg-[#f9fafb]"
                  }`}
                >
                  <span>{rate}%</span>
                  <span className="text-[9px] font-normal text-[#667085]">
                    {rate === 0
                      ? "Nil"
                      : rate === 5
                      ? "Basic"
                      : rate === 12
                      ? "Standard"
                      : rate === 18
                      ? "Common"
                      : "Luxury"}
                  </span>
                </button>
              ))}
            </div>

            {/* Custom rate input */}
            <div className="mt-3 flex items-center gap-3">
              <span className="text-xs text-[#667085]">Or custom rate:</span>
              <div className="relative w-28">
                <input
                  id={gstRateInputId}
                  type="number"
                  min="0"
                  max="100"
                  step="0.1"
                  value={gstRate}
                  onChange={(e) => setGstRate(parseFloat(e.target.value) || 0)}
                  className="focus-ring h-9 w-full rounded-lg border border-[#dfe3eb] bg-white px-3 pr-7 text-xs font-bold outline-none"
                />
                <span className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-2.5 text-xs text-[#667085]">
                  %
                </span>
              </div>
            </div>
          </div>

          {/* Tax treatment split */}
          <div className="border-t border-[#eaecf0] pt-4">
            <span className="block text-xs font-bold uppercase tracking-wider text-[#475467]">
              Tax Treatment
            </span>
            <div className="mt-2 grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={() => setTaxType("INTRA")}
                className={`rounded-xl border p-2.5 text-left transition ${
                  taxType === "INTRA"
                    ? "border-[#057c73] bg-[#edf7f5] text-[#057c73]"
                    : "border-[#dfe3eb] bg-white text-[#344054] hover:bg-[#f9fafb]"
                }`}
              >
                <strong className="block text-xs">Intra-State</strong>
                <small className="text-[10px] text-[#667085]">CGST + SGST (50% each)</small>
              </button>
              <button
                type="button"
                onClick={() => setTaxType("INTER")}
                className={`rounded-xl border p-2.5 text-left transition ${
                  taxType === "INTER"
                    ? "border-[#057c73] bg-[#edf7f5] text-[#057c73]"
                    : "border-[#dfe3eb] bg-white text-[#344054] hover:bg-[#f9fafb]"
                }`}
              >
                <strong className="block text-xs">Inter-State</strong>
                <small className="text-[10px] text-[#667085]">IGST (Full rate)</small>
              </button>
            </div>
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={handleReset}
              className="focus-ring inline-flex h-9 items-center gap-1.5 rounded-lg border border-[#dfe3eb] bg-white px-3 text-xs font-semibold text-[#475467] hover:bg-[#f8f9fa]"
            >
              <RotateCcw size={14} />
              <span>Reset</span>
            </button>
          </div>
        </div>

        {/* Output breakdown summary */}
        <div className="surface flex flex-col justify-between p-6">
          <div className="space-y-5">
            <div className="flex items-center justify-between border-b border-[#eaecf0] pb-4">
              <div>
                <p className="text-[10px] font-bold uppercase tracking-wider text-[#057c73]">
                  Calculated Result
                </p>
                <h3 className="font-serif text-xl font-bold text-[#171b36]">
                  Price Breakup
                </h3>
              </div>
              <span className="rounded-full bg-[#e6f2f0] px-3 py-1 text-xs font-bold text-[#035f58]">
                {gstRate}% GST
              </span>
            </div>

            <dl className="space-y-3.5 text-sm">
              <div className="flex items-center justify-between">
                <dt className="text-[#667085]">Base / Net Price</dt>
                <dd className="font-semibold text-[#171b36]">
                  {formatMoney(Math.round(result.baseAmount * 100))}
                </dd>
              </div>

              {taxType === "INTRA" ? (
                <>
                  <div className="flex items-center justify-between text-xs text-[#475467]">
                    <dt className="flex items-center gap-1.5 pl-3">
                      <span className="size-1.5 rounded-full bg-[#057c73]" />
                      CGST ({((result.effectiveRate || 0) / 2).toFixed(1)}%)
                    </dt>
                    <dd>{formatMoney(Math.round(result.cgst * 100))}</dd>
                  </div>
                  <div className="flex items-center justify-between text-xs text-[#475467]">
                    <dt className="flex items-center gap-1.5 pl-3">
                      <span className="size-1.5 rounded-full bg-[#057c73]" />
                      SGST ({((result.effectiveRate || 0) / 2).toFixed(1)}%)
                    </dt>
                    <dd>{formatMoney(Math.round(result.sgst * 100))}</dd>
                  </div>
                </>
              ) : (
                <div className="flex items-center justify-between text-xs text-[#475467]">
                  <dt className="flex items-center gap-1.5 pl-3">
                    <span className="size-1.5 rounded-full bg-[#057c73]" />
                    IGST ({result.effectiveRate}%)
                  </dt>
                  <dd>{formatMoney(Math.round(result.igst * 100))}</dd>
                </div>
              )}

              <div className="flex items-center justify-between border-t border-[#f2f4f7] pt-2">
                <dt className="font-medium text-[#475467]">Total GST Amount</dt>
                <dd className="font-bold text-[#057c73]">
                  + {formatMoney(Math.round(result.totalGst * 100))}
                </dd>
              </div>

              {/* Highlight final total amount */}
              <div className="rounded-2xl border border-[#bddbd7] bg-[#f2f9f8] p-4">
                <div className="flex items-baseline justify-between">
                  <div>
                    <span className="text-[10px] font-bold uppercase tracking-wider text-[#057c73]">
                      Final Payable Amount
                    </span>
                    <strong className="block text-2xl font-bold text-[#171b36]">
                      {formatMoney(Math.round(result.finalAmount * 100))}
                    </strong>
                  </div>
                  <span className="text-right text-[11px] text-[#667085]">
                    {isInclusive ? "GST Included" : "GST Added"}
                  </span>
                </div>
              </div>
            </dl>
          </div>

          <div className="mt-6 border-t border-[#eaecf0] pt-4">
            <button
              type="button"
              onClick={handleCopy}
              className="focus-ring inline-flex w-full items-center justify-center gap-2 rounded-xl bg-[#171b36] py-2.5 text-xs font-semibold text-white shadow-sm transition hover:bg-[#252b52]"
            >
              {copied ? <Check size={15} /> : <Copy size={15} />}
              <span>{copied ? "Copied to Clipboard!" : "Copy Calculation Breakdown"}</span>
            </button>
            <p className="mt-2.5 flex items-center justify-center gap-1.5 text-[11px] text-[#667085]">
              <Info size={13} />
              <span>Offline calculator. No network requests made.</span>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
