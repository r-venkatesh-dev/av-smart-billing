"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Check, CheckCircle2, Copy, CreditCard, LoaderCircle, ShieldCheck } from "lucide-react";

type Plan = { id: string; name: string; description: string; maxDevices: number; validationWindowDays: number; priceInPaise: number; interval: "MONTH" | "YEAR" };
type Details = { companyName: string; contactPerson: string; email: string; phone: string; gstin: string; address: string };
type RazorpayResponse = { razorpay_order_id: string; razorpay_payment_id: string; razorpay_signature: string };
type RazorpayFailure = { error?: { code?: string; description?: string; source?: string; step?: string; reason?: string; metadata?: { order_id?: string; payment_id?: string } } };
type Checkout = { open(): void; on(event: "payment.failed", callback: (response: RazorpayFailure) => void): void };

declare global {
  interface Window {
    Razorpay?: new (options: Record<string, unknown>) => Checkout;
  }
}

const emptyDetails: Details = { companyName: "", contactPerson: "", email: "", phone: "", gstin: "", address: "" };

function formatMoney(paise: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 2 }).format(paise / 100);
}

async function loadRazorpay() {
  if (window.Razorpay) return true;
  return new Promise<boolean>((resolve) => {
    const existing = document.querySelector<HTMLScriptElement>('script[src="https://checkout.razorpay.com/v1/checkout.js"]');
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

export function SubscriptionCheckout({ plans, plansUnavailable }: { plans: Plan[]; plansUnavailable: boolean }) {
  const router = useRouter();
  const [step, setStep] = useState<"DETAILS" | "PLAN" | "SUCCESS">("DETAILS");
  const [details, setDetails] = useState<Details>(emptyDetails);
  const [selectedPlanId, setSelectedPlanId] = useState(plans[0]?.id ?? "");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [licenseKey, setLicenseKey] = useState("");
  const [copied, setCopied] = useState(false);
  const selectedPlan = useMemo(() => plans.find((plan) => plan.id === selectedPlanId), [plans, selectedPlanId]);

  useEffect(() => {
    if (!licenseKey) return;
    const warn = (event: BeforeUnloadEvent) => { event.preventDefault(); event.returnValue = ""; };
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [licenseKey]);

  function update(field: keyof Details, value: string) {
    setDetails((current) => ({ ...current, [field]: field === "gstin" ? value.toUpperCase() : value }));
  }

  async function recordFailure(payload: Record<string, unknown>) {
    await fetch("/api/subscriptions/failure", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload), keepalive: true }).catch(() => null);
  }

  async function pay() {
    if (!selectedPlan) return;
    setBusy(true);
    setMessage("");
    try {
      if (!await loadRazorpay() || !window.Razorpay) throw new Error("Unable to load Razorpay. Check your internet connection and try again.");
      const orderResponse = await fetch("/api/subscriptions/order", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ...details, planId: selectedPlan.id }),
      });
      const order = await orderResponse.json() as Record<string, unknown>;
      if (!orderResponse.ok) throw new Error(String(order.message ?? "Unable to start payment."));
      let paymentCompleted = false;
      const checkout = new window.Razorpay({
        key: order.keyId,
        amount: order.amount,
        currency: order.currency,
        name: "AV Smartbilling",
        description: `${order.planName} activation plan`,
        order_id: order.razorpayOrderId,
        prefill: order.prefill,
        notes: { subscription_order_id: order.subscriptionOrderId },
        theme: { color: "#057c73" },
        modal: {
          confirm_close: true,
          ondismiss: () => {
            if (!paymentCompleted) void recordFailure({ subscriptionOrderId: order.subscriptionOrderId, razorpayOrderId: order.razorpayOrderId, cancelled: true });
            setBusy(false);
          },
        },
        handler: async (response: RazorpayResponse) => {
          paymentCompleted = true;
          setMessage("Payment received. Creating your activation key…");
          try {
            const verification = await fetch("/api/subscriptions/verify", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ subscriptionOrderId: order.subscriptionOrderId, razorpayOrderId: response.razorpay_order_id, razorpayPaymentId: response.razorpay_payment_id, razorpaySignature: response.razorpay_signature }),
            });
            const result = await verification.json() as { message?: string; licenseKey?: string };
            if (!verification.ok || !result.licenseKey) {
              setMessage(result.message ?? "Payment needs manual verification. Please contact support and do not pay again.");
              setBusy(false);
              return;
            }
            setLicenseKey(result.licenseKey);
            setStep("SUCCESS");
            setMessage("");
          } catch {
            setMessage("Payment was received, but verification was interrupted. Please contact support and do not pay again.");
          } finally {
            setBusy(false);
          }
        },
      });
      checkout.on("payment.failed", (response) => {
        paymentCompleted = true;
        const error = response.error ?? {};
        void recordFailure({ subscriptionOrderId: order.subscriptionOrderId, razorpayOrderId: error.metadata?.order_id ?? order.razorpayOrderId, razorpayPaymentId: error.metadata?.payment_id, error, cancelled: false });
        setMessage(error.description ?? "Payment failed. You can try again safely.");
        setBusy(false);
      });
      checkout.open();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Unable to start payment.");
      setBusy(false);
    }
  }

  async function copyKey() {
    try {
      await navigator.clipboard.writeText(licenseKey);
      setCopied(true);
    } catch {
      setMessage("Copy was blocked by the browser. Select the key and copy it manually.");
    }
  }

  function finish() {
    if (window.confirm("Did you copy and save the activation key? You cannot view it again after leaving this page.")) {
      setLicenseKey("");
      router.push("/products");
    }
  }

  if (step === "SUCCESS") return <section className="mx-auto max-w-2xl border border-emerald-300 bg-white p-6 shadow-sm sm:p-9"><div className="flex items-start gap-4"><span className="grid size-12 shrink-0 place-items-center bg-emerald-50 text-emerald-700"><CheckCircle2 size={26} /></span><div><p className="text-[11px] font-bold uppercase tracking-[.16em] text-emerald-700">Payment successful</p><h2 className="mt-1 text-3xl">Your activation key is ready</h2></div></div><div className="mt-7 border border-amber-300 bg-amber-50 p-5"><p className="text-sm font-bold text-amber-900">One-time view — copy this key now.</p><p className="mt-1 text-xs leading-5 text-amber-800">After you close or leave this page, the full key cannot be shown again.</p><code className="mt-5 block select-all break-all text-center font-mono text-2xl font-black tracking-[.08em] text-[#26272a] sm:text-3xl">{licenseKey}</code><button type="button" onClick={copyKey} className="mt-5 flex h-12 w-full items-center justify-center gap-2 bg-[#057c73] text-xs font-bold uppercase tracking-[.1em] text-white"><Copy size={17} />{copied ? "Copied to clipboard" : "Copy activation key"}</button></div>{message ? <p className="mt-4 bg-amber-50 p-3 text-sm text-amber-900">{message}</p> : null}<button type="button" onClick={finish} className="mt-5 h-12 w-full border border-[#057c73] text-xs font-bold uppercase tracking-[.1em] text-[#035f58]">I saved the key — continue</button></section>;

  return <section className="grid gap-7 lg:grid-cols-[1fr_320px]">
    <div className="border border-[#dfe3e1] bg-white p-5 sm:p-8">
      <div className="mb-7 flex items-center gap-3 text-xs font-bold uppercase tracking-[.1em]"><span className={`grid size-7 place-items-center rounded-full ${step === "DETAILS" ? "bg-[#057c73] text-white" : "bg-emerald-50 text-emerald-700"}`}>{step === "DETAILS" ? "1" : <Check size={15} />}</span><span>Shop details</span><span className="h-px flex-1 bg-[#dfe3e1]" /><span className={`grid size-7 place-items-center rounded-full ${step === "PLAN" ? "bg-[#057c73] text-white" : "bg-[#edf0ef] text-[#6d716f]"}`}>2</span><span>Choose plan</span></div>
      {step === "DETAILS" ? <form onSubmit={(event) => { event.preventDefault(); setMessage(""); setStep("PLAN"); }} className="grid gap-5 sm:grid-cols-2">
        <Field label="Shop / business name" value={details.companyName} onChange={(value) => update("companyName", value)} minLength={2} required />
        <Field label="Contact person" value={details.contactPerson} onChange={(value) => update("contactPerson", value)} minLength={2} required />
        <Field label="Mobile number" value={details.phone} onChange={(value) => update("phone", value.replace(/\D/g, "").slice(0, 10))} pattern="[6-9][0-9]{9}" inputMode="numeric" required />
        <Field label="Email address" value={details.email} onChange={(value) => update("email", value)} type="email" required />
        <Field label="GSTIN (optional)" value={details.gstin} onChange={(value) => update("gstin", value.slice(0, 15))} pattern="[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]" />
        <label className="sm:col-span-2"><span className="mb-2 block text-xs font-semibold text-[#475467]">Business address</span><textarea value={details.address} onChange={(event) => update("address", event.target.value)} required minLength={5} maxLength={500} rows={4} className="focus-ring w-full border border-[#dfe3e1] bg-white px-3 py-3 text-sm" /></label>
        <button type="submit" className="h-12 bg-[#057c73] px-6 text-xs font-bold uppercase tracking-[.1em] text-white sm:col-span-2">Proceed to choose plan</button>
      </form> : <div><div className="grid gap-4 sm:grid-cols-2">{plans.map((plan) => <button type="button" key={plan.id} onClick={() => setSelectedPlanId(plan.id)} className={`relative border p-5 text-left transition ${selectedPlanId === plan.id ? "border-[#057c73] bg-[#e6f2f0] ring-1 ring-[#057c73]" : "border-[#dfe3e1] hover:border-[#8a908d]"}`}><span className="block text-xl font-bold">{plan.name}</span><span className="mt-2 block text-sm leading-6 text-[#6d716f]">{plan.description}</span><strong className="mt-5 block text-2xl">{formatMoney(plan.priceInPaise)} <small className="text-xs font-normal text-[#6d716f]">/ {plan.interval.toLowerCase()}</small></strong><span className="mt-3 block text-xs text-[#475467]">{plan.maxDevices} device{plan.maxDevices === 1 ? "" : "s"} · {plan.validationWindowDays}-day offline validation</span>{selectedPlanId === plan.id ? <CheckCircle2 className="absolute right-4 top-4 text-[#057c73]" size={20} /> : null}</button>)}</div>{plansUnavailable ? <p className="mt-4 bg-rose-50 p-3 text-sm text-rose-700">Plans are temporarily unavailable. Please try again later.</p> : !plans.length ? <p className="mt-4 bg-amber-50 p-3 text-sm text-amber-800">No online purchase plan is currently available.</p> : null}{message ? <p className="mt-4 bg-amber-50 p-3 text-sm leading-6 text-amber-900">{message}</p> : null}<div className="mt-6 flex flex-col-reverse gap-3 sm:flex-row sm:justify-between"><button type="button" onClick={() => setStep("DETAILS")} disabled={busy} className="h-12 border border-[#dfe3e1] px-6 text-xs font-bold uppercase tracking-[.1em]">Back</button><button type="button" onClick={pay} disabled={busy || !selectedPlan} className="flex h-12 items-center justify-center gap-2 bg-[#057c73] px-7 text-xs font-bold uppercase tracking-[.1em] text-white disabled:opacity-50">{busy ? <LoaderCircle className="animate-spin" size={17} /> : <CreditCard size={17} />}{busy ? "Please wait…" : "Pay securely"}</button></div></div>}
    </div>
    <aside className="h-fit border border-[#dfe3e1] bg-white p-6"><ShieldCheck size={24} className="text-[#057c73]" /><h2 className="mt-4 text-xl">Secure purchase</h2><ul className="mt-5 space-y-3 text-xs leading-5 text-[#6d716f]"><li className="flex gap-2"><Check size={15} className="mt-0.5 shrink-0 text-[#057c73]" />Razorpay securely handles payment details.</li><li className="flex gap-2"><Check size={15} className="mt-0.5 shrink-0 text-[#057c73]" />The server verifies the order, amount, and captured payment.</li><li className="flex gap-2"><Check size={15} className="mt-0.5 shrink-0 text-[#057c73]" />Your license is issued only after verification.</li></ul>{selectedPlan ? <div className="mt-6 border-t border-[#dfe3e1] pt-5"><span className="text-xs text-[#6d716f]">Selected plan</span><strong className="mt-1 block">{selectedPlan.name}</strong><span className="mt-1 block text-lg font-bold">{formatMoney(selectedPlan.priceInPaise)}</span></div> : null}</aside>
  </section>;
}

function Field({ label, value, onChange, ...props }: { label: string; value: string; onChange: (value: string) => void } & Omit<React.InputHTMLAttributes<HTMLInputElement>, "value" | "onChange">) {
  return <label><span className="mb-2 block text-xs font-semibold text-[#475467]">{label}</span><input {...props} value={value} onChange={(event) => onChange(event.target.value)} className="focus-ring h-12 w-full border border-[#dfe3e1] bg-white px-3 text-sm" /></label>;
}
