import Link from "next/link";
import { Building2 } from "lucide-react";

export function WorkspaceRequired() {
  return <div className="surface flex min-h-80 flex-col items-center justify-center p-8 text-center"><span className="grid size-12 place-items-center bg-[#e6f2f0] text-[#057c73]"><Building2 /></span><h2 className="mt-5 text-2xl font-normal">Set up your billing workspace</h2><p className="mt-2 max-w-md text-sm leading-6 text-[#667085]">Create the business profile that owns billing customers, products, invoices and payments.</p><Link href="/billing/settings" className="mt-6 bg-[#057c73] px-5 py-3 text-[11px] font-bold uppercase tracking-[.1em] text-white">Set up workspace</Link></div>;
}
