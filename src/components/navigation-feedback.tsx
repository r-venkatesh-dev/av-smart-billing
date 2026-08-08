"use client";

import { useEffect, useRef, useState } from "react";
import { usePathname } from "next/navigation";
import { LoaderCircle } from "lucide-react";

export function NavigationFeedback() {
  const pathname = usePathname();
  const [startedFrom, setStartedFrom] = useState<string | null>(null);
  const timeoutRef = useRef<number | null>(null);
  const navigating = startedFrom === pathname;

  useEffect(() => {
    function begin(event: MouseEvent) {
      if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      const target = event.target;
      if (!(target instanceof Element)) return;
      const anchor = target.closest("a[href]");
      if (!(anchor instanceof HTMLAnchorElement) || anchor.target === "_blank" || anchor.hasAttribute("download")) return;
      const destination = new URL(anchor.href, window.location.href);
      if (destination.origin !== window.location.origin || destination.pathname === window.location.pathname) return;
      setStartedFrom(window.location.pathname);
      if (timeoutRef.current) window.clearTimeout(timeoutRef.current);
      timeoutRef.current = window.setTimeout(() => setStartedFrom(null), 10000);
    }

    document.addEventListener("click", begin, true);
    return () => {
      document.removeEventListener("click", begin, true);
      if (timeoutRef.current) window.clearTimeout(timeoutRef.current);
    };
  }, []);

  if (!navigating) return null;
  return <div className="screen-only pointer-events-none fixed inset-x-0 top-0 z-[100]" role="status" aria-live="polite" aria-label="Loading the next page">
    <div className="route-progress h-1 bg-[#057c73] shadow-[0_0_12px_rgba(5,124,115,.45)]" />
    <div className="mx-auto mt-3 flex w-fit items-center gap-2 border border-[#dfe3e1] bg-white px-4 py-2 text-xs font-semibold text-[#26272a] shadow-lg"><LoaderCircle size={15} className="animate-spin text-[#057c73]" />Loading page…</div>
  </div>;
}
