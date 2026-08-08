import { LoaderCircle } from "lucide-react";

export function RouteLoading() {
  return <div className="relative min-h-[65vh]" role="status" aria-live="polite" aria-label="Loading page content">
    <div className="screen-only fixed inset-x-0 top-0 z-[99] h-1 overflow-hidden bg-[#d7e5e2]"><div className="route-progress h-full bg-[#057c73]" /></div>
    <div className="mb-7 flex items-center gap-3"><LoaderCircle size={20} className="animate-spin text-[#057c73]" /><div><p className="text-sm font-semibold">Loading page…</p><p className="mt-0.5 text-xs text-[#8a908d]">Fetching the latest data from Supabase</p></div></div>
    <div className="animate-pulse space-y-6" aria-hidden="true">
      <div className="space-y-3"><div className="h-3 w-28 bg-[#dfe3e1]" /><div className="h-9 w-64 max-w-full bg-[#e8ebe9]" /><div className="h-4 w-[430px] max-w-full bg-[#eef0ef]" /></div>
      <div className="grid gap-4 sm:grid-cols-3"><div className="surface h-28 bg-white" /><div className="surface h-28 bg-white" /><div className="surface h-28 bg-white" /></div>
      <div className="surface overflow-hidden bg-white"><div className="h-12 border-b border-[#dfe3e1] bg-[#f1f3f2]" /><div className="space-y-4 p-6"><div className="h-5 w-full bg-[#eef0ef]" /><div className="h-5 w-11/12 bg-[#eef0ef]" /><div className="h-5 w-4/5 bg-[#eef0ef]" /><div className="h-5 w-3/4 bg-[#eef0ef]" /></div></div>
    </div>
  </div>;
}
