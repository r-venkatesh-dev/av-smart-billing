/* eslint-disable @typescript-eslint/no-require-imports -- Electron entrypoint uses CommonJS without changing the Next.js module mode. */
const { app, BrowserWindow, Menu, ipcMain, safeStorage, session } = require("electron");
const { randomUUID } = require("node:crypto");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { createBillingDatabase } = require("./database.cjs");
const { createCloudClient } = require("./cloud.cjs");
const { createLicenseStore } = require("./license.cjs");

const PRODUCT_NAME = "AV Smartbilling";
let mainWindow = null;
let database = null;
let licenses = null;
let cloud = null;

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
  expose("app:bootstrap", () => ({ license: licenses.status(), device: getDeviceIdentity(), business: database.getBusiness() }), { licenseRequired: false });
  expose("license:activate", async (input) => {
    const identity = getDeviceIdentity();
    const licenseKey = String(input.licenseKey || "").trim().toUpperCase();
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
  expose("billing:reports", () => database.reports());

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
    return cloud.pushBackup(record.token, { envelope, counts, deviceName: getDeviceIdentity().deviceName, appVersion: app.getVersion() });
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
    registerIpc();
    createWindow();
  }).catch((error) => {
    console.error(error);
    app.quit();
  });
}

app.on("window-all-closed", () => app.quit());
app.on("before-quit", () => database?.close());
