import Link from "next/link";
import { Apple, ArrowRight, Check, Download, FileDown, HelpCircle, LockKeyhole, PackageCheck, ShieldCheck } from "lucide-react";
import { WindowsIcon } from "@/components/platform-icons";
import { PublicSite } from "@/components/public-site";
import { publicDownloads } from "@/lib/public-downloads";

export const metadata = { title: "Download AV Smartbilling" };

const benefits = ["Invoices and payment tracking", "Customers and inventory", "Business reports and exports"];
const steps = [
  { icon: FileDown, number: "01", title: "Download", description: "Choose the installer that matches your computer." },
  { icon: PackageCheck, number: "02", title: "Install", description: "Open the file and follow the installation prompts." },
  { icon: LockKeyhole, number: "03", title: "Activate", description: "Launch the app and enter your AV Smartbilling license key." },
];

function InstallerCard({ icon, platform, title, description, href, filename, primary = false }: { icon: React.ReactNode; platform: string; title: string; description: string; href: string; filename: string; primary?: boolean }) {
  return <article className={`flex h-full flex-col border bg-white p-6 transition hover:border-[#8fc5c0] hover:shadow-[0_12px_32px_rgba(38,39,42,.07)] ${primary ? "border-[#057c73]" : "border-[#dfe3e1]"}`}>
    <div className="flex items-start justify-between gap-4"><span className="grid size-12 place-items-center bg-[#e6f2f0] text-[#057c73]">{icon}</span>{primary ? <span className="bg-[#e6f2f0] px-2.5 py-1 text-[9px] font-bold uppercase tracking-[.1em] text-[#057c73]">Popular</span> : null}</div>
    <p className="mt-5 text-[10px] font-bold uppercase tracking-[.16em] text-[#057c73]">{platform}</p>
    <h2 className="mt-1 text-2xl">{title}</h2>
    <p className="mt-2 flex-1 text-sm leading-6 text-[#6d716f]">{description}</p>
    <a href={href} download className={`focus-ring mt-6 inline-flex min-h-12 items-center justify-center gap-2 px-5 text-[10px] font-bold uppercase tracking-[.1em] ${primary ? "bg-[#057c73] text-white hover:bg-[#035f58]" : "border border-[#057c73] text-[#057c73] hover:bg-[#e6f2f0]"}`}><Download size={17} />{filename}</a>
  </article>;
}

export default function DownloadsPage() {
  return <PublicSite>
    <section className="border-b border-[#dfe3e1] bg-white">
      <div className="mx-auto grid max-w-6xl gap-10 px-4 py-12 sm:px-5 sm:py-16 lg:grid-cols-[1.15fr_.85fr] lg:items-center">
        <div><div className="inline-flex items-center gap-2 border border-[#bddbd7] bg-[#e6f2f0] px-3 py-1.5 text-[10px] font-bold uppercase tracking-[.12em] text-[#057c73]"><ShieldCheck size={14} />Desktop version {publicDownloads.desktopVersion}</div><h1 className="mt-5 max-w-3xl text-4xl leading-[1.08] tracking-[-.04em] sm:text-5xl">Download AV Smartbilling for your computer.</h1><p className="mt-4 max-w-2xl text-base leading-7 text-[#6d716f]">A focused desktop workspace for faster billing, cleaner records, and dependable day-to-day business management.</p><a href="#installers" className="focus-ring mt-7 inline-flex min-h-12 items-center gap-2 bg-[#057c73] px-6 text-[10px] font-bold uppercase tracking-[.1em] text-white">Choose installer <ArrowRight size={16} /></a></div>
        <aside className="border border-[#dfe3e1] bg-[#f7f8f7] p-6 sm:p-8"><p className="text-[10px] font-bold uppercase tracking-[.16em] text-[#8a908d]">Included in the desktop app</p><ul className="mt-5 space-y-4">{benefits.map((benefit) => <li key={benefit} className="flex items-center gap-3 text-sm font-semibold"><span className="grid size-7 place-items-center bg-white text-[#057c73]"><Check size={15} /></span>{benefit}</li>)}</ul><div className="mt-6 border-t border-[#dfe3e1] pt-5 text-xs leading-5 text-[#6d716f]">Available for 64-bit Windows PCs and both Apple silicon and Intel-based Mac computers.</div></aside>
      </div>
    </section>

    <section id="installers" className="scroll-mt-4">
      <div className="mx-auto max-w-6xl px-4 py-12 sm:px-5 sm:py-16">
        <div className="max-w-2xl"><p className="text-[10px] font-bold uppercase tracking-[.18em] text-[#057c73]">Desktop installers</p><h2 className="mt-2 text-3xl tracking-[-.03em]">Select your operating system.</h2><p className="mt-2 text-sm leading-6 text-[#6d716f]">Not sure which Mac you have? Open the Apple menu and choose “About This Mac” to see whether the processor is Apple or Intel.</p></div>
        <div className="mt-8 grid gap-5 md:grid-cols-3"><InstallerCard primary icon={<WindowsIcon className="size-6" />} platform="Windows · 64-bit" title="Windows PC" description="For most Windows desktop and laptop computers." href={publicDownloads.windowsUrl} filename="Download .exe" /><InstallerCard icon={<Apple size={25} />} platform="macOS · ARM64" title="Apple silicon" description="For Mac computers with an M1, M2, M3, M4 or newer Apple chip." href={publicDownloads.macArm64Url} filename="Download .dmg" /><InstallerCard icon={<Apple size={25} />} platform="macOS · x64" title="Intel Mac" description="For older Mac computers powered by an Intel processor." href={publicDownloads.macX64Url} filename="Download .dmg" /></div>

        <section className="mt-14 border border-[#dfe3e1] bg-white p-6 sm:p-8"><div className="flex flex-col gap-8 lg:flex-row lg:items-start lg:justify-between"><div className="max-w-sm"><p className="text-[10px] font-bold uppercase tracking-[.16em] text-[#057c73]">Getting started</p><h2 className="mt-2 text-2xl">Install in three simple steps.</h2></div><ol className="grid flex-1 gap-7 sm:grid-cols-3 lg:max-w-3xl">{steps.map(({ icon: Icon, number, title, description }) => <li key={number}><span className="text-[10px] font-bold tracking-[.14em] text-[#8a908d]">{number}</span><Icon size={20} className="mt-3 text-[#057c73]" /><h3 className="mt-3 text-base">{title}</h3><p className="mt-1 text-xs leading-5 text-[#6d716f]">{description}</p></li>)}</ol></div></section>

        <div className="mt-6 flex flex-col gap-4 border border-[#bddbd7] bg-[#e6f2f0] p-5 sm:flex-row sm:items-center sm:justify-between"><div className="flex gap-3"><HelpCircle size={20} className="mt-0.5 shrink-0 text-[#057c73]" /><div><h2 className="text-base">Need help choosing or installing?</h2><p className="mt-1 text-xs leading-5 text-[#52605d]">Contact our support team and tell us which Windows or Mac computer you use.</p></div></div><Link href="/contact" className="focus-ring inline-flex shrink-0 items-center gap-2 text-[10px] font-bold uppercase tracking-[.1em] text-[#057c73]">Contact support <ArrowRight size={15} /></Link></div>
      </div>
    </section>
  </PublicSite>;
}
