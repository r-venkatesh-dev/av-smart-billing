"use client";

import { useEffect } from "react";
import { Printer } from "lucide-react";

export function PrintInvoiceButton({ autoPrint = false, preferThermal = false, thermalWidth = 80 }: { autoPrint?: boolean; preferThermal?: boolean; thermalWidth?: 58 | 80 }) {
  function print(format: "a4" | "thermal") {
    document.body.dataset.invoicePrint = format;
    window.print();
  }
  useEffect(() => {
    if (!autoPrint) return;
    const timer = window.setTimeout(() => print(preferThermal ? "thermal" : "a4"), 250);
    return () => window.clearTimeout(timer);
  }, [autoPrint, preferThermal]);

  return <><button type="button" onClick={() => print("thermal")} className="focus-ring inline-flex h-11 items-center justify-center gap-2 border border-[#dfe3e1] bg-white px-5 text-[11px] font-bold uppercase tracking-[.1em]"><Printer size={16} />{thermalWidth}mm receipt</button><button type="button" onClick={() => print("a4")} className="focus-ring inline-flex h-11 items-center justify-center gap-2 bg-[#057c73] px-5 text-[11px] font-bold uppercase tracking-[.1em] text-white"><Printer size={16} />A4 / Save PDF</button></>;
}
