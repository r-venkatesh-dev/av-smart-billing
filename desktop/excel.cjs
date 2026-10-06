/* eslint-disable @typescript-eslint/no-require-imports -- CommonJS module for Electron desktop */
const writeXlsx = require("write-excel-file/node");
const readXlsx = require("read-excel-file/node");

function cellString(cell) {
  if (cell === null || cell === undefined) return "";
  return String(cell).trim();
}

function cellNumber(cell) {
  if (cell === null || cell === undefined || cell === "") return null;
  const num = Number(cell);
  return isNaN(num) ? null : num;
}

// -----------------------------------------------------------------------------
// PRODUCTS: TEMPLATE, EXPORT & PARSING
// -----------------------------------------------------------------------------

async function generateProductsTemplate() {
  const headers = [
    { value: "Product Name *", fontWeight: "bold" },
    { value: "Price (Rs) *", fontWeight: "bold" },
    { value: "Stock Quantity *", fontWeight: "bold" },
    { value: "Selling Unit *", fontWeight: "bold" },
    { value: "SKU", fontWeight: "bold" },
    { value: "Barcode", fontWeight: "bold" },
    { value: "GST Rate (%)", fontWeight: "bold" },
    { value: "Discount (%)", fontWeight: "bold" },
  ];

  const sampleRows = [
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

  return writeXlsx([headers, ...sampleRows]).toBuffer();
}

async function generateProductsExport(products) {
  const headers = [
    { value: "Product Name", fontWeight: "bold" },
    { value: "Price (Rs)", fontWeight: "bold" },
    { value: "Stock Quantity", fontWeight: "bold" },
    { value: "Selling Unit", fontWeight: "bold" },
    { value: "SKU", fontWeight: "bold" },
    { value: "Barcode", fontWeight: "bold" },
    { value: "GST Rate (%)", fontWeight: "bold" },
    { value: "Discount (%)", fontWeight: "bold" },
    { value: "Status", fontWeight: "bold" },
  ];

  const rows = products.map((p) => [
    { value: p.name || "", type: String },
    { value: Number((p.price_in_paise / 100).toFixed(2)), type: Number },
    { value: Number(p.stock_quantity || 0), type: Number },
    { value: p.unit || "unit", type: String },
    { value: p.sku || "", type: String },
    { value: p.barcode || "", type: String },
    { value: Number(((p.tax_rate_basis_points || 0) / 100).toFixed(2)), type: Number },
    { value: Number(p.discount_percent || 0), type: Number },
    { value: p.status === "ACTIVE" ? "Active" : "Inactive", type: String },
  ]);

  return writeXlsx([headers, ...rows]).toBuffer();
}

async function parseProductsFile(filePathOrBuffer) {
  const sheets = await readXlsx(filePathOrBuffer);
  if (!sheets || !sheets.length || !sheets[0].data || !sheets[0].data.length) {
    throw new Error("The Excel sheet is empty or contains no valid worksheets.");
  }

  const rawRows = sheets[0].data;
  let headerRowIndex = -1;
  const headerMap = {};

  for (let r = 0; r < rawRows.length; r++) {
    const row = rawRows[r];
    const colNames = row.map(cellString).map((s) => s.toLowerCase().trim());
    if (colNames.some((c) => c.includes("product") || c.includes("name") || c.includes("item"))) {
      headerRowIndex = r;
      for (let c = 0; c < colNames.length; c++) {
        const col = colNames[c];
        if (!col) continue;
        if (col.includes("name") || col === "product" || col === "item" || col.includes("title")) {
          if (headerMap.name === undefined) headerMap.name = c;
        } else if (col.includes("price") || col.includes("rate") || col.includes("mrp")) {
          if (headerMap.price === undefined) headerMap.price = c;
        } else if (col.includes("stock") || col.includes("qty") || col.includes("quantity")) {
          if (headerMap.stock === undefined) headerMap.stock = c;
        } else if (col.includes("unit") || col === "uom") {
          if (headerMap.unit === undefined) headerMap.unit = c;
        } else if (col.includes("sku") || col === "code" || col.includes("item code")) {
          if (headerMap.sku === undefined) headerMap.sku = c;
        } else if (col.includes("barcode") || col.includes("bar code") || col === "upc" || col === "ean") {
          if (headerMap.barcode === undefined) headerMap.barcode = c;
        } else if (col.includes("gst") || col.includes("tax")) {
          if (headerMap.tax === undefined) headerMap.tax = c;
        } else if (col.includes("discount") || col.includes("disc")) {
          if (headerMap.discount === undefined) headerMap.discount = c;
        }
      }
      break;
    }
  }

  if (headerRowIndex === -1 || headerMap.name === undefined) {
    throw new Error("Could not find valid column headers in the Excel file. Please use the downloadable template.");
  }

  const items = [];
  for (let r = headerRowIndex + 1; r < rawRows.length; r++) {
    const row = rawRows[r];
    if (!row || row.every((c) => cellString(c) === "")) continue;

    const name = headerMap.name !== undefined ? cellString(row[headerMap.name]) : "";
    const price = headerMap.price !== undefined ? cellNumber(row[headerMap.price]) : null;
    const stockQuantity = headerMap.stock !== undefined ? cellNumber(row[headerMap.stock]) : null;
    const rawUnit = headerMap.unit !== undefined ? cellString(row[headerMap.unit]) : "";
    const sku = headerMap.sku !== undefined ? cellString(row[headerMap.sku]) : "";
    const barcode = headerMap.barcode !== undefined ? cellString(row[headerMap.barcode]) : "";
    const taxRate = headerMap.tax !== undefined ? (cellNumber(row[headerMap.tax]) ?? 0) : 0;
    const discount = headerMap.discount !== undefined ? (cellNumber(row[headerMap.discount]) ?? 0) : 0;

    items.push({
      rowNumber: r + 1,
      name,
      price,
      stockQuantity,
      unit: rawUnit || "pcs",
      sku,
      barcode,
      taxRate,
      discount,
    });
  }

  return items;
}

// -----------------------------------------------------------------------------
// CUSTOMERS: TEMPLATE, EXPORT & PARSING
// -----------------------------------------------------------------------------

async function generateCustomersTemplate() {
  const headers = [
    { value: "Customer Name *", fontWeight: "bold" },
    { value: "Phone Number", fontWeight: "bold" },
    { value: "GSTIN", fontWeight: "bold" },
    { value: "Address", fontWeight: "bold" },
  ];

  const sampleRows = [
    [
      { value: "Rajesh Kumar", type: String },
      { value: "9876543210", type: String },
      { value: "33AAAAA0000A1Z5", type: String },
      { value: "123 MG Road, Bengaluru", type: String },
    ],
    [
      { value: "Priya Sharma", type: String },
      { value: "9123456780", type: String },
      { value: "", type: String },
      { value: "45 Park Street, Chennai", type: String },
    ],
    [
      { value: "Sai Traders", type: String },
      { value: "8765432109", type: String },
      { value: "27BBBBB1111B2Z6", type: String },
      { value: "Shop 4, Market Complex, Pune", type: String },
    ],
  ];

  return writeXlsx([headers, ...sampleRows]).toBuffer();
}

async function generateCustomersExport(customers) {
  const headers = [
    { value: "Customer Name", fontWeight: "bold" },
    { value: "Phone Number", fontWeight: "bold" },
    { value: "GSTIN", fontWeight: "bold" },
    { value: "Address", fontWeight: "bold" },
  ];

  const rows = customers.map((c) => [
    { value: c.name || "", type: String },
    { value: c.phone || "", type: String },
    { value: c.gstin || "", type: String },
    { value: c.address || "", type: String },
  ]);

  return writeXlsx([headers, ...rows]).toBuffer();
}

async function parseCustomersFile(filePathOrBuffer) {
  const sheets = await readXlsx(filePathOrBuffer);
  if (!sheets || !sheets.length || !sheets[0].data || !sheets[0].data.length) {
    throw new Error("The Excel sheet is empty or contains no valid worksheets.");
  }

  const rawRows = sheets[0].data;
  let headerRowIndex = -1;
  const headerMap = {};

  for (let r = 0; r < rawRows.length; r++) {
    const row = rawRows[r];
    const colNames = row.map(cellString).map((s) => s.toLowerCase().trim());
    if (colNames.some((c) => c.includes("customer") || c.includes("name") || c.includes("client"))) {
      headerRowIndex = r;
      for (let c = 0; c < colNames.length; c++) {
        const col = colNames[c];
        if (!col) continue;
        if (col.includes("name") || col === "customer" || col === "client") {
          if (headerMap.name === undefined) headerMap.name = c;
        } else if (col.includes("phone") || col.includes("mobile") || col.includes("contact")) {
          if (headerMap.phone === undefined) headerMap.phone = c;
        } else if (col.includes("gstin") || col === "gst" || col.includes("tax number")) {
          if (headerMap.gstin === undefined) headerMap.gstin = c;
        } else if (col.includes("address") || col.includes("city") || col.includes("location")) {
          if (headerMap.address === undefined) headerMap.address = c;
        }
      }
      break;
    }
  }

  if (headerRowIndex === -1 || headerMap.name === undefined) {
    throw new Error("Could not find valid column headers in the Excel file. Please use the downloadable template.");
  }

  const items = [];
  for (let r = headerRowIndex + 1; r < rawRows.length; r++) {
    const row = rawRows[r];
    if (!row || row.every((c) => cellString(c) === "")) continue;

    const name = headerMap.name !== undefined ? cellString(row[headerMap.name]) : "";
    const phone = headerMap.phone !== undefined ? cellString(row[headerMap.phone]) : "";
    const gstin = headerMap.gstin !== undefined ? cellString(row[headerMap.gstin]) : "";
    const address = headerMap.address !== undefined ? cellString(row[headerMap.address]) : "";

    items.push({
      rowNumber: r + 1,
      name,
      phone,
      gstin,
      address,
    });
  }

  return items;
}

module.exports = {
  generateProductsTemplate,
  generateProductsExport,
  parseProductsFile,
  generateCustomersTemplate,
  generateCustomersExport,
  parseCustomersFile,
};
