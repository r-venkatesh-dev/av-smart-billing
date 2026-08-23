import { Check, ShieldCheck } from "lucide-react";
import { LoginForm } from "@/app/login/login-form";
import { BrandLogo } from "@/components/brand-logo";

export const metadata = { title: "Sign in" };

export default async function LoginPage({ searchParams }: PageProps<"/login">) {
  const { reason, redirectTo } = await searchParams;
  return <main className="grid min-h-screen lg:grid-cols-[1.05fr_.95fr]">
    <section className="relative hidden overflow-hidden bg-[#171b36] p-12 text-white lg:flex lg:flex-col lg:justify-between">
      <div className="absolute -right-32 -top-32 size-[440px] rounded-full bg-[#057c73]/25 blur-3xl" /><div className="absolute -bottom-32 -left-20 size-[380px] rounded-full bg-[#556706]/15 blur-3xl" />
      <div className="relative flex items-center gap-3"><BrandLogo size={40} /><span className="text-xl font-bold">AV Smartbilling</span></div>
      <div className="relative max-w-xl"><p className="mb-5 text-xs font-bold uppercase tracking-[.22em] text-[#9189ff] before:mr-3 before:inline-block before:h-0.5 before:w-7 before:align-middle before:bg-current">Billing infrastructure, simplified</p><h1 className="text-5xl font-normal leading-[1.04] tracking-[-.04em]">One platform.<br /><em className="font-normal text-[#91a533]">Every business you serve.</em></h1><p className="mt-6 max-w-lg font-serif text-lg leading-8 text-[#b9bdd3]">Issue licenses, manage devices, and give every client a dependable billing workspace built to keep working offline.</p><div className="mt-10 grid gap-3 text-xs uppercase tracking-[.06em] text-[#d8d9e8] sm:grid-cols-2">{["Secure device activation", "Configurable business profiles", "Offline-ready billing", "Central license control"].map((item) => <span className="flex items-center gap-2" key={item}><span className="grid size-5 place-items-center rounded-full bg-white/10"><Check size={12} /></span>{item}</span>)}</div></div>
      <p className="relative text-xs text-[#7f849f]">© 2026 AV Smartbilling. Built for dependable commerce.</p>
    </section>
    <section className="flex items-center justify-center bg-[#f7f8f7] px-5 py-12 sm:px-10"><div className="w-full max-w-[410px]">
      <div className="mb-9 flex items-center gap-3 lg:hidden"><BrandLogo size={36} /><span className="text-lg font-bold">AV Smartbilling</span></div>
      <div className="mb-8"><span className="mb-5 grid size-11 place-items-center rounded-2xl bg-[#efedff] text-[#5b4df5]"><ShieldCheck size={22} /></span><h2 className="text-[34px] font-normal tracking-[-.03em]">Welcome back</h2><p className="mt-2 text-sm leading-6 text-[#667085]">Sign in to manage customers, licenses, and billing workspaces.</p></div>
      {reason === "session-required" ? <p className="mb-5 rounded-xl bg-amber-50 px-3 py-2.5 text-sm text-amber-800">Your session is missing or expired. Sign in to continue.</p> : null}
      {reason === "not-authorized" ? <p className="mb-5 rounded-xl bg-rose-50 px-3 py-2.5 text-sm text-rose-700">Your account does not have an active control-center profile.</p> : null}
      <LoginForm redirectTo={typeof redirectTo === "string" ? redirectTo : undefined} />
      <div className="mt-7 flex items-start gap-2 rounded-xl bg-[#f7f8fa] p-3 text-xs leading-5 text-[#667085]"><ShieldCheck size={16} className="mt-0.5 shrink-0 text-[#11966f]" />Credentials are verified by Supabase Auth. Access also requires an active control-center profile.</div>
    </div></section>
  </main>;
}
