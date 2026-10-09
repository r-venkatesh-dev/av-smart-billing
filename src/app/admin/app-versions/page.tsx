import { Smartphone, Apple, CheckCircle2, AlertCircle, ArrowUpRight } from "lucide-react";
import {
  CreateVersionButton,
  EditVersionButton,
  DeleteVersionButton,
  ToggleActiveButton,
} from "@/components/app-version-dialogs";
import { listAppVersions } from "@/data/admin";
import { formatDate } from "@/lib/format";

export const metadata = { title: "Mobile App Versions" };

export default async function AppVersionsPage() {
  const versions = await listAppVersions();

  const activeAndroid = versions.filter(
    (v) => v.platform === "android" && v.isActive,
  );
  const activeIos = versions.filter((v) => v.platform === "ios" && v.isActive);
  const maxBuild = versions.reduce(
    (acc, v) => Math.max(acc, v.latestBuildNumber),
    0,
  );

  return (
    <div className="space-y-7">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <span className="text-[11px] font-bold uppercase tracking-[.18em] text-[#057c73]">
            Release Management
          </span>
          <h1 className="font-serif text-2xl font-bold tracking-tight text-[#111322] sm:text-3xl">
            Mobile App Versions
          </h1>
          <p className="mt-1 text-sm text-[#667085]">
            Manage Android and iOS release numbers, force-update thresholds, and update links directly in Supabase without manual SQL queries.
          </p>
        </div>
        <CreateVersionButton />
      </div>

      {/* KPI Cards */}
      <div className="grid gap-4 sm:grid-cols-4">
        <div className="surface p-5">
          <div className="flex items-center justify-between text-[#667085]">
            <span className="text-xs font-semibold uppercase tracking-wider">
              Total Releases
            </span>
            <span className="grid size-8 place-items-center rounded-lg bg-teal-50 text-[#057c73]">
              <Smartphone size={16} />
            </span>
          </div>
          <strong className="mt-2 block text-2xl font-bold text-[#101828]">
            {versions.length}
          </strong>
          <span className="text-[11px] text-[#667085]">Stored in database</span>
        </div>

        <div className="surface p-5">
          <div className="flex items-center justify-between text-[#667085]">
            <span className="text-xs font-semibold uppercase tracking-wider">
              Active Android
            </span>
            <span className="grid size-8 place-items-center rounded-lg bg-emerald-50 text-emerald-600">
              <CheckCircle2 size={16} />
            </span>
          </div>
          <strong className="mt-2 block text-2xl font-bold text-emerald-600">
            {activeAndroid[0]?.latestVersion || "—"}
          </strong>
          <span className="text-[11px] text-[#667085]">
            {activeAndroid[0]
              ? `Build #${activeAndroid[0].latestBuildNumber} active`
              : "No active Android build"}
          </span>
        </div>

        <div className="surface p-5">
          <div className="flex items-center justify-between text-[#667085]">
            <span className="text-xs font-semibold uppercase tracking-wider">
              Active iOS
            </span>
            <span className="grid size-8 place-items-center rounded-lg bg-indigo-50 text-indigo-600">
              <Apple size={16} />
            </span>
          </div>
          <strong className="mt-2 block text-2xl font-bold text-indigo-600">
            {activeIos[0]?.latestVersion || "—"}
          </strong>
          <span className="text-[11px] text-[#667085]">
            {activeIos[0]
              ? `Build #${activeIos[0].latestBuildNumber} active`
              : "No active iOS build"}
          </span>
        </div>

        <div className="surface p-5">
          <div className="flex items-center justify-between text-[#667085]">
            <span className="text-xs font-semibold uppercase tracking-wider">
              Highest Build #
            </span>
            <span className="grid size-8 place-items-center rounded-lg bg-amber-50 text-amber-600">
              <AlertCircle size={16} />
            </span>
          </div>
          <strong className="mt-2 block text-2xl font-bold text-amber-600">
            {maxBuild || 0}
          </strong>
          <span className="text-[11px] text-[#667085]">Current release ceiling</span>
        </div>
      </div>

      {/* Versions Table */}
      <div className="surface overflow-hidden rounded-2xl border border-[#eaecf0] shadow-sm">
        <div className="border-b border-[#eaecf0] bg-[#fafbfc] px-6 py-4">
          <h2 className="text-sm font-bold text-[#101828]">All App Releases</h2>
          <p className="text-xs text-[#667085]">
            When the mobile app starts up, it requests{" "}
            <code className="rounded bg-slate-100 px-1 py-0.5 text-[#057c73]">
              /api/mobile/version?platform=...
            </code>{" "}
            and receives the latest active version.
          </p>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full min-w-[950px] text-left text-sm">
            <thead className="bg-[#f8f9fc] text-[11px] font-bold uppercase tracking-wider text-[#667085]">
              <tr>
                <th className="px-6 py-3.5">Platform</th>
                <th className="px-6 py-3.5">Version & Build</th>
                <th className="px-6 py-3.5">Min Required</th>
                <th className="px-6 py-3.5">Release Notes</th>
                <th className="px-6 py-3.5">Update Link</th>
                <th className="px-6 py-3.5">Status</th>
                <th className="px-6 py-3.5">Updated</th>
                <th className="px-6 py-3.5 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#eaecf0]">
              {versions.map((item) => (
                <tr key={item.id} className="transition hover:bg-[#fafbff]">
                  <td className="px-6 py-4">
                    <span className="inline-flex items-center gap-2 font-bold capitalize text-[#344054]">
                      {item.platform === "ios" ? (
                        <span className="grid size-7 place-items-center rounded-lg bg-slate-100 text-slate-800">
                          <Apple size={15} />
                        </span>
                      ) : (
                        <span className="grid size-7 place-items-center rounded-lg bg-emerald-50 text-emerald-600">
                          <Smartphone size={15} />
                        </span>
                      )}
                      {item.platform}
                    </span>
                  </td>

                  <td className="px-6 py-4">
                    <span className="block font-bold text-[#101828]">
                      v{item.latestVersion}
                    </span>
                    <span className="font-mono text-xs text-[#667085]">
                      Build #{item.latestBuildNumber}
                    </span>
                  </td>

                  <td className="px-6 py-4">
                    <span className="inline-flex items-center gap-1.5 rounded-md bg-slate-100 px-2 py-0.5 font-mono text-xs font-semibold text-slate-700">
                      Build #{item.minRequiredBuild}
                    </span>
                    {item.minRequiredBuild >= item.latestBuildNumber ? (
                      <span className="mt-1 block text-[10px] font-bold uppercase text-amber-600">
                        Force update
                      </span>
                    ) : (
                      <span className="mt-1 block text-[10px] text-[#98a2b3]">
                        Optional update
                      </span>
                    )}
                  </td>

                  <td className="max-w-[280px] px-6 py-4 text-xs text-[#475467]">
                    <p className="line-clamp-2" title={item.releaseNotes}>
                      {item.releaseNotes || "—"}
                    </p>
                  </td>

                  <td className="px-6 py-4">
                    <a
                      href={item.updateUrl}
                      target="_blank"
                      rel="noreferrer"
                      className="inline-flex max-w-[200px] items-center gap-1 truncate text-xs font-semibold text-[#057c73] hover:underline"
                      title={item.updateUrl}
                    >
                      <span className="truncate">{item.updateUrl}</span>
                      <ArrowUpRight size={13} className="shrink-0" />
                    </a>
                  </td>

                  <td className="px-6 py-4">
                    <ToggleActiveButton item={item} />
                  </td>

                  <td className="px-6 py-4 text-xs text-[#667085]">
                    {formatDate(item.updatedAt || item.createdAt)}
                  </td>

                  <td className="px-6 py-4 text-right">
                    <div className="flex items-center justify-end gap-1">
                      <EditVersionButton item={item} />
                      <DeleteVersionButton item={item} />
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {!versions.length ? (
          <div className="p-12 text-center text-sm text-[#667085]">
            <Smartphone className="mx-auto mb-3 size-10 text-[#d0d5dd]" />
            <p className="font-semibold text-[#344054]">No app versions in database.</p>
            <p className="mt-1 text-xs">
              Click &quot;New App Version&quot; above to create the initial release entry.
            </p>
          </div>
        ) : null}
      </div>
    </div>
  );
}
