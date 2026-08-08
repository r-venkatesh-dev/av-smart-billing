"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { ArrowRight, LoaderCircle, Search, X } from "lucide-react";
import type { GlobalSearchResult } from "@/app/api/search/route";

export function GlobalSearch({ mode }: { mode: "admin" | "billing" }) {
  const router = useRouter();
  const containerRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<GlobalSearchResult[]>([]);
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    function handleKeydown(event: KeyboardEvent) {
      if ((event.metaKey || event.ctrlKey) && event.key.toLocaleLowerCase() === "k") {
        event.preventDefault();
        setOpen(true);
        inputRef.current?.focus();
      }
      if (event.key === "Escape") {
        setOpen(false);
        inputRef.current?.blur();
      }
    }
    function handlePointerDown(event: PointerEvent) {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) setOpen(false);
    }
    document.addEventListener("keydown", handleKeydown);
    document.addEventListener("pointerdown", handlePointerDown);
    return () => {
      document.removeEventListener("keydown", handleKeydown);
      document.removeEventListener("pointerdown", handlePointerDown);
    };
  }, []);

  useEffect(() => {
    const trimmed = query.trim();
    if (trimmed.length < 2) return;
    const controller = new AbortController();
    const timeout = window.setTimeout(async () => {
      setLoading(true);
      setError("");
      try {
        const response = await fetch(`/api/search?mode=${mode}&q=${encodeURIComponent(trimmed)}`, {
          signal: controller.signal,
          cache: "no-store",
        });
        const payload = (await response.json()) as { results?: GlobalSearchResult[]; error?: string };
        if (!response.ok) throw new Error(payload.error || "Search failed");
        setResults(payload.results ?? []);
      } catch (fetchError) {
        if (fetchError instanceof DOMException && fetchError.name === "AbortError") return;
        setResults([]);
        setError(fetchError instanceof Error ? fetchError.message : "Search failed");
      } finally {
        if (!controller.signal.aborted) setLoading(false);
      }
    }, 250);
    return () => {
      window.clearTimeout(timeout);
      controller.abort();
    };
  }, [mode, query]);

  function select(result: GlobalSearchResult) {
    setOpen(false);
    setQuery("");
    setResults([]);
    router.push(result.href);
  }

  const hasQuery = query.trim().length >= 2;

  return <div ref={containerRef} className="relative min-w-0">
    <div className={`flex h-10 w-[42vw] min-w-[120px] items-center gap-2 border bg-[#f5f6fa] px-3 transition sm:w-[310px] ${open ? "border-[#057c73] ring-2 ring-[#057c73]/10" : "border-transparent"}`}>
      {loading ? <LoaderCircle size={16} className="shrink-0 animate-spin text-[#057c73]" /> : <Search size={16} className="shrink-0 text-[#667085]" />}
      <input
        ref={inputRef}
        value={query}
        onFocus={() => setOpen(true)}
        onChange={(event) => { setQuery(event.target.value); setOpen(true); if (event.target.value.trim().length < 2) { setResults([]); setError(""); } }}
        onKeyDown={(event) => {
          if (event.key === "Enter" && results[0]) select(results[0]);
        }}
        role="combobox"
        aria-label={`Search ${mode === "admin" ? "Control Center" : "Billing Desk"}`}
        aria-expanded={open}
        aria-controls="global-search-results"
        autoComplete="off"
        placeholder="Search anything…"
        className="min-w-0 flex-1 bg-transparent text-xs text-[#26272a] outline-none placeholder:text-[#98a2b3]"
      />
      {query ? <button type="button" aria-label="Clear search" onClick={() => { setQuery(""); setResults([]); setError(""); inputRef.current?.focus(); }} className="text-[#667085] hover:text-[#26272a]"><X size={15} /></button> : <kbd className="hidden rounded border border-[#dfe2e9] bg-white px-1.5 py-0.5 text-[10px] text-[#667085] sm:block">⌘ K</kbd>}
    </div>
    {open ? <div id="global-search-results" className="absolute left-0 top-[calc(100%+10px)] z-50 w-[min(88vw,430px)] border border-[#dfe3e1] bg-white p-2 shadow-[0_18px_50px_rgba(23,27,54,.16)]">
      {!hasQuery ? <div className="px-3 py-5 text-center"><Search size={22} className="mx-auto text-[#a3aaa7]" /><p className="mt-2 text-xs font-semibold text-[#26272a]">Search this workspace</p><p className="mt-1 text-[11px] text-[#7b817e]">Type at least 2 characters to find pages and records.</p></div> : null}
      {hasQuery && loading && results.length === 0 ? <p className="px-3 py-6 text-center text-xs text-[#7b817e]">Searching Supabase…</p> : null}
      {hasQuery && !loading && !error && results.length === 0 ? <p className="px-3 py-6 text-center text-xs text-[#7b817e]">No matching pages or records found.</p> : null}
      {error ? <p className="px-3 py-5 text-center text-xs text-rose-700">{error}</p> : null}
      {results.length > 0 ? <ul className="max-h-[360px] overflow-y-auto py-1">
        {results.map((result) => <li key={result.id}>
          <button type="button" onClick={() => select(result)} className="group flex w-full items-center gap-3 px-3 py-3 text-left transition hover:bg-[#f2f6f5] focus:bg-[#f2f6f5] focus:outline-none">
            <span className="min-w-16 border border-[#d9e4e2] bg-[#f3f8f7] px-2 py-1 text-center text-[9px] font-bold uppercase tracking-[.08em] text-[#057c73]">{result.type}</span>
            <span className="min-w-0 flex-1"><strong className="block truncate text-xs font-semibold text-[#26272a]">{result.title}</strong><small className="mt-0.5 block truncate text-[10px] text-[#7b817e]">{result.subtitle}</small></span>
            <ArrowRight size={14} className="shrink-0 text-[#a3aaa7] transition group-hover:translate-x-0.5 group-hover:text-[#057c73]" />
          </button>
        </li>)}
      </ul> : null}
      {results.length > 0 ? <p className="border-t border-[#edf0ee] px-3 py-2 text-[9px] uppercase tracking-[.1em] text-[#8b918e]">Press Enter to open the first result</p> : null}
    </div> : null}
  </div>;
}
