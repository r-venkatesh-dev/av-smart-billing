"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState, type ReactNode } from "react";
import { Boxes, Building2, CircleDollarSign, FileBarChart, FileText, KeyRound, LayoutDashboard, LogOut, Menu, MonitorSmartphone, Package, ReceiptIndianRupee, ScanBarcode, Settings, Users, WalletCards, Warehouse, X } from "lucide-react";
import { logout } from "@/app/login/actions";
import { GlobalSearch } from "@/components/global-search";
import { NavigationFeedback } from "@/components/navigation-feedback";
import { SessionStatus } from "@/components/session-status";

type NavItem = { label: string; href: string; icon: typeof LayoutDashboard };

const adminNav: NavItem[] = [
  { label: "Overview", href: "/admin/dashboard", icon: LayoutDashboard },
  { label: "Customers", href: "/admin/customers", icon: Building2 },
  { label: "Licenses", href: "/admin/licenses", icon: KeyRound },
  { label: "Devices", href: "/admin/devices", icon: MonitorSmartphone },
  { label: "Plans", href: "/admin/plans", icon: WalletCards },
  { label: "Subscriptions", href: "/admin/subscriptions", icon: CircleDollarSign },
  { label: "Settings", href: "/admin/settings", icon: Settings },
];

const billingNav: NavItem[] = [
  { label: "Dashboard", href: "/billing/dashboard", icon: LayoutDashboard },
  { label: "Quick POS", href: "/billing/pos", icon: ScanBarcode },
  { label: "Customers", href: "/billing/customers", icon: Users },
  { label: "Products", href: "/billing/products", icon: Package },
  { label: "Inventory", href: "/billing/inventory", icon: Warehouse },
  { label: "Invoices", href: "/billing/invoices", icon: FileText },
  { label: "Payments", href: "/billing/payments", icon: CircleDollarSign },
  { label: "Reports", href: "/billing/reports", icon: FileBarChart },
  { label: "Settings", href: "/billing/settings", icon: Settings },
];

export function AppShell({ mode, children, user }: { mode: "admin" | "billing"; children: ReactNode; user?: { fullName: string; role: string } }) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const items = mode === "admin" ? adminNav : billingNav;
  const productName = mode === "admin" ? "Control Center" : "Billing Desk";

  return (
    <div className="min-h-screen bg-[#f6f7fb]">
      <NavigationFeedback />
      {open ? <button aria-label="Close menu" className="fixed inset-0 z-30 bg-[#11152b]/50 backdrop-blur-[1px] lg:hidden" onClick={() => setOpen(false)} /> : null}
      <aside className={`app-shell-chrome fixed inset-y-0 left-0 z-40 flex w-[264px] flex-col bg-[#171b36] text-white transition-transform duration-200 lg:translate-x-0 ${open ? "translate-x-0" : "-translate-x-full"}`}>
        <div className="flex h-[76px] items-center justify-between border-b border-white/10 px-5">
          <Link href={mode === "admin" ? "/admin/dashboard" : "/billing/dashboard"} className="focus-ring flex items-center gap-3 rounded-lg">
            <span className="grid size-9 place-items-center rounded-xl bg-[#6f62ff]"><ReceiptIndianRupee size={20} strokeWidth={2} /></span>
            <span className="border-l border-white/35 pl-3"><strong className="block font-serif text-[17px] font-semibold tracking-wide">AV Smartbilling</strong><small className="block text-[9px] font-semibold uppercase tracking-[.18em] text-[#aaaed0]">{productName}</small></span>
          </Link>
          <button className="rounded-lg p-1.5 text-[#bfc3dc] hover:bg-white/10 lg:hidden" onClick={() => setOpen(false)}><X size={20} /></button>
        </div>
        <nav className="flex-1 space-y-1 overflow-y-auto px-3 py-5" aria-label="Main navigation">
          <p className="mb-3 px-3 text-[10px] font-bold uppercase tracking-[.18em] text-[#737998]">Workspace</p>
          {items.map((item) => {
            const active = pathname === item.href || pathname.startsWith(`${item.href}/`);
            const Icon = item.icon;
            return <Link key={item.href} href={item.href} onClick={() => setOpen(false)} className={`focus-ring flex h-11 items-center gap-3 rounded-xl border-l-2 px-3 text-xs font-semibold uppercase tracking-[.06em] transition ${active ? "border-[#057c73] bg-white/[.09] text-white" : "border-transparent text-[#b9bdd6] hover:bg-white/[.05] hover:text-white"}`}><Icon size={18} strokeWidth={active ? 2.2 : 1.8} />{item.label}</Link>;
          })}
        </nav>
        <div className="border-t border-white/10 p-4">
          {user?.role !== "LICENSED" ? <Link href={mode === "admin" ? "/billing/dashboard" : "/admin/dashboard"} className="focus-ring flex items-center gap-3 rounded-xl bg-white/[.06] p-3 text-xs font-semibold text-[#d6d8e8] transition hover:bg-white/10"><Boxes size={18} /><span>Switch to {mode === "admin" ? "Billing Desk" : "Control Center"}</span></Link> : <Link href="/activate" className="focus-ring flex items-center gap-3 bg-white/[.06] p-3 text-xs font-semibold text-[#d6d8e8]"><KeyRound size={18} /><span>License activation</span></Link>}
          {user && user.role !== "LICENSED" ? <form action={logout} className="mt-3"><button className="focus-ring flex w-full items-center gap-3 rounded-xl px-1 py-2 text-left hover:bg-white/[.05]" title="Sign out"><div className="grid size-9 place-items-center rounded-full bg-[#343a60] text-xs font-bold">{user.fullName.split(/\s+/).slice(0, 2).map((part) => part[0]).join("").toUpperCase()}</div><div className="min-w-0 flex-1"><p className="truncate text-xs font-semibold">{user.fullName}</p><p className="truncate text-[11px] capitalize text-[#858aa9]">{user.role.toLowerCase()}</p></div><LogOut aria-hidden="true" size={14} className="text-[#858aa9]" /></button></form> : user ? <div className="mt-3 flex items-center gap-3 px-1 py-2"><div className="grid size-9 place-items-center rounded-full bg-[#343a60] text-xs font-bold">{user.fullName.split(/\s+/).slice(0, 2).map((part) => part[0]).join("").toUpperCase()}</div><div className="min-w-0"><p className="truncate text-xs font-semibold">{user.fullName}</p><p className="text-[11px] text-[#858aa9]">Licensed customer</p></div></div> : null}
        </div>
      </aside>
      <div className="app-shell-body lg:pl-[264px]">
        <header className="app-shell-chrome sticky top-0 z-20 flex h-[76px] items-center justify-between border-b border-[#e6e9f0] bg-[#f7f8f7]/95 px-4 backdrop-blur-xl sm:px-7 lg:px-8">
          <div className="flex min-w-0 items-center gap-3"><button aria-label="Open navigation" onClick={() => setOpen(true)} className="focus-ring shrink-0 rounded-xl border border-[#e4e7ec] p-2 text-[#475467] lg:hidden"><Menu size={20} /></button><GlobalSearch mode={mode} /></div>
          <div className="ml-3 flex shrink-0 items-center gap-3"><span className="hidden items-center gap-1.5 rounded-full bg-emerald-50 px-3 py-1.5 text-xs font-semibold text-emerald-700 md:flex"><span className="size-1.5 rounded-full bg-emerald-500" />Secure session active</span><SessionStatus mode={mode} user={user} /></div>
        </header>
        <main className="app-shell-main page-enter mx-auto max-w-[1500px] p-4 sm:p-7 lg:p-8">{children}</main>
      </div>
    </div>
  );
}
