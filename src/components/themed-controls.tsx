"use client";

import { useEffect, useId, useMemo, useRef, useState } from "react";
import { CalendarDays, Check, ChevronDown, ChevronLeft, ChevronRight, Search } from "lucide-react";

export interface SelectOption {
  value: string;
  label: string;
  description?: string;
  disabled?: boolean;
}

export function ThemedSelect({ name, label, options, defaultValue = "", placeholder = "Select an option", required, searchable = false, emptyMessage = "No options available", onValueChange }: {
  name: string;
  label: string;
  options: SelectOption[];
  defaultValue?: string;
  placeholder?: string;
  required?: boolean;
  searchable?: boolean;
  emptyMessage?: string;
  onValueChange?: (value: string) => void;
}) {
  const listboxId = useId();
  const rootRef = useRef<HTMLDivElement>(null);
  const searchRef = useRef<HTMLInputElement>(null);
  const [open, setOpen] = useState(false);
  const [value, setValue] = useState(defaultValue);
  const [query, setQuery] = useState("");
  const selected = options.find((option) => option.value === value);
  const visibleOptions = useMemo(() => {
    const search = query.trim().toLowerCase();
    return search ? options.filter((option) => `${option.label} ${option.description ?? ""}`.toLowerCase().includes(search)) : options;
  }, [options, query]);

  useEffect(() => {
    function close(event: PointerEvent) {
      if (!rootRef.current?.contains(event.target as Node)) setOpen(false);
    }
    function escape(event: KeyboardEvent) {
      if (event.key === "Escape") setOpen(false);
    }
    document.addEventListener("pointerdown", close);
    document.addEventListener("keydown", escape);
    return () => {
      document.removeEventListener("pointerdown", close);
      document.removeEventListener("keydown", escape);
    };
  }, []);

  function toggle() {
    setOpen((current) => {
      const next = !current;
      if (next && searchable) requestAnimationFrame(() => searchRef.current?.focus());
      return next;
    });
  }

  return <div ref={rootRef} className="relative">
    <span className="mb-2 block text-sm font-semibold">{label}</span>
    <input type="hidden" name={name} value={value} required={required} />
    <button type="button" onClick={toggle} aria-haspopup="listbox" aria-expanded={open} aria-controls={listboxId} className={`focus-ring flex min-h-11 w-full items-center justify-between gap-3 border bg-white px-3 text-left text-sm transition ${open ? "border-[#057c73] ring-2 ring-[#057c73]/10" : "border-[#dfe3eb]"}`}>
      <span className="min-w-0 flex-1"><span className={`block truncate ${selected ? "text-[#26272a]" : "text-[#8a908d]"}`}>{selected?.label ?? placeholder}</span>{selected?.description ? <small className="mt-0.5 block truncate text-[11px] text-[#8a908d]">{selected.description}</small> : null}</span>
      <ChevronDown size={16} className={`shrink-0 text-[#6d716f] transition ${open ? "rotate-180" : ""}`} />
    </button>
    {open ? <div className="absolute left-0 right-0 z-50 mt-2 border border-[#dfe3e1] bg-white p-2 shadow-[0_18px_45px_rgba(38,39,42,.14)]">
      {searchable ? <label className="mb-2 flex h-10 items-center gap-2 border border-[#dfe3e1] bg-[#f7f8f7] px-3"><Search size={15} className="text-[#6d716f]" /><span className="sr-only">Search {label.toLowerCase()}</span><input ref={searchRef} value={query} onChange={(event) => setQuery(event.target.value)} className="min-w-0 flex-1 bg-transparent text-sm outline-none" placeholder={`Search ${label.toLowerCase()}…`} /></label> : null}
      <div id={listboxId} role="listbox" aria-label={label} className="max-h-64 overflow-y-auto">{visibleOptions.length ? visibleOptions.map((option) => <button key={`${option.value}-${option.label}`} type="button" role="option" aria-selected={value === option.value} disabled={option.disabled} onClick={() => { setValue(option.value); onValueChange?.(option.value); setOpen(false); setQuery(""); }} className="flex w-full items-center gap-3 border-l-2 border-transparent px-3 py-2.5 text-left transition hover:border-[#057c73] hover:bg-[#e6f2f0] disabled:cursor-not-allowed disabled:opacity-45"><span className="min-w-0 flex-1"><strong className="block truncate text-sm font-semibold">{option.label}</strong>{option.description ? <small className="mt-0.5 block truncate text-[11px] text-[#6d716f]">{option.description}</small> : null}</span>{value === option.value ? <Check size={16} className="shrink-0 text-[#057c73]" /> : null}</button>) : <p className="px-3 py-6 text-center text-xs text-[#6d716f]">{emptyMessage}</p>}</div>
    </div> : null}
  </div>;
}

function parseDate(value: string) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  return match ? { year: Number(match[1]), month: Number(match[2]) - 1, day: Number(match[3]) } : null;
}

function dateValue(year: number, month: number, day: number) {
  return `${year}-${String(month + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

function formatDateLabel(value: string, placeholder: string) {
  const date = parseDate(value);
  if (!date) return placeholder;
  return new Intl.DateTimeFormat("en-IN", { day: "2-digit", month: "long", year: "numeric" }).format(new Date(date.year, date.month, date.day));
}

export function ThemedDatePicker({ name, label, defaultValue = "", disablePast = true, disableFuture = false, required = false }: { name: string; label: string; defaultValue?: string; disablePast?: boolean; disableFuture?: boolean; required?: boolean }) {
  const calendarId = useId();
  const rootRef = useRef<HTMLDivElement>(null);
  const initial = parseDate(defaultValue);
  const [value, setValue] = useState(defaultValue);
  const [open, setOpen] = useState(false);
  const [view, setView] = useState(initial ? { year: initial.year, month: initial.month } : { year: 2000, month: 0 });
  const [today, setToday] = useState("");

  useEffect(() => {
    function close(event: PointerEvent) {
      if (!rootRef.current?.contains(event.target as Node)) setOpen(false);
    }
    function escape(event: KeyboardEvent) {
      if (event.key === "Escape") setOpen(false);
    }
    document.addEventListener("pointerdown", close);
    document.addEventListener("keydown", escape);
    return () => {
      document.removeEventListener("pointerdown", close);
      document.removeEventListener("keydown", escape);
    };
  }, []);

  function openCalendar() {
    if (!open) {
      const current = new Date();
      const selected = parseDate(value);
      setView(selected ? { year: selected.year, month: selected.month } : { year: current.getFullYear(), month: current.getMonth() });
      setToday(dateValue(current.getFullYear(), current.getMonth(), current.getDate()));
    }
    setOpen((current) => !current);
  }

  function moveMonth(offset: number) {
    setView((current) => {
      const date = new Date(current.year, current.month + offset, 1);
      return { year: date.getFullYear(), month: date.getMonth() };
    });
  }

  const firstWeekday = new Date(view.year, view.month, 1).getDay();
  const daysInMonth = new Date(view.year, view.month + 1, 0).getDate();
  const monthLabel = new Intl.DateTimeFormat("en-IN", { month: "long", year: "numeric" }).format(new Date(view.year, view.month, 1));

  return <div ref={rootRef} className="relative">
    <span className="mb-2 block text-sm font-semibold">{label}</span>
    <input type="hidden" name={name} value={value} required={required} />
    <button type="button" onClick={openCalendar} aria-haspopup="dialog" aria-expanded={open} aria-controls={calendarId} className={`focus-ring flex h-11 w-full items-center justify-between border bg-white px-3 text-left text-sm transition ${open ? "border-[#057c73] ring-2 ring-[#057c73]/10" : "border-[#dfe3eb]"}`}><span className={value ? "text-[#26272a]" : "text-[#8a908d]"}>{formatDateLabel(value, `Select ${label.toLowerCase()}`)}</span><CalendarDays size={17} className="text-[#057c73]" /></button>
    {open ? <div id={calendarId} role="dialog" aria-label="Choose due date" className="absolute right-0 z-50 mt-2 w-[310px] border border-[#dfe3e1] bg-white p-4 shadow-[0_18px_45px_rgba(38,39,42,.14)]"><div className="mb-4 flex items-center justify-between"><button type="button" onClick={() => moveMonth(-1)} aria-label="Previous month" className="focus-ring grid size-9 place-items-center border border-[#dfe3e1] text-[#057c73]"><ChevronLeft size={17} /></button><strong className="font-serif text-lg font-semibold">{monthLabel}</strong><button type="button" onClick={() => moveMonth(1)} aria-label="Next month" className="focus-ring grid size-9 place-items-center border border-[#dfe3e1] text-[#057c73]"><ChevronRight size={17} /></button></div><div className="grid grid-cols-7 text-center text-[10px] font-bold uppercase tracking-[.08em] text-[#8a908d]">{["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"].map((day) => <span key={day} className="py-2">{day}</span>)}</div><div className="grid grid-cols-7 gap-1">{Array.from({ length: firstWeekday }, (_, index) => <span key={`blank-${index}`} />)}{Array.from({ length: daysInMonth }, (_, index) => {
      const day = index + 1;
      const candidate = dateValue(view.year, view.month, day);
      const selected = candidate === value;
      const current = candidate === today;
      const disabled = Boolean(today) && ((disablePast && candidate < today) || (disableFuture && candidate > today));
      return <button type="button" key={candidate} disabled={disabled} onClick={() => { setValue(candidate); setOpen(false); }} aria-label={candidate} aria-pressed={selected} className={`focus-ring grid aspect-square place-items-center text-xs transition disabled:cursor-not-allowed disabled:text-[#c5c9c7] ${selected ? "bg-[#057c73] font-bold text-white" : current ? "border border-[#057c73] font-bold text-[#057c73]" : disabled ? "" : "hover:bg-[#e6f2f0]"}`}>{day}</button>;
    })}</div><div className="mt-4 flex justify-between border-t border-[#dfe3e1] pt-3"><button type="button" onClick={() => { setValue(""); setOpen(false); }} className="text-[10px] font-bold uppercase tracking-[.1em] text-[#6d716f]">Clear</button>{today ? <button type="button" onClick={() => { setValue(today); setOpen(false); }} className="text-[10px] font-bold uppercase tracking-[.1em] text-[#057c73]">Today</button> : null}</div></div> : null}
  </div>;
}
