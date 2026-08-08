import type { ReactNode } from "react";
import Link from "next/link";
import { ArrowLeft, Inbox, Plus, Search } from "lucide-react";

export function StatusBadge({ status }: { status: string }) {
  const tone = status === "ACTIVE" || status === "PAID" ? "bg-emerald-50 text-emerald-700 ring-emerald-600/15" : status === "EXPIRED" || status === "REVOKED" || status === "CANCELLED" || status === "INACTIVE" ? "bg-rose-50 text-rose-700 ring-rose-600/15" : "bg-amber-50 text-amber-700 ring-amber-600/15";
  return <span className={`inline-flex rounded-full px-2.5 py-1 text-[11px] font-bold tracking-wide ring-1 ring-inset ${tone}`}>{status.replaceAll("_", " ")}</span>;
}

export function PageHeader({ eyebrow, title, description, actionLabel, actionHref, backHref }: { eyebrow?: string; title: string; description: string; actionLabel?: string; actionHref?: string; backHref?: string }) {
  return (
    <header className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div>
        {backHref ? <Link href={backHref} className="focus-ring mb-4 inline-flex items-center gap-1.5 rounded text-[11px] font-bold uppercase tracking-[.1em] text-[#5b4df5]"><ArrowLeft size={15} /> Back</Link> : null}
        {eyebrow ? <p className="mb-2 text-[11px] font-bold uppercase tracking-[0.18em] text-[#7b71e8] before:mr-3 before:inline-block before:h-0.5 before:w-6 before:align-middle before:bg-current">{eyebrow}</p> : null}
        <h1 className="text-3xl font-normal tracking-[-0.035em] text-[#172034] sm:text-[36px]">{title}</h1>
        <p className="mt-1.5 max-w-2xl text-sm leading-6 text-[#667085]">{description}</p>
      </div>
      {actionLabel && actionHref ? <Link href={actionHref} className="focus-ring inline-flex h-11 shrink-0 items-center justify-center gap-3 rounded-xl bg-[#5b4df5] px-5 text-[11px] font-bold uppercase tracking-[.1em] text-white transition hover:bg-[#4b3ee2]"><Plus size={16} />{actionLabel}</Link> : null}
    </header>
  );
}

export function SearchField({ placeholder = "Search…" }: { placeholder?: string }) {
  return <label className="relative block w-full sm:w-72"><Search className="absolute left-3 top-1/2 -translate-y-1/2 text-[#98a2b3]" size={17} /><span className="sr-only">Search</span><input className="focus-ring h-10 w-full rounded-xl border border-[#e0e4ec] bg-white pl-10 pr-3 text-sm placeholder:text-[#98a2b3]" placeholder={placeholder} /></label>;
}

export function EmptyState({ title, message, action }: { title: string; message: string; action?: string }) {
  return <div className="surface flex min-h-72 flex-col items-center justify-center px-6 text-center"><div className="mb-4 grid size-12 place-items-center rounded-2xl bg-[#f0efff] text-[#5b4df5]"><Inbox size={22} /></div><h2 className="text-xl font-normal">{title}</h2><p className="mt-1 max-w-sm text-sm leading-6 text-[#667085]">{message}</p>{action ? <button className="focus-ring mt-5 rounded-xl bg-[#5b4df5] px-5 py-2.5 text-[11px] font-bold uppercase tracking-[.1em] text-white">{action}</button> : null}</div>;
}

export function DetailItem({ label, children }: { label: string; children: ReactNode }) {
  return <div><dt className="text-xs font-semibold uppercase tracking-wide text-[#98a2b3]">{label}</dt><dd className="mt-1.5 text-sm font-medium text-[#344054]">{children}</dd></div>;
}
