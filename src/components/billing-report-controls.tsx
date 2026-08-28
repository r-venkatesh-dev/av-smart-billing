"use client";

import { Download, FileSpreadsheet, Printer, Search } from "lucide-react";
import { ThemedDatePicker } from "@/components/themed-controls";

interface ExportInvoice {
  invoiceNumber: string;
  customerName: string;
  issuedAt: string;
  status: string;
  subtotalInPaise: number;
  taxInPaise: number;
  totalInPaise: number;
}

function csvCell(value: string | number) {
  return `"${String(value).replaceAll('"', '""')}"`;
}

function downloadFile(contents: string, type: string, filename: string) {
  const url = URL.createObjectURL(new Blob([contents], { type }));
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

export function BillingReportControls({ from, to, invoices }: { from: string; to: string; invoices: ExportInvoice[] }) {
  const filename = `billing-report-${from}-to-${to}`;

  function exportCsv() {
    const headings = ["Invoice", "Customer", "Issued date", "Status", "Subtotal (INR)", "Tax (INR)", "Total (INR)"];
    const rows = invoices.map((invoice) => [invoice.invoiceNumber, invoice.customerName, invoice.issuedAt.slice(0, 10), invoice.status, (invoice.subtotalInPaise / 100).toFixed(2), (invoice.taxInPaise / 100).toFixed(2), (invoice.totalInPaise / 100).toFixed(2)]);
    downloadFile([headings, ...rows].map((row) => row.map(csvCell).join(",")).join("\n"), "text/csv;charset=utf-8", `${filename}.csv`);
  }

  function exportExcel() {
    const headings = ["Invoice", "Customer", "Issued date", "Status", "Subtotal (INR)", "Tax (INR)", "Total (INR)"];
    const rows = invoices.map((invoice) => [invoice.invoiceNumber, invoice.customerName, invoice.issuedAt.slice(0, 10), invoice.status, (invoice.subtotalInPaise / 100).toFixed(2), (invoice.taxInPaise / 100).toFixed(2), (invoice.totalInPaise / 100).toFixed(2)]);
    const escapeHtml = (value: string | number) => String(value).replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
    const table = `<table><thead><tr>${headings.map((heading) => `<th>${escapeHtml(heading)}</th>`).join("")}</tr></thead><tbody>${rows.map((row) => `<tr>${row.map((cell) => `<td>${escapeHtml(cell)}</td>`).join("")}</tr>`).join("")}</tbody></table>`;
    downloadFile(`<html><head><meta charset="UTF-8"></head><body>${table}</body></html>`, "application/vnd.ms-excel;charset=utf-8", `${filename}.xls`);
  }

  return <section className="screen-only surface p-5">
    <form method="get" className="grid gap-4 lg:grid-cols-[minmax(210px,1fr)_minmax(210px,1fr)_auto] lg:items-end">
      <ThemedDatePicker key={`from-${from}`} name="from" label="From date" defaultValue={from} disablePast={false} disableFuture required />
      <ThemedDatePicker key={`to-${to}`} name="to" label="To date" defaultValue={to} disablePast={false} disableFuture required />
      <button type="submit" className="focus-ring inline-flex h-11 items-center justify-center gap-2 bg-[#057c73] px-5 text-[10px] font-bold uppercase tracking-[.1em] text-white"><Search size={15} />Apply range</button>
    </form>
    <div className="mt-4 flex flex-wrap gap-2 border-t border-[#eef0f4] pt-4">
      <button type="button" onClick={exportCsv} disabled={!invoices.length} className="focus-ring inline-flex h-10 items-center gap-2 border border-[#dfe3e1] px-4 text-[10px] font-bold uppercase tracking-[.08em] text-[#057c73] disabled:cursor-not-allowed disabled:opacity-40"><Download size={15} />Download CSV</button>
      <button type="button" onClick={exportExcel} disabled={!invoices.length} className="focus-ring inline-flex h-10 items-center gap-2 border border-[#dfe3e1] px-4 text-[10px] font-bold uppercase tracking-[.08em] text-[#057c73] disabled:cursor-not-allowed disabled:opacity-40"><FileSpreadsheet size={15} />Download Excel</button>
      <button type="button" onClick={() => window.print()} className="focus-ring inline-flex h-10 items-center gap-2 border border-[#dfe3e1] px-4 text-[10px] font-bold uppercase tracking-[.08em] text-[#26272a]"><Printer size={15} />Print / Save PDF</button>
    </div>
  </section>;
}
