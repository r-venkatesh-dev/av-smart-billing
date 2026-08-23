import Link from "next/link";
import {
  ArrowUpRight,
  Building2,
  CalendarClock,
  KeyRound,
  MonitorSmartphone,
  TrendingUp,
  TriangleAlert,
} from "lucide-react";
import { StatusBadge } from "@/components/ui";
import { getAdminDashboard } from "@/data/admin";
import { getCurrentAdmin } from "@/lib/auth/authorization";
import { formatDate } from "@/lib/format";

export const metadata = { title: "Admin dashboard" };

export default async function AdminDashboardPage() {
  const [dashboard, profile] = await Promise.all([
    getAdminDashboard(),
    getCurrentAdmin(),
  ]);
  const metrics = [
    {
      label: "Total customers",
      value: dashboard.customerCount,
      hint: `${dashboard.newCustomersThisMonth} this month`,
      icon: Building2,
      tone: "bg-indigo-50 text-indigo-600",
    },
    {
      label: "Active licenses",
      value: dashboard.activeLicenseCount,
      hint: "currently valid",
      icon: KeyRound,
      tone: "bg-emerald-50 text-emerald-600",
    },
    {
      label: "Active devices",
      value: dashboard.activeDeviceCount,
      hint: "activated",
      icon: MonitorSmartphone,
      tone: "bg-sky-50 text-sky-600",
    },
    {
      label: "Expiring soon",
      value: dashboard.expiringCount,
      hint: "within 30 days",
      icon: CalendarClock,
      tone: "bg-amber-50 text-amber-600",
    },
  ];
  const maxGrowth = Math.max(
    1,
    ...dashboard.months.flatMap((month) => [month.licenses, month.customers]),
  );
  const today = new Intl.DateTimeFormat("en-IN", {
    weekday: "long",
    day: "numeric",
    month: "long",
  }).format(new Date());
  return (
    <div className="space-y-7">
      <div>
        <p className="mb-1.5 text-xs font-bold uppercase tracking-[.16em] text-[#7b71e8]">
          {today}
        </p>
        <h1 className="text-3xl font-normal tracking-[-.035em] sm:text-[36px]">
          Welcome, {profile?.fullName ?? "Administrator"}
        </h1>
        <p className="mt-1.5 text-sm text-[#667085]">
          Live activity across your Supabase license data.
        </p>
      </div>
      <section
        className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4"
        aria-label="Platform metrics"
      >
        {metrics.map(({ label, value, hint, icon: Icon, tone }) => (
          <article key={label} className="surface p-5">
            <div
              className={`grid size-10 place-items-center rounded-xl ${tone}`}
            >
              <Icon size={20} />
            </div>
            <p className="mt-5 text-sm font-medium text-[#667085]">{label}</p>
            <div className="mt-1 flex items-end justify-between gap-2">
              <strong className="text-[28px] tracking-[-.04em]">{value}</strong>
              <span className="mb-1 text-xs text-[#98a2b3]">{hint}</span>
            </div>
          </article>
        ))}
      </section>
      <div className="grid gap-5 xl:grid-cols-[1.45fr_.75fr]">
        <section className="surface overflow-hidden">
          <div className="border-b border-[#eaecf0] px-6 py-4">
            <h2 className="font-bold">Six-month growth</h2>
            <p className="mt-0.5 text-xs text-[#98a2b3]">
              Licenses and customers created
            </p>
          </div>
          <div className="p-6">
            <div className="mb-5 flex items-center gap-4 text-xs">
              <span className="flex items-center gap-2 text-[#667085]">
                <i className="size-2 rounded-full bg-[#5b4df5]" />
                Licenses
              </span>
              <span className="flex items-center gap-2 text-[#667085]">
                <i className="size-2 rounded-full bg-[#d2ceff]" />
                Customers
              </span>
            </div>
            <div className="flex h-56 items-end justify-between gap-3 border-b border-[#e6e9f0] px-2">
              {dashboard.months.map((month) => (
                <div
                  className="relative flex h-full flex-1 items-end justify-center gap-1"
                  key={month.key}
                >
                  <div
                    style={{
                      height: `${Math.max(2, (month.licenses / maxGrowth) * 100)}%`,
                    }}
                    className="w-[38%] max-w-8 rounded-t-md bg-[#5b4df5]"
                    title={`${month.licenses} licenses`}
                  />
                  <div
                    style={{
                      height: `${Math.max(2, (month.customers / maxGrowth) * 100)}%`,
                    }}
                    className="w-[38%] max-w-8 rounded-t-md bg-[#d2ceff]"
                    title={`${month.customers} customers`}
                  />
                  <span className="absolute -bottom-6 text-[10px] font-medium text-[#98a2b3]">
                    {month.label}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </section>
        <section className="surface p-6">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="font-bold">License attention</h2>
              <p className="mt-0.5 text-xs text-[#98a2b3]">
                Current database state
              </p>
            </div>
            <TrendingUp className="text-[#5b4df5]" size={20} />
          </div>
          <strong className="mt-8 block text-5xl font-normal">
            {dashboard.expiringCount}
          </strong>
          <p className="mt-2 text-sm text-[#667085]">
            licenses expire within 30 days.
          </p>
          {dashboard.expiringCount ? (
            <div className="mt-5 flex gap-2 rounded-xl bg-amber-50 p-3 text-xs leading-5 text-amber-800">
              <TriangleAlert className="mt-0.5 shrink-0" size={15} />
              Review these licenses before customer access is interrupted.
            </div>
          ) : null}
        </section>
      </div>
      <section className="surface overflow-hidden">
        <div className="flex items-center justify-between border-b border-[#eaecf0] px-6 py-4">
          <div>
            <h2 className="font-bold">Recent licenses</h2>
            <p className="mt-0.5 text-xs text-[#98a2b3]">
              Latest records from Supabase
            </p>
          </div>
          <Link
            href="/admin/licenses"
            className="text-xs font-bold text-[#5b4df5]"
          >
            View all
          </Link>
        </div>
        {dashboard.recentLicenses.length ? (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[760px] text-left text-sm">
              <thead className="bg-[#fafbfc] text-[11px] uppercase tracking-wide text-[#98a2b3]">
                <tr>
                  {["Customer", "Plan", "Devices", "Expires", "Status", ""].map(
                    (heading) => (
                      <th key={heading} className="px-6 py-3 font-semibold">
                        {heading}
                      </th>
                    ),
                  )}
                </tr>
              </thead>
              <tbody className="divide-y divide-[#eef0f4]">
                {dashboard.recentLicenses.map((license) => (
                  <tr key={license.id}>
                    <td className="px-6 py-4">
                      <strong className="block text-sm">
                        {license.customerName}
                      </strong>
                      <span className="font-mono text-[11px] text-[#98a2b3]">
                        {license.maskedKey}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-[#667085]">
                      {license.planName}
                    </td>
                    <td className="px-6 py-4 text-[#667085]">
                      {license.activeDevices}/{license.maxDevices}
                    </td>
                    <td className="px-6 py-4 text-[#667085]">
                      {formatDate(license.expiresAt)}
                    </td>
                    <td className="px-6 py-4">
                      <StatusBadge status={license.status} />
                    </td>
                    <td className="px-6 py-4">
                      <Link
                        href={`/admin/licenses/${license.id}`}
                        aria-label={`View ${license.customerName}`}
                      >
                        <ArrowUpRight size={16} />
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="p-10 text-center text-sm text-[#667085]">
            No licenses are stored in Supabase.
          </p>
        )}
      </section>
    </div>
  );
}
