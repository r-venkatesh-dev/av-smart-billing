import Link from "next/link";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { ReceiptIndianRupee, ShieldCheck } from "lucide-react";
import { ActivationForm } from "@/app/activate/activation-form";
import { getLicensedSession } from "@/lib/billing-access";

export const metadata = { title: "Activate software" };

export default async function Page() {
  const desktop = (await headers()).get("x-avsb-desktop") === "1";
  if (desktop && await getLicensedSession()) redirect("/billing/dashboard");
  return <main className="min-h-screen bg-[#f7f8f7] px-5 py-10"><div className="mx-auto max-w-xl"><header className="mb-8 text-center"><span className="mx-auto grid size-12 place-items-center bg-[#057c73] text-white"><ReceiptIndianRupee size={24} /></span><p className="mt-5 text-[10px] font-bold uppercase tracking-[.2em] text-[#057c73]">AV Smartbilling</p><h1 className="mt-2 text-4xl">Activate this device</h1><p className="mt-3 text-sm leading-6 text-[#6d716f]">{desktop ? "Internet is required for first activation and periodic license validation." : "Browser activation simulator. Internet is required for first activation and periodic validation."}</p></header><ActivationForm /><Link href="/subscribe" className="mt-4 flex h-12 items-center justify-center border border-[#057c73] text-xs font-bold uppercase tracking-[.1em] text-[#035f58]">Get your activation key</Link><div className="mt-6 flex items-start gap-2 border border-[#dfe3e1] bg-white p-4 text-xs leading-5 text-[#6d716f]"><ShieldCheck size={17} className="mt-0.5 shrink-0 text-[#057c73]" />The license key and device identity are verified by server-only APIs. Signing credentials are never sent to the client.</div>{!desktop ? <p className="mt-6 text-center"><Link href="/login" className="text-xs font-bold text-[#057c73] hover:underline">Administrator sign in</Link></p> : null}</div></main>;
}
