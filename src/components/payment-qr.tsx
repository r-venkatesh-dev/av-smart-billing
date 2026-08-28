"use client";

import { useActionState, useEffect, useState } from "react";
import { useFormStatus } from "react-dom";
import { useRouter } from "next/navigation";
import { ImageUp, QrCode, Trash2 } from "lucide-react";
import { removeBillingPaymentQr, updateBillingPaymentQr, type BillingFormState } from "@/app/billing/actions";

const initialState: BillingFormState = {};

export function PaymentQrPreview({ url, size = "large" }: { url: string; size?: "compact" | "small" | "large" }) {
  const sizeClass = size === "large" ? "size-[220px]" : size === "small" ? "size-[156px]" : "size-[132px]";
  return <div role="img" aria-label="Shop UPI payment QR code" className={`mx-auto border border-[#dfe3e1] bg-white bg-contain bg-center bg-no-repeat ${sizeClass}`} style={{ backgroundImage: `url("${url.replaceAll('"', "%22")}")` }} />;
}

function UploadButton({ replacing }: { replacing: boolean }) {
  const { pending } = useFormStatus();
  return <button disabled={pending} className="focus-ring inline-flex min-h-11 items-center justify-center gap-2 bg-[#057c73] px-5 text-[10px] font-bold uppercase tracking-[.1em] text-white disabled:opacity-50"><ImageUp size={16} />{pending ? "Uploading…" : replacing ? "Replace QR code" : "Upload QR code"}</button>;
}

function RemoveButton() {
  const { pending } = useFormStatus();
  return <button disabled={pending} className="focus-ring inline-flex min-h-11 items-center justify-center gap-2 border border-rose-200 px-5 text-[10px] font-bold uppercase tracking-[.1em] text-rose-700 disabled:opacity-50"><Trash2 size={15} />{pending ? "Removing…" : "Remove"}</button>;
}

export function PaymentQrSettings({ paymentQrUrl }: { paymentQrUrl: string }) {
  const router = useRouter();
  const [uploadState, uploadAction] = useActionState(updateBillingPaymentQr, initialState);
  const [removeState, removeAction] = useActionState(removeBillingPaymentQr, initialState);
  const [filename, setFilename] = useState("");

  useEffect(() => {
    if (uploadState.success || removeState.success) router.refresh();
  }, [removeState.success, router, uploadState.success]);

  const state = uploadState.message ? uploadState : removeState;
  return <section className="surface p-6">
    <div className="flex items-start gap-3"><span className="grid size-10 shrink-0 place-items-center bg-[#e6f2f0] text-[#057c73]"><QrCode size={21} /></span><div><h2 className="text-xl">Shop payment QR code</h2><p className="mt-1 text-sm leading-6 text-[#6d716f]">Upload the shop owner&apos;s UPI QR code. It will be shown when UPI / QR Code is selected during payment.</p></div></div>
    <div className={`mt-6 grid gap-6 ${paymentQrUrl ? "lg:grid-cols-[250px_1fr] lg:items-center" : ""}`}>
      {paymentQrUrl ? <PaymentQrPreview url={paymentQrUrl} /> : <div className="grid min-h-44 place-items-center border border-dashed border-[#bddbd7] bg-[#f7fbfa] p-6 text-center"><div><QrCode size={35} className="mx-auto text-[#8fc5c0]" /><p className="mt-3 text-sm font-semibold">No payment QR uploaded</p><p className="mt-1 text-xs text-[#6d716f]">PNG, JPG or WebP · maximum 1 MB</p></div></div>}
      <div><form action={uploadAction} className="space-y-4"><label className="block"><span className="mb-2 block text-sm font-semibold">QR code image</span><input name="paymentQr" type="file" required accept="image/png,image/jpeg,image/webp" onChange={(event) => setFilename(event.target.files?.[0]?.name ?? "")} className="focus-ring block w-full border border-[#dfe3e1] bg-white p-2 text-xs file:mr-3 file:border-0 file:bg-[#e6f2f0] file:px-3 file:py-2 file:text-[10px] file:font-bold file:uppercase file:tracking-[.08em] file:text-[#057c73]" /><span className="mt-2 block text-xs text-[#8a908d]">{filename || "Choose a clear image containing only your payment QR code."}</span></label><UploadButton replacing={Boolean(paymentQrUrl)} /></form>{paymentQrUrl ? <form action={removeAction} className="mt-3"><RemoveButton /></form> : null}</div>
    </div>
    {state.message ? <p role="status" className={`mt-5 border-l-2 p-3 text-sm ${state.success ? "border-[#057c73] bg-[#e6f2f0] text-[#035f58]" : "border-rose-500 bg-rose-50 text-rose-700"}`}>{state.message}</p> : null}
  </section>;
}
