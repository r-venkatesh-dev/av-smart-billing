"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { usePathname } from "next/navigation";
import { Loader2 } from "lucide-react";

interface BusyContextType {
  isBusy: boolean;
  message: string;
  setBusy: (busy: boolean, message?: string) => void;
  runWithBusy: <T>(task: () => Promise<T>, message?: string) => Promise<T>;
}

const BusyContext = createContext<BusyContextType>({
  isBusy: false,
  message: "Processing…",
  setBusy: () => {},
  runWithBusy: async (task) => task(),
});

export function useAdminBusy() {
  return useContext(BusyContext);
}

export function AdminBusyProvider({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const [isBusy, setIsBusyState] = useState(false);
  const [message, setMessage] = useState("Processing request…");
  const timeoutRef = useRef<number | null>(null);

  // Clear busy on pathname change
  useEffect(() => {
    setIsBusyState(false);
  }, [pathname]);

  const setBusy = useCallback((busy: boolean, msg?: string) => {
    if (timeoutRef.current) {
      window.clearTimeout(timeoutRef.current);
      timeoutRef.current = null;
    }
    if (busy) {
      setMessage(msg || "Processing request…");
      setIsBusyState(true);
      // Failsafe timeout to unblock screen if something hangs
      timeoutRef.current = window.setTimeout(() => {
        setIsBusyState(false);
      }, 30000);
    } else {
      setIsBusyState(false);
    }
  }, []);

  const runWithBusy = useCallback(
    async <T,>(task: () => Promise<T>, msg?: string): Promise<T> => {
      setBusy(true, msg || "Saving changes…");
      try {
        return await task();
      } finally {
        setBusy(false);
      }
    },
    [setBusy],
  );

  // Global form submission listener: whenever any form in the admin shell is submitted,
  // automatically show the blocking loader unless data-no-busy is specified.
  useEffect(() => {
    function handleFormSubmit(event: Event) {
      const form = event.target as HTMLFormElement | null;
      if (!form || form.getAttribute("data-no-busy") === "true") return;

      const submitBtn = form.querySelector(
        "button[type='submit'], input[type='submit']",
      );
      const customMessage =
        form.getAttribute("data-busy-message") ||
        (submitBtn?.textContent?.trim()
          ? `${submitBtn.textContent.trim().replace(/…$/, "")}…`
          : "Saving changes…");

      setBusy(true, customMessage);
    }

    document.addEventListener("submit", handleFormSubmit, true);
    return () => {
      document.removeEventListener("submit", handleFormSubmit, true);
      if (timeoutRef.current) window.clearTimeout(timeoutRef.current);
    };
  }, [setBusy]);

  return (
    <BusyContext.Provider value={{ isBusy, message, setBusy, runWithBusy }}>
      {children}
      {isBusy ? (
        <div
          role="status"
          aria-live="assertive"
          aria-label={message}
          className="fixed inset-0 z-[99999] flex items-center justify-center bg-[#0d1024]/60 backdrop-blur-md transition-all animate-in fade-in duration-200"
        >
          <div className="mx-4 flex max-w-sm flex-col items-center gap-4 rounded-2xl border border-white/15 bg-[#171b36] p-7 text-center shadow-2xl">
            <div className="relative flex size-14 items-center justify-center rounded-2xl bg-gradient-to-tr from-[#057c73] to-[#5b4df5] p-0.5 shadow-lg shadow-[#057c73]/30">
              <div className="flex size-full items-center justify-center rounded-2xl bg-[#171b36]">
                <Loader2 className="size-7 animate-spin text-[#38d4c7]" />
              </div>
            </div>
            <div>
              <p className="text-base font-bold text-white tracking-wide">
                {message}
              </p>
              <p className="mt-1 text-xs text-[#9aa0c2]">
                Please wait, do not close or navigate away.
              </p>
            </div>
            <div className="h-1 w-32 overflow-hidden rounded-full bg-white/10">
              <div className="h-full w-full animate-[progress_1.5s_ease-in-out_infinite] rounded-full bg-gradient-to-r from-[#057c73] via-[#38d4c7] to-[#5b4df5]" />
            </div>
          </div>
        </div>
      ) : null}
    </BusyContext.Provider>
  );
}
