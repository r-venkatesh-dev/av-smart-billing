"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import {
  CheckCircle2,
  Clock,
  CreditCard,
  Eye,
  EyeOff,
  KeyRound,
  LoaderCircle,
  Search,
  ShieldCheck,
  Store,
  Sparkles,
} from "lucide-react";

interface LicenseDetails {
  licenseKeyHint: string;
  companyName: string;
  contactPerson: string;
  phoneMasked: string;
  planName: string;
  planInterval: string;
  priceInPaise: number;
  expiresAt: string;
  isExpired: boolean;
  daysRemaining: number;
  maxDevices: number;
  allowCloudBackup: boolean;
  allowOnlineBilling: boolean;
  allowReportsExports: boolean;
}

interface RenewalCheckoutProps {
  initialToken?: string;
}

function formatMoney(paise: number) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 0,
  }).format(paise / 100);
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString("en-IN", {
    day: "numeric",
    month: "short",
    year: "numeric",
  });
}

function calculateNewExpiry(currentExpiryIso: string, interval: string): string {
  const now = new Date();
  const currentExpiry = new Date(currentExpiryIso);
  const baseDate = currentExpiry > now ? currentExpiry : now;
  const newDate = new Date(baseDate);

  if (interval === "WEEK") newDate.setDate(newDate.getDate() + 7);
  else if (interval === "MONTH") newDate.setMonth(newDate.getMonth() + 1);
  else if (interval === "QUARTER") newDate.setMonth(newDate.getMonth() + 3);
  else newDate.setFullYear(newDate.getFullYear() + 1);

  return newDate.toISOString();
}

async function loadRazorpay() {
  if (window.Razorpay) return true;
  return new Promise<boolean>((resolve) => {
    const existing = document.querySelector<HTMLScriptElement>(
      'script[src="https://checkout.razorpay.com/v1/checkout.js"]',
    );
    if (existing) {
      existing.addEventListener("load", () => resolve(true), { once: true });
      existing.addEventListener("error", () => resolve(false), { once: true });
      return;
    }
    const script = document.createElement("script");
    script.src = "https://checkout.razorpay.com/v1/checkout.js";
    script.onload = () => resolve(true);
    script.onerror = () => resolve(false);
    document.body.appendChild(script);
  });
}

export function RenewalCheckout({ initialToken }: RenewalCheckoutProps) {
  const [token, setToken] = useState<string | undefined>(initialToken);
  const [details, setDetails] = useState<LicenseDetails | null>(null);
  const [loading, setLoading] = useState<boolean>(false);
  const [paying, setPaying] = useState<boolean>(false);
  const [message, setMessage] = useState<string>("");
  const [success, setSuccess] = useState<{ newExpiry: string; planName: string } | null>(null);

  // Manual lookup fields
  const [lookupMode, setLookupMode] = useState<"KEY" | "PHONE">("KEY");
  const [inputKey, setInputKey] = useState<string>("");
  const [inputPhone, setInputPhone] = useState<string>("");
  const [showKey, setShowKey] = useState<boolean>(false);

  useEffect(() => {
    if (initialToken) {
      void fetchDetails({ token: initialToken });
    }
  }, [initialToken]);

  async function fetchDetails(payload: { token?: string; licenseKey?: string; phone?: string }) {
    setLoading(true);
    setMessage("");
    try {
      const res = await fetch("/api/subscriptions/renew/lookup", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      const data = await res.json();
      if (!res.ok || !data.ok) {
        setMessage(data.message || "Failed to find license. Please check your details.");
        return;
      }
      setDetails(data.details);
      setToken(data.token);
    } catch {
      setMessage("Connection error. Please check your network and try again.");
    } finally {
      setLoading(false);
    }
  }

  function handleManualLookup(e: React.FormEvent) {
    e.preventDefault();
    if (lookupMode === "KEY") {
      if (!inputKey.trim()) {
        setMessage("Please enter your license key.");
        return;
      }
      void fetchDetails({ licenseKey: inputKey.trim() });
    } else {
      if (!inputPhone.trim() || inputPhone.trim().length < 10) {
        setMessage("Please enter a valid 10-digit mobile number.");
        return;
      }
      void fetchDetails({ phone: inputPhone.trim() });
    }
  }

  async function handlePay() {
    if (!token || !details) return;
    setPaying(true);
    setMessage("");

    try {
      // If plan is free (0 paise), renew directly without Razorpay!
      if (details.priceInPaise === 0) {
        const freeRes = await fetch("/api/subscriptions/renew/verify", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ token, isFree: true }),
        });
        const result = await freeRes.json();
        if (!freeRes.ok || !result.ok) {
          setMessage(result.message || "Failed to renew plan.");
          setPaying(false);
          return;
        }

        setSuccess({
          newExpiry: result.newExpiry,
          planName: result.planName,
        });
        setPaying(false);
        return;
      }

      const razorpayReady = await loadRazorpay();
      if (!razorpayReady || !window.Razorpay) {
        setMessage("Unable to load Razorpay payment gateway. Please check your internet connection.");
        setPaying(false);
        return;
      }

      // 1. Create renewal order
      const orderRes = await fetch("/api/subscriptions/renew/order", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token }),
      });
      const order = await orderRes.json();

      if (!orderRes.ok || !order.ok) {
        setMessage(order.message || "Could not initiate payment. Please try again.");
        setPaying(false);
        return;
      }

      // 2. Open Razorpay Checkout
      const checkout = new window.Razorpay({
        key: order.keyId,
        amount: order.amount,
        currency: order.currency,
        name: "AV Smartbilling",
        description: `License Renewal - ${order.planName}`,
        order_id: order.razorpayOrderId,
        prefill: order.prefill,
        theme: { color: "#004d40" },
        modal: {
          confirm_close: true,
          ondismiss: () => {
            setPaying(false);
          },
        },
        handler: async (response: {
          razorpay_order_id: string;
          razorpay_payment_id: string;
          razorpay_signature: string;
        }) => {
          setMessage("Payment received! Verifying and extending your license…");
          try {
            const verifyRes = await fetch("/api/subscriptions/renew/verify", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                token,
                razorpayOrderId: response.razorpay_order_id,
                razorpayPaymentId: response.razorpay_payment_id,
                razorpaySignature: response.razorpay_signature,
              }),
            });
            const result = await verifyRes.json();
            if (!verifyRes.ok || !result.ok) {
              setMessage(
                result.message || "Payment verification failed. Please contact support.",
              );
              setPaying(false);
              return;
            }

            setSuccess({
              newExpiry: result.newExpiry,
              planName: result.planName,
            });
            setMessage("");
          } catch {
            setMessage(
              "Payment verification was interrupted. Please contact support with payment ID " +
                response.razorpay_payment_id,
            );
          } finally {
            setPaying(false);
          }
        },
      });

      checkout.open();
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Payment error occurred.");
      setPaying(false);
    }
  }

  // 1. Success Screen
  if (success) {
    return (
      <div className="rounded-2xl border border-emerald-200 bg-white p-6 shadow-xl sm:p-10">
        <div className="flex flex-col items-center text-center">
          <div className="grid size-16 place-items-center rounded-full bg-emerald-100 text-emerald-700 sm:size-20">
            <CheckCircle2 size={40} className="sm:size-48" />
          </div>
          <span className="mt-4 inline-flex items-center gap-1.5 rounded-full bg-emerald-50 px-3 py-1 text-xs font-bold text-emerald-800">
            <Sparkles size={14} /> RENEWAL CONFIRMED
          </span>
          <h2 className="mt-3 text-2xl font-extrabold text-[#171b36] sm:text-3xl">
            License Extended Successfully!
          </h2>
          <p className="mt-2 max-w-md text-sm text-[#5f6663]">
            Your existing license key is now active until{" "}
            <strong className="text-emerald-800">{formatDate(success.newExpiry)}</strong>.
          </p>

          <div className="mt-8 w-full max-w-md rounded-xl border border-[#dfe3e1] bg-[#f8fafc] p-5 text-left">
            <h3 className="text-xs font-bold uppercase tracking-wider text-[#004d40]">
              What to do next:
            </h3>
            <ol className="mt-3 space-y-2.5 text-xs leading-5 text-[#334155]">
              <li className="flex items-start gap-2">
                <span className="grid size-5 shrink-0 place-items-center rounded-full bg-[#004d40] text-[10px] font-bold text-white">
                  1
                </span>
                <span>
                  <strong>No new key is needed!</strong> Your current key and all local bills/data remain untouched.
                </span>
              </li>
              <li className="flex items-start gap-2">
                <span className="grid size-5 shrink-0 place-items-center rounded-full bg-[#004d40] text-[10px] font-bold text-white">
                  2
                </span>
                <span>
                  Open your <strong>AV Smartbilling mobile app</strong> or desktop software.
                </span>
              </li>
              <li className="flex items-start gap-2">
                <span className="grid size-5 shrink-0 place-items-center rounded-full bg-[#004d40] text-[10px] font-bold text-white">
                  3
                </span>
                <span>
                  Click <strong>&ldquo;Refresh License&rdquo;</strong> (or simply restart the app) to sync the new expiry date immediately.
                </span>
              </li>
            </ol>
          </div>

          <Link
            href="/"
            className="mt-8 inline-flex h-11 items-center justify-center rounded-xl bg-[#004d40] px-8 text-xs font-bold uppercase tracking-wider text-white shadow transition hover:bg-[#00382f]"
          >
            Back to Home
          </Link>
        </div>
      </div>
    );
  }

  // 2. Loading Screen
  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center rounded-2xl border border-[#dfe3e1] bg-white p-12 text-center shadow-sm">
        <LoaderCircle size={36} className="animate-spin text-[#004d40]" />
        <p className="mt-4 text-sm font-semibold text-[#171b36]">
          Loading your license details securely…
        </p>
      </div>
    );
  }

  // 3. License Found -> Show Renewal Review & Payment
  if (details) {
    const projectedExpiry = calculateNewExpiry(details.expiresAt, details.planInterval);

    return (
      <div className="space-y-6">
        <div className="overflow-hidden rounded-2xl border border-[#dfe3e1] bg-white shadow-lg">
          {/* Header */}
          <div className="border-b border-[#dfe3e1] bg-[#f4fbfa] px-6 py-5 sm:flex sm:items-center sm:justify-between">
            <div className="flex items-center gap-3">
              <div className="grid size-12 place-items-center rounded-xl bg-[#004d40] text-white">
                <Store size={22} />
              </div>
              <div>
                <h2 className="text-lg font-bold text-[#171b36] sm:text-xl">
                  {details.companyName}
                </h2>
                <p className="text-xs text-[#5f6663]">
                  Licensed to {details.contactPerson} ({details.phoneMasked})
                </p>
              </div>
            </div>
            <div className="mt-3 sm:mt-0">
              <span className="inline-flex items-center rounded-full border border-amber-200 bg-amber-50 px-3 py-1 text-xs font-bold uppercase tracking-wider text-amber-800">
                {details.planName}
              </span>
            </div>
          </div>

          {/* Details body */}
          <div className="p-6">
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="rounded-xl border border-[#e2e8f0] bg-[#f8fafc] p-4">
                <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-[#64748b]">
                  <Clock size={15} /> Current Status
                </div>
                <div className="mt-2 text-sm font-semibold text-[#171b36]">
                  {details.isExpired ? (
                    <span className="text-rose-600">Expired on {formatDate(details.expiresAt)}</span>
                  ) : (
                    <span>
                      Expires in <strong className="text-amber-700">{details.daysRemaining} days</strong> ({formatDate(details.expiresAt)})
                    </span>
                  )}
                </div>
                <p className="mt-1 text-[11px] text-[#64748b]">
                  License Key: {details.licenseKeyHint}
                </p>
              </div>

              <div className="rounded-xl border border-emerald-200 bg-emerald-50/60 p-4">
                <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-emerald-800">
                  <Sparkles size={15} /> Extended Expiry (After Renewal)
                </div>
                <div className="mt-2 text-base font-extrabold text-emerald-900">
                  {formatDate(projectedExpiry)}
                </div>
                <p className="mt-1 text-[11px] text-emerald-700">
                  +1 {details.planInterval.toLowerCase()} added without losing any remaining days
                </p>
              </div>
            </div>

            {/* Inclusions */}
            <div className="mt-6 border-t border-[#e2e8f0] pt-4">
              <h4 className="text-xs font-bold uppercase tracking-wider text-[#64748b]">
                Included in your renewal
              </h4>
              <ul className="mt-3 grid gap-2 text-xs text-[#334155] sm:grid-cols-3">
                <li className="flex items-center gap-1.5">
                  <CheckCircle2 size={14} className="text-[#004d40]" />
                  <span>Up to {details.maxDevices} device{details.maxDevices === 1 ? "" : "s"}</span>
                </li>
                <li className="flex items-center gap-1.5">
                  <CheckCircle2 size={14} className="text-[#004d40]" />
                  <span>{details.allowCloudBackup ? "Cloud backup active" : "Offline billing"}</span>
                </li>
                <li className="flex items-center gap-1.5">
                  <CheckCircle2 size={14} className="text-[#004d40]" />
                  <span>{details.allowReportsExports ? "Reports & Excel/PDF export" : "Standard billing"}</span>
                </li>
              </ul>
            </div>

            {/* Error Message */}
            {message ? (
              <div className="mt-5 rounded-xl border border-rose-200 bg-rose-50 p-3 text-xs font-semibold text-rose-700">
                {message}
              </div>
            ) : null}

            {/* Action Buttons */}
            <div className="mt-6 flex flex-col-reverse gap-3 sm:flex-row sm:items-center sm:justify-between">
              <button
                type="button"
                onClick={() => {
                  setDetails(null);
                  setToken(undefined);
                }}
                disabled={paying}
                className="text-xs font-bold text-[#64748b] hover:text-[#171b36]"
              >
                ← Look up a different license
              </button>

              <button
                type="button"
                onClick={handlePay}
                disabled={paying}
                className="inline-flex h-12 items-center justify-center gap-2 rounded-xl bg-[#004d40] px-8 text-sm font-bold uppercase tracking-wider text-white shadow-md transition hover:bg-[#00382f] disabled:opacity-60"
              >
                {paying ? (
                  <>
                    <LoaderCircle size={18} className="animate-spin" />
                    <span>Processing…</span>
                  </>
                ) : details.priceInPaise === 0 ? (
                  <>
                    <Sparkles size={18} />
                    <span>Renew Plan (Free)</span>
                  </>
                ) : (
                  <>
                    <CreditCard size={18} />
                    <span>Pay {formatMoney(details.priceInPaise)} &amp; Renew</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>

        <div className="flex items-center justify-center gap-2 text-center text-xs text-[#64748b]">
          <ShieldCheck size={16} className="text-[#004d40]" />
          <span>
            Secured by Razorpay. Accepts UPI, Google Pay, PhonePe, Paytm, Cards, and Netbanking.
          </span>
        </div>
      </div>
    );
  }

  // 4. Default View: Look up License
  return (
    <div className="mx-auto max-w-xl">
      <div className="rounded-2xl border border-[#dfe3e1] bg-white p-6 shadow-md sm:p-8">
        <div className="flex items-center gap-3">
          <div className="grid size-10 place-items-center rounded-xl bg-[#004d40]/10 text-[#004d40]">
            <KeyRound size={20} />
          </div>
          <div>
            <h2 className="text-lg font-bold text-[#171b36]">
              Find Your License
            </h2>
            <p className="text-xs text-[#5f6663]">
              Enter your license key or registered mobile number to fetch your renewal details.
            </p>
          </div>
        </div>

        <div className="mt-6 flex rounded-xl border border-[#dfe3e1] bg-[#f8fafc] p-1 text-xs font-bold">
          <button
            type="button"
            onClick={() => {
              setLookupMode("KEY");
              setMessage("");
            }}
            className={`flex-1 rounded-lg py-2 transition ${
              lookupMode === "KEY"
                ? "bg-white text-[#004d40] shadow-sm"
                : "text-[#64748b] hover:text-[#171b36]"
            }`}
          >
            License Key
          </button>
          <button
            type="button"
            onClick={() => {
              setLookupMode("PHONE");
              setMessage("");
            }}
            className={`flex-1 rounded-lg py-2 transition ${
              lookupMode === "PHONE"
                ? "bg-white text-[#004d40] shadow-sm"
                : "text-[#64748b] hover:text-[#171b36]"
            }`}
          >
            Registered Phone
          </button>
        </div>

        <form noValidate onSubmit={handleManualLookup} className="mt-5 space-y-4">
          {lookupMode === "KEY" ? (
            <div>
              <label
                htmlFor="license-key-input"
                className="block text-xs font-bold uppercase tracking-wider text-[#334155]"
              >
                Activation / License Key
              </label>
              <div className="relative mt-1.5">
                <input
                  id="license-key-input"
                  name="renewalLicenseKey"
                  type={showKey ? "text" : "password"}
                  value={inputKey}
                  onChange={(e) => {
                    setInputKey(e.target.value.toUpperCase().trimStart());
                    setMessage("");
                  }}
                  placeholder="e.g. 8GYP-YGEB-2DKR-ANM5"
                  autoComplete="off"
                  spellCheck={false}
                  className="h-11 w-full rounded-xl border border-[#dfe3e1] bg-white px-3.5 pr-10 font-mono text-sm uppercase tracking-wider text-[#171b36] outline-none transition focus:border-[#004d40] focus:ring-1 focus:ring-[#004d40]"
                />
                <button
                  type="button"
                  onClick={() => setShowKey(!showKey)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-[#64748b] hover:text-[#171b36]"
                >
                  {showKey ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
              <p className="mt-1.5 text-[11px] text-[#64748b]">
                Enter your 16-character key (with or without dashes). You can find this in your app under Settings → License.
              </p>
            </div>
          ) : (
            <div>
              <label
                htmlFor="phone-input"
                className="block text-xs font-bold uppercase tracking-wider text-[#334155]"
              >
                Registered 10-Digit Mobile Number
              </label>
              <div className="mt-1.5">
                <input
                  id="phone-input"
                  name="renewalCustomerPhone"
                  type="text"
                  inputMode="numeric"
                  value={inputPhone}
                  onChange={(e) => {
                    setInputPhone(e.target.value);
                    setMessage("");
                  }}
                  placeholder="e.g. 9089786756"
                  className="h-11 w-full rounded-xl border border-[#dfe3e1] bg-white px-3.5 text-sm font-semibold tracking-wider text-[#171b36] outline-none transition focus:border-[#004d40] focus:ring-1 focus:ring-[#004d40]"
                />
              </div>
              <p className="mt-1.5 text-[11px] text-[#64748b]">
                Enter the mobile number provided during initial activation.
              </p>
            </div>
          )}

          {message ? (
            <div className="rounded-xl border border-rose-200 bg-rose-50 p-3 text-xs font-semibold text-rose-700">
              {message}
            </div>
          ) : null}

          <button
            type="submit"
            disabled={loading}
            className="flex h-11 w-full items-center justify-center gap-2 rounded-xl bg-[#004d40] text-xs font-bold uppercase tracking-wider text-white shadow transition hover:bg-[#00382f] disabled:opacity-60"
          >
            {loading ? (
              <LoaderCircle size={16} className="animate-spin" />
            ) : (
              <Search size={16} />
            )}
            <span>Find License Details</span>
          </button>
        </form>
      </div>

      <div className="mt-6 rounded-xl border border-dashed border-[#cbd5e1] p-4 text-center text-xs text-[#64748b]">
        Are you a new customer without a license yet?{" "}
        <Link href="/subscribe" className="font-bold text-[#004d40] hover:underline">
          Purchase a new activation key here →
        </Link>
      </div>
    </div>
  );
}
