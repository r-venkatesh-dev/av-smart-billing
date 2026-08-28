/* eslint-disable @typescript-eslint/no-require-imports -- Electron entrypoint uses CommonJS without changing the Next.js module mode. */
const { app, BrowserWindow, Menu, dialog, ipcMain, safeStorage, session, shell, systemPreferences } = require("electron");
const { randomUUID } = require("node:crypto");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { createBillingDatabase } = require("./database.cjs");
const { createCloudClient } = require("./cloud.cjs");
const { createLicenseStore } = require("./license.cjs");
const { createDesktopPreferences } = require("./preferences.cjs");

const PRODUCT_NAME = "AV Smartbilling";
let mainWindow = null;
let database = null;
let licenses = null;
let cloud = null;
let preferences = null;

function readApplicationUrl() {
  let configuredUrl = process.env.AVSB_APP_URL;
  if (app.isPackaged) {
    const config = JSON.parse(fs.readFileSync(path.join(process.resourcesPath, "desktop-config.json"), "utf8"));
    configuredUrl = config.appUrl;
  }
  const parsed = new URL(configuredUrl || "http://localhost:3000");
  const localDevelopment = !app.isPackaged && ["localhost", "127.0.0.1"].includes(parsed.hostname);
  if (parsed.protocol !== "https:" && !localDevelopment) throw new Error("The desktop application requires an HTTPS AV Smartbilling server URL.");
  if (parsed.username || parsed.password) throw new Error("The desktop application URL cannot contain credentials.");
  return parsed.origin;
}

function getDeviceIdentity() {
  const identityPath = path.join(app.getPath("userData"), "device-identity.json");
  try {
    const saved = JSON.parse(fs.readFileSync(identityPath, "utf8"));
    if (typeof saved.id === "string" && saved.id.length >= 32) return { fingerprint: `avsb-desktop:${saved.id}`, deviceName: saved.deviceName || os.hostname() };
  } catch {
    // First launch or deleted profile.
  }
  const identity = { id: randomUUID(), deviceName: os.hostname(), createdAt: new Date().toISOString() };
  fs.mkdirSync(path.dirname(identityPath), { recursive: true });
  fs.writeFileSync(identityPath, JSON.stringify(identity), { encoding: "utf8", mode: 0o600 });
  return { fingerprint: `avsb-desktop:${identity.id}`, deviceName: identity.deviceName };
}

function expose(channel, handler, { licenseRequired = true } = {}) {
  ipcMain.handle(channel, async (_event, input) => {
    try {
      if (licenseRequired) licenses.requireActive();
      return { ok: true, data: await handler(input || {}) };
    } catch (error) {
      console.error(`${channel} failed`, error);
      return { ok: false, message: error instanceof Error ? error.message : "Operation failed." };
    }
  });
}

function initializeBillingName(customerName) {
  const business = database.getBusiness();
  if (business.company_name !== "My Business") return;
  database.saveSettings({
    companyName: customerName,
    contactPerson: business.contact_person,
    email: business.email,
    phone: business.phone,
    address: business.address,
    gstin: business.gstin,
    invoicePrefix: business.invoice_prefix,
    lowStockThreshold: business.low_stock_threshold,
    invoiceFooter: business.invoice_footer,
  });
}

function registerIpc() {
  expose("app:bootstrap", () => ({ license: licenses.status(), device: getDeviceIdentity(), business: database.getBusiness(), security: preferences.status() }), { licenseRequired: false });
  expose("license:activate", async (input) => {
    const identity = getDeviceIdentity();
    const licenseKey = String(input.licenseKey || "").trim().toUpperCase();
    if (!/^[A-Z0-9]{4}(?:-[A-Z0-9]{4}){3}$/.test(licenseKey)) throw new Error("Enter a valid license key.");
    const result = await cloud.activate({ licenseKey, deviceName: String(input.deviceName || identity.deviceName).trim(), deviceFingerprint: identity.fingerprint });
    const record = licenses.saveActivation(result, identity.fingerprint, licenseKey, null);
    initializeBillingName(record.grant.customerName);
    return licenses.status();
  }, { licenseRequired: false });
  expose("license:validate", async () => {
    const current = licenses.read();
    if (!current) throw new Error("No activation is stored on this computer.");
    const result = await cloud.validate({ deviceId: current.grant.deviceId, deviceFingerprint: current.deviceFingerprint });
    licenses.saveActivation(result, current.deviceFingerprint, null, current);
    return licenses.status();
  }, { licenseRequired: false });

  expose("billing:dashboard", () => database.dashboard());
  expose("billing:customers", () => database.listCustomers());
  expose("billing:save-customer", (input) => database.saveCustomer(input));
  expose("billing:delete-customer", (input) => database.deleteCustomer(input.id));
  expose("billing:products", () => database.listProducts());
  expose("billing:generate-sku", () => database.generateSku());
  expose("billing:save-product", (input) => database.saveProduct(input));
  expose("billing:delete-product", (input) => database.deleteProduct(input.id));
  expose("billing:inventory", () => database.inventory());
  expose("billing:adjust-stock", (input) => database.adjustStock(input));
  expose("billing:invoices", () => database.listInvoices());
  expose("billing:invoice", (input) => database.getInvoice(input.id));
  expose("billing:create-invoice", (input) => database.createInvoice(input));
  expose("billing:create-pos-sale", (input) => database.createPosSale(input));
  expose("billing:held-bills", () => database.listHeldBills());
  expose("billing:hold-bill", (input) => database.holdBill(input));
  expose("billing:delete-held-bill", (input) => database.deleteHeldBill(input.id));
  expose("billing:payments", () => database.listPayments());
  expose("billing:record-payment", (input) => database.recordPayment(input));
  expose("billing:settings", () => database.getBusiness());
  expose("billing:save-settings", (input) => database.saveSettings(input));
  expose("billing:reports", (input) => database.reports(input));

  expose("security:status", () => preferences.status(), { licenseRequired: false });
  expose("security:configure", (input) => preferences.configurePin(String(input.pin || ""), input.inactivityMinutes));
  expose("security:verify", (input) => ({ valid: preferences.verifyPin(String(input.pin || "")) }), { licenseRequired: false });
  expose("security:disable", (input) => preferences.disable(String(input.pin || "")));
  expose("security:biometric", async () => {
    if (process.platform !== "darwin") throw new Error("Operating-system biometric unlock is currently available on macOS only.");
    await systemPreferences.promptTouchID("Unlock AV Smartbilling");
    preferences.record("APP_UNLOCKED", "Touch ID verified");
    return { valid: true };
  }, { licenseRequired: false });
  expose("activity:list", () => preferences.activity());

  expose("payment-qr:pick", async () => {
    const selected = await dialog.showOpenDialog(mainWindow, { title: "Choose payment QR image", properties: ["openFile"], filters: [{ name: "Images", extensions: ["png", "jpg", "jpeg", "webp"] }] });
    if (selected.canceled || !selected.filePaths[0]) return { canceled: true };
    const source = selected.filePaths[0];
    const extension = path.extname(source).toLowerCase() || ".png";
    const destination = path.join(app.getPath("userData"), `payment-qr${extension}`);
    fs.copyFileSync(source, destination);
    preferences.setPaymentQrPath(destination);
    return { canceled: false };
  });
  expose("payment-qr:get", () => {
    const qrPath = preferences.paymentQrPath();
    if (!qrPath || !fs.existsSync(qrPath)) return { configured: false };
    const extension = path.extname(qrPath).toLowerCase();
    const mime = extension === ".webp" ? "image/webp" : extension === ".png" ? "image/png" : "image/jpeg";
    return { configured: true, dataUrl: `data:${mime};base64,${fs.readFileSync(qrPath).toString("base64")}` };
  });
  expose("payment-qr:remove", () => {
    const qrPath = preferences.paymentQrPath();
    if (qrPath && fs.existsSync(qrPath)) fs.unlinkSync(qrPath);
    preferences.setPaymentQrPath(null);
    return { message: "Payment QR removed." };
  });

  expose("file:save-export", async (input) => {
    const format = ["csv", "xls"].includes(input.format) ? input.format : null;
    if (!format || typeof input.content !== "string" || input.content.length > 10_000_000) throw new Error("Invalid export data.");
    const result = await dialog.showSaveDialog(mainWindow, { defaultPath: `${String(input.fileName || "report").replace(/[^a-z0-9_-]/gi, "-")}.${format}`, filters: [{ name: format === "csv" ? "CSV" : "Excel", extensions: [format] }] });
    if (result.canceled || !result.filePath) return { canceled: true };
    fs.writeFileSync(result.filePath, input.content, "utf8");
    preferences.record("REPORT_EXPORTED", `${format.toUpperCase()} · ${path.basename(result.filePath)}`);
    return { canceled: false, path: result.filePath };
  });
  expose("document:save-pdf", async (input) => {
    const result = await dialog.showSaveDialog(mainWindow, { defaultPath: `${String(input.fileName || "document").replace(/[^a-z0-9_-]/gi, "-")}.pdf`, filters: [{ name: "PDF", extensions: ["pdf"] }] });
    if (result.canceled || !result.filePath) return { canceled: true };
    const pdf = await mainWindow.webContents.printToPDF({ printBackground: true, pageSize: input.pageSize === "A4" ? "A4" : undefined });
    fs.writeFileSync(result.filePath, pdf);
    preferences.record(input.kind === "invoice" ? "INVOICE_PDF_SAVED" : "REPORT_EXPORTED", path.basename(result.filePath));
    return { canceled: false, path: result.filePath };
  });
  expose("external:whatsapp", async (input) => {
    let digits = String(input.phone || "").replace(/\D/g, "");
    if (digits.length === 11 && digits.startsWith("0")) digits = digits.slice(1);
    if (digits.length === 10) digits = `91${digits}`;
    if (!/^\d{11,15}$/.test(digits)) throw new Error("Add a valid customer mobile number before opening WhatsApp.");
    await shell.openExternal(`https://wa.me/${digits}?text=${encodeURIComponent(String(input.message || "").slice(0, 4000))}`);
    preferences.record("INVOICE_SHARED", `WhatsApp · ${String(input.invoiceNumber || "")}`);
    return { opened: true };
  });
  expose("external:email", async (input) => {
    const email = String(input.email || "").trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error("Add a valid customer email before composing an email.");
    await shell.openExternal(`mailto:${encodeURIComponent(email)}?subject=${encodeURIComponent(String(input.subject || "Invoice"))}&body=${encodeURIComponent(String(input.body || "").slice(0, 8000))}`);
    preferences.record("INVOICE_SHARED", `Email · ${String(input.invoiceNumber || "")}`);
    return { opened: true };
  });

  expose("cloud:status", async () => {
    const record = licenses.requireActive();
    const result = await cloud.listBackups(record.token);
    return { available: result.backups.length > 0, metadata: result.backups[0] || null, backups: result.backups };
  });
  expose("cloud:backup", async () => {
    const record = licenses.requireActive();
    const snapshot = database.exportSnapshot();
    const envelope = licenses.encryptSnapshot(snapshot);
    const counts = database.counts();
    const result = await cloud.pushBackup(record.token, { envelope, counts, deviceName: getDeviceIdentity().deviceName, appVersion: app.getVersion() });
    preferences.record("CLOUD_BACKUP_COMPLETED", `${counts.invoices} invoices · ${counts.products} products`);
    return result;
  });
  expose("cloud:restore", async (input) => {
    const record = licenses.requireActive();
    const result = await cloud.pullBackup(record.token, input.id);
    const snapshot = licenses.decryptSnapshot(result.envelope);
    const backupDirectory = path.join(app.getPath("userData"), "backups");
    fs.mkdirSync(backupDirectory, { recursive: true });
    const backupPath = path.join(backupDirectory, `before-cloud-restore-${new Date().toISOString().replaceAll(":", "-")}.sqlite`);
    await database.backup(backupPath);
    const restored = database.restoreSnapshot(snapshot);
    preferences.record("CLOUD_RESTORE_COMPLETED", path.basename(backupPath));
    return { ...restored, backupPath, metadata: result.metadata };
  });
}

function createWindow() {
  mainWindow = new BrowserWindow({
    title: PRODUCT_NAME,
    width: 1440,
    height: 920,
    minWidth: 1024,
    minHeight: 680,
    show: false,
    backgroundColor: "#f7f8f7",
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webSecurity: true,
      devTools: !app.isPackaged,
    },
  });
  mainWindow.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
  mainWindow.webContents.on("will-navigate", (event, url) => {
    if (!url.startsWith("file:")) event.preventDefault();
  });
  mainWindow.once("ready-to-show", () => mainWindow?.show());
  mainWindow.on("closed", () => { mainWindow = null; });
  mainWindow.loadFile(path.join(__dirname, "renderer", "index.html"));
}

const hasSingleInstanceLock = app.requestSingleInstanceLock();
if (!hasSingleInstanceLock) app.quit();
else {
  app.on("second-instance", () => {
    if (!mainWindow) return;
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.focus();
  });
  app.whenReady().then(() => {
    app.setName(PRODUCT_NAME);
    Menu.setApplicationMenu(null);
    session.defaultSession.setPermissionRequestHandler((_contents, _permission, callback) => callback(false));
    session.defaultSession.setPermissionCheckHandler(() => false);
    const userDataPath = app.getPath("userData");
    database = createBillingDatabase(path.join(userDataPath, "av-smartbilling.sqlite"));
    licenses = createLicenseStore({ userDataPath, safeStorage });
    cloud = createCloudClient(readApplicationUrl());
    preferences = createDesktopPreferences({ userDataPath, safeStorage });
    registerIpc();
    createWindow();
  }).catch((error) => {
    console.error(error);
    app.quit();
  });
}

app.on("window-all-closed", () => app.quit());
app.on("before-quit", () => database?.close());
