"use client";

import { useEffect } from "react";
import { Printer } from "lucide-react";

export function PrintInvoiceButton({ autoPrint = false }: { autoPrint?: boolean }) {
  useEffect(() => {
    if (!autoPrint) return;
    const timer = window.setTimeout(() => window.print(), 250);
    return () => window.clearTimeout(timer);
  }, [autoPrint]);

  return <button type="button" onClick={() => window.print()} className="focus-ring inline-flex h-11 items-center justify-center gap-2 bg-[#057c73] px-5 text-[11px] font-bold uppercase tracking-[.1em] text-white"><Printer size={16} />Print / Save PDF</button>;
}
