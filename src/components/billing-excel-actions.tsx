"use client";

import { useRef, useState, useTransition } from "react";
import { Download, FileSpreadsheet, Loader2, Upload } from "lucide-react";
import writeXlsxFile, { type SheetData } from "write-excel-file/browser";
import readXlsxFile from "read-excel-file/browser";
import {
  bulkImportBillingProducts,
  bulkImportBillingCustomers,
  type BulkProductImportRow,
  type BulkCustomerImportRow,
} from "@/app/billing/actions";

export type ExportProductItem = {
  name: string;
  sku: string;
  barcode: string | null;
  category: string;
  unit: string;
  purchasePriceInPaise: number;
  priceInPaise: number;
  taxRateBasisPoints: number;
  stockQuantity: number;
  status: string;
};

export type ExportCustomerItem = {
  name: string;
  phone: string;
  email: string | null;
  gstin: string | null;
  address: string;
  status: string;
};

type Props =
  | {
      type: "products";
      items: ExportProductItem[];
      label?: string;
    }
  | {
      type: "customers";
      items: ExportCustomerItem[];
      label?: string;
    };

function cellString(cell: unknown): string {
  if (cell === null || cell === undefined) return "";
  return String(cell).trim();
}

function cellNumber(cell: unknown): number | null {
  if (cell === null || cell === undefined || cell === "") return null;
  const num = Number(cell);
  return isNaN(num) ? null : num;
}

export function BillingExcelActions(props: Props) {
  const [pending, startTransition] = useTransition();
  const [feedback, setFeedback] = useState<{ ok: boolean; message: string } | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // 1. DOWNLOAD TEMPLATE
  async function downloadTemplate() {
    setFeedback(null);
    try {
      if (props.type === "products") {
        const sheetData: SheetData = [
          [
            { value: "Product Name *", fontWeight: "bold" },
            { value: "Price (Rs) *", fontWeight: "bold" },
            { value: "Stock Quantity *", fontWeight: "bold" },
            { value: "Selling Unit *", fontWeight: "bold" },
            { value: "SKU", fontWeight: "bold" },
            { value: "Barcode", fontWeight: "bold" },
            { value: "GST Rate (%)", fontWeight: "bold" },
            { value: "Discount (%)", fontWeight: "bold" },
          ],
          [
            { value: "Apple Shimla", type: String },
            { value: 120.0, type: Number },
            { value: 50, type: Number },
            { value: "kg", type: String },
            { value: "APP-001", type: String },
            { value: "8901234567890", type: String },
            { value: 0, type: Number },
            { value: 5, type: Number },
          ],
          [
            { value: "Full Cream Milk 500ml", type: String },
            { value: 34.0, type: Number },
            { value: 100, type: Number },
            { value: "packet", type: String },
            { value: "MLK-002", type: String },
            { value: "", type: String },
            { value: 0, type: Number },
            { value: 0, type: Number },
          ],
          [
            { value: "Ballpoint Blue Pen", type: String },
            { value: 10.0, type: Number },
            { value: 200, type: Number },
            { value: "pcs", type: String },
            { value: "PEN-003", type: String },
            { value: "8909876543210", type: String },
            { value: 18, type: Number },
            { value: 0, type: Number },
          ],
        ];
        await writeXlsxFile(sheetData).toFile("products_template.xlsx");
      } else {
        const sheetData: SheetData = [
          [
            { value: "Customer Name *", fontWeight: "bold" },
            { value: "Phone Number", fontWeight: "bold" },
            { value: "GSTIN", fontWeight: "bold" },
            { value: "Address", fontWeight: "bold" },
            { value: "Email", fontWeight: "bold" },
          ],
          [
            { value: "Rajesh Kumar", type: String },
            { value: "9876543210", type: String },
            { value: "33AAAAA0000A1Z5", type: String },
            { value: "123 MG Road, Bengaluru", type: String },
            { value: "rajesh@example.com", type: String },
          ],
          [
            { value: "Priya Sharma", type: String },
            { value: "9123456780", type: String },
            { value: "", type: String },
            { value: "45 Park Street, Chennai", type: String },
            { value: "", type: String },
          ],
          [
            { value: "Sai Traders", type: String },
            { value: "8765432109", type: String },
            { value: "27BBBBB1111B2Z6", type: String },
            { value: "Shop 4, Market Complex, Pune", type: String },
            { value: "saitraders@example.com", type: String },
          ],
        ];
        await writeXlsxFile(sheetData).toFile("customers_template.xlsx");
      }
    } catch (err: unknown) {
      setFeedback({
        ok: false,
        message: `Failed to download template: ${err instanceof Error ? err.message : String(err)}`,
      });
    }
  }

  // 2. EXPORT EXCEL
  async function exportExcel() {
    setFeedback(null);
    try {
      if (props.type === "products") {
        const sheetData: SheetData = [
          [
            { value: "Product Name", fontWeight: "bold" },
            { value: "Price (Rs)", fontWeight: "bold" },
            { value: "Stock Quantity", fontWeight: "bold" },
            { value: "Selling Unit", fontWeight: "bold" },
            { value: "SKU", fontWeight: "bold" },
            { value: "Barcode", fontWeight: "bold" },
            { value: "GST Rate (%)", fontWeight: "bold" },
            { value: "Category", fontWeight: "bold" },
            { value: "Status", fontWeight: "bold" },
          ],
          ...props.items.map((p) => [
            { value: p.name || "", type: String },
            { value: Number((p.priceInPaise / 100).toFixed(2)), type: Number },
            { value: Number(p.stockQuantity || 0), type: Number },
            { value: p.unit || "unit", type: String },
            { value: p.sku || "", type: String },
            { value: p.barcode || "", type: String },
            { value: Number(((p.taxRateBasisPoints || 0) / 100).toFixed(2)), type: Number },
            { value: p.category || "", type: String },
            { value: p.status === "ACTIVE" ? "Active" : "Inactive", type: String },
          ]),
        ];
        await writeXlsxFile(sheetData).toFile(`products_${new Date().toISOString().split("T")[0]}.xlsx`);
      } else {
        const sheetData: SheetData = [
          [
            { value: "Customer Name", fontWeight: "bold" },
            { value: "Phone Number", fontWeight: "bold" },
            { value: "GSTIN", fontWeight: "bold" },
            { value: "Address", fontWeight: "bold" },
            { value: "Email", fontWeight: "bold" },
            { value: "Status", fontWeight: "bold" },
          ],
          ...props.items.map((c) => [
            { value: c.name || "", type: String },
            { value: c.phone || "", type: String },
            { value: c.gstin || "", type: String },
            { value: c.address || "", type: String },
            { value: c.email || "", type: String },
            { value: c.status === "ACTIVE" ? "Active" : "Inactive", type: String },
          ]),
        ];
        await writeXlsxFile(sheetData).toFile(`customers_${new Date().toISOString().split("T")[0]}.xlsx`);
      }
    } catch (err: unknown) {
      setFeedback({
        ok: false,
        message: `Failed to export Excel: ${err instanceof Error ? err.message : String(err)}`,
      });
    }
  }

  // 3. IMPORT EXCEL
  async function handleFileSelected(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    event.target.value = "";
    setFeedback(null);

    startTransition(async () => {
      try {
        const sheets = await readXlsxFile(file);
        if (!sheets || !sheets.length || !sheets[0]?.data?.length) {
          setFeedback({ ok: false, message: "The selected Excel file is empty." });
          return;
        }

        const rawRows = sheets[0].data;

        // Header detection
        let headerRowIndex = -1;
        const headerMap: Record<string, number> = {};

        for (let r = 0; r < rawRows.length; r++) {
          const row = rawRows[r];
          if (!row) continue;
          const colNames = row.map((c: unknown) => cellString(c).toLowerCase().trim());
          if (
            props.type === "products"
              ? colNames.some((c: string) => c.includes("product") || c.includes("name") || c.includes("item"))
              : colNames.some((c: string) => c.includes("customer") || c.includes("name") || c.includes("phone"))
          ) {
            headerRowIndex = r;
            for (let c = 0; c < colNames.length; c++) {
              const col = colNames[c];
              if (!col) continue;
              if (props.type === "products") {
                if (col.includes("name") || col === "product" || col === "item" || col.includes("title")) {
                  if (headerMap.name === undefined) headerMap.name = c;
                } else if (col.includes("price") || col.includes("rate") || col.includes("mrp")) {
                  if (headerMap.price === undefined) headerMap.price = c;
                } else if (col.includes("stock") || col.includes("qty") || col.includes("quantity")) {
                  if (headerMap.stock === undefined) headerMap.stock = c;
                } else if (col.includes("unit") || col === "uom") {
                  if (headerMap.unit === undefined) headerMap.unit = c;
                } else if (col.includes("sku") || col === "code") {
                  if (headerMap.sku === undefined) headerMap.sku = c;
                } else if (col.includes("barcode") || col.includes("bar code") || col === "upc" || col === "ean") {
                  if (headerMap.barcode === undefined) headerMap.barcode = c;
                } else if (col.includes("gst") || col.includes("tax")) {
                  if (headerMap.tax === undefined) headerMap.tax = c;
                } else if (col.includes("category") || col.includes("dept")) {
                  if (headerMap.category === undefined) headerMap.category = c;
                }
              } else {
                if (col.includes("name") || col === "customer" || col.includes("client")) {
                  if (headerMap.name === undefined) headerMap.name = c;
                } else if (col.includes("phone") || col.includes("mobile") || col.includes("contact")) {
                  if (headerMap.phone === undefined) headerMap.phone = c;
                } else if (col.includes("gst") || col.includes("tax")) {
                  if (headerMap.gstin === undefined) headerMap.gstin = c;
                } else if (col.includes("address") || col.includes("location")) {
                  if (headerMap.address === undefined) headerMap.address = c;
                } else if (col.includes("email") || col.includes("mail")) {
                  if (headerMap.email === undefined) headerMap.email = c;
                }
              }
            }
            break;
          }
        }

        if (headerRowIndex === -1 || headerMap.name === undefined) {
          setFeedback({
            ok: false,
            message: "Could not find valid column headers in the Excel file. Please use the downloadable template.",
          });
          return;
        }

        if (props.type === "products") {
          const parsedProducts: BulkProductImportRow[] = [];
          for (let r = headerRowIndex + 1; r < rawRows.length; r++) {
            const row = rawRows[r];
            if (!row || row.every((c: unknown) => cellString(c) === "")) continue;
            const name = headerMap.name !== undefined ? cellString(row[headerMap.name]) : "";
            if (!name) continue;
            const price = headerMap.price !== undefined ? (cellNumber(row[headerMap.price]) ?? 0) : 0;
            const stockQuantity = headerMap.stock !== undefined ? (cellNumber(row[headerMap.stock]) ?? 0) : 0;
            const unit = headerMap.unit !== undefined ? cellString(row[headerMap.unit]) : "pcs";
            const sku = headerMap.sku !== undefined ? cellString(row[headerMap.sku]) : "";
            const barcode = headerMap.barcode !== undefined ? cellString(row[headerMap.barcode]) : "";
            const taxRate = headerMap.tax !== undefined ? (cellNumber(row[headerMap.tax]) ?? 0) : 0;
            const category = headerMap.category !== undefined ? cellString(row[headerMap.category]) : "General";

            parsedProducts.push({
              name,
              price,
              stockQuantity,
              unit: unit || "pcs",
              sku,
              barcode,
              taxRate,
              category: category || "General",
            });
          }

          if (!parsedProducts.length) {
            setFeedback({ ok: false, message: "No product data rows found in the Excel file." });
            return;
          }

          const res = await bulkImportBillingProducts(parsedProducts);
          if (res.ok) {
            setFeedback({
              ok: true,
              message: `Products imported: ${res.added} added, ${res.updated} updated${res.errors.length ? ` (${res.errors.length} warnings)` : ""}.`,
            });
          } else {
            setFeedback({
              ok: false,
              message: res.errors[0] || "Failed to import products.",
            });
          }
        } else {
          const parsedCustomers: BulkCustomerImportRow[] = [];
          for (let r = headerRowIndex + 1; r < rawRows.length; r++) {
            const row = rawRows[r];
            if (!row || row.every((c: unknown) => cellString(c) === "")) continue;
            const name = headerMap.name !== undefined ? cellString(row[headerMap.name]) : "";
            if (!name) continue;
            const phone = headerMap.phone !== undefined ? cellString(row[headerMap.phone]) : "";
            const gstin = headerMap.gstin !== undefined ? cellString(row[headerMap.gstin]) : "";
            const address = headerMap.address !== undefined ? cellString(row[headerMap.address]) : "";
            const email = headerMap.email !== undefined ? cellString(row[headerMap.email]) : "";

            parsedCustomers.push({ name, phone, gstin, address, email });
          }

          if (!parsedCustomers.length) {
            setFeedback({ ok: false, message: "No customer data rows found in the Excel file." });
            return;
          }

          const res = await bulkImportBillingCustomers(parsedCustomers);
          if (res.ok) {
            setFeedback({
              ok: true,
              message: `Customers imported: ${res.added} added, ${res.updated} updated${res.errors.length ? ` (${res.errors.length} warnings)` : ""}.`,
            });
          } else {
            setFeedback({
              ok: false,
              message: res.errors[0] || "Failed to import customers.",
            });
          }
        }
      } catch (err: unknown) {
        setFeedback({
          ok: false,
          message: `Error processing Excel file: ${err instanceof Error ? err.message : String(err)}`,
        });
      }
    });
  }

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center gap-2">
        <input
          ref={fileInputRef}
          type="file"
          accept=".xlsx"
          onChange={handleFileSelected}
          className="hidden"
        />

        <button
          type="button"
          onClick={downloadTemplate}
          className="focus-ring inline-flex h-9 items-center gap-1.5 rounded-xl border border-[#dfe3eb] bg-white px-3 text-xs font-semibold text-[#344054] shadow-sm transition hover:bg-[#f9fafb]"
          title="Download sample Excel template"
        >
          <FileSpreadsheet size={15} className="text-[#057c73]" />
          <span>Template</span>
        </button>

        <button
          type="button"
          disabled={pending}
          onClick={() => fileInputRef.current?.click()}
          className="focus-ring inline-flex h-9 items-center gap-1.5 rounded-xl border border-[#dfe3eb] bg-white px-3 text-xs font-semibold text-[#344054] shadow-sm transition hover:bg-[#f9fafb] disabled:opacity-50"
          title="Import records from Excel spreadsheet"
        >
          {pending ? (
            <Loader2 size={15} className="animate-spin text-[#057c73]" />
          ) : (
            <Upload size={15} className="text-[#057c73]" />
          )}
          <span>{pending ? "Importing…" : "Import Excel"}</span>
        </button>

        <button
          type="button"
          onClick={exportExcel}
          className="focus-ring inline-flex h-9 items-center gap-1.5 rounded-xl border border-[#dfe3eb] bg-white px-3 text-xs font-semibold text-[#344054] shadow-sm transition hover:bg-[#f9fafb]"
          title="Export current list to Excel"
        >
          <Download size={15} className="text-[#057c73]" />
          <span>Export Excel</span>
        </button>
      </div>

      {feedback ? (
        <div
          role="status"
          className={`flex items-center justify-between gap-3 rounded-xl border px-4 py-2.5 text-xs font-medium transition ${
            feedback.ok
              ? "border-[#bddbd7] bg-[#e6f2f0] text-[#035f58]"
              : "border-rose-200 bg-rose-50 text-rose-800"
          }`}
        >
          <span>{feedback.message}</span>
          <button
            type="button"
            onClick={() => setFeedback(null)}
            className="text-[11px] font-bold uppercase underline"
          >
            Dismiss
          </button>
        </div>
      ) : null}
    </div>
  );
}
