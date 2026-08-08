/* eslint-disable @typescript-eslint/no-require-imports -- Electron entrypoints use CommonJS without changing the Next.js module mode. */
const { app, BrowserWindow, Menu, ipcMain, session } = require("electron");
const { randomUUID } = require("node:crypto");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const PRODUCT_NAME = "AV Smartbilling";
const PARTITION = "persist:av-smartbilling";
let mainWindow = null;
let applicationOrigin = "";
let startUrl = "";

function readApplicationUrl() {
  let configuredUrl = process.env.AVSB_APP_URL;
  if (app.isPackaged) {
    const configPath = path.join(process.resourcesPath, "desktop-config.json");
    const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
    configuredUrl = config.appUrl;
  }

  const parsed = new URL(configuredUrl || "http://localhost:3000");
  const localDevelopment = !app.isPackaged && ["localhost", "127.0.0.1"].includes(parsed.hostname);
  if (parsed.protocol !== "https:" && !localDevelopment) {
    throw new Error("The packaged desktop application requires an HTTPS AV Smartbilling server URL.");
  }
  if (parsed.username || parsed.password) throw new Error("The desktop application URL cannot contain credentials.");
  return parsed.origin;
}

function isAllowedPath(pathname) {
  return pathname === "/activate"
    || pathname === "/billing"
    || pathname.startsWith("/billing/")
    || pathname === "/api/license/activate"
    || pathname === "/api/license/validate"
    || pathname === "/api/search"
    || pathname.startsWith("/_next/")
    || pathname === "/favicon.ico";
}

function isAllowedUrl(value) {
  try {
    const parsed = new URL(value);
    if (parsed.protocol === "data:") return true;
    if (parsed.protocol === "ws:" || parsed.protocol === "wss:") {
      const expectedSocketOrigin = applicationOrigin.replace(/^http/, "ws");
      return !app.isPackaged && parsed.origin === expectedSocketOrigin && parsed.pathname.startsWith("/_next/");
    }
    if (parsed.origin !== applicationOrigin) return false;
    return isAllowedPath(parsed.pathname);
  } catch {
    return false;
  }
}

function getDeviceIdentity() {
  const identityPath = path.join(app.getPath("userData"), "device-identity.json");
  try {
    const saved = JSON.parse(fs.readFileSync(identityPath, "utf8"));
    if (typeof saved.id === "string" && saved.id.length >= 32) {
      return { fingerprint: `avsb-desktop:${saved.id}`, deviceName: saved.deviceName || os.hostname() };
    }
  } catch {
    // A first launch, deleted profile, or invalid file creates a new installation identity.
  }

  const identity = { id: randomUUID(), deviceName: os.hostname(), createdAt: new Date().toISOString() };
  fs.mkdirSync(path.dirname(identityPath), { recursive: true });
  fs.writeFileSync(identityPath, JSON.stringify(identity), { encoding: "utf8", mode: 0o600 });
  return { fingerprint: `avsb-desktop:${identity.id}`, deviceName: identity.deviceName };
}

function offlinePage() {
  const escapedStartUrl = JSON.stringify(startUrl);
  return `data:text/html;charset=utf-8,${encodeURIComponent(`<!doctype html>
    <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>${PRODUCT_NAME}</title><style>
    body{margin:0;min-height:100vh;display:grid;place-items:center;background:#f7f8f7;color:#26272a;font-family:Arial,sans-serif}.card{width:min(480px,calc(100% - 40px));border:1px solid #dfe3e1;background:#fff;padding:36px;box-sizing:border-box}small{color:#057c73;font-weight:700;letter-spacing:.16em;text-transform:uppercase}h1{font-family:Georgia,serif;font-weight:400}p{color:#6d716f;line-height:1.6}button{border:0;background:#057c73;color:#fff;padding:13px 20px;font-weight:700;text-transform:uppercase;letter-spacing:.1em;cursor:pointer}
    </style></head><body><main class="card"><small>AV Smartbilling</small><h1>Unable to reach the billing server</h1><p>Check this computer's internet connection and try again. Your administrator may also need to verify the configured billing URL.</p><button onclick='location.href=${escapedStartUrl}'>Try again</button></main></body></html>`)}`;
}

function configureSession() {
  const desktopSession = session.fromPartition(PARTITION);
  desktopSession.setPermissionRequestHandler((_webContents, _permission, callback) => callback(false));
  desktopSession.setPermissionCheckHandler(() => false);

  desktopSession.webRequest.onBeforeSendHeaders({ urls: [`${applicationOrigin}/*`] }, (details, callback) => {
    details.requestHeaders["X-AVSB-Desktop"] = "1";
    callback({ requestHeaders: details.requestHeaders });
  });

  desktopSession.webRequest.onBeforeRequest({ urls: ["<all_urls>"] }, (details, callback) => {
    callback({ cancel: !isAllowedUrl(details.url) });
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
      partition: PARTITION,
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webSecurity: true,
      devTools: !app.isPackaged,
    },
  });

  mainWindow.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
  mainWindow.webContents.on("will-navigate", (event, url) => {
    if (!isAllowedUrl(url)) event.preventDefault();
  });
  mainWindow.webContents.on("did-fail-load", (_event, errorCode, _description, _url, isMainFrame) => {
    if (isMainFrame && errorCode !== -3 && mainWindow && !mainWindow.isDestroyed()) mainWindow.loadURL(offlinePage());
  });
  mainWindow.once("ready-to-show", () => mainWindow?.show());
  mainWindow.on("closed", () => { mainWindow = null; });
  mainWindow.loadURL(startUrl);
}

const hasSingleInstanceLock = app.requestSingleInstanceLock();
if (!hasSingleInstanceLock) {
  app.quit();
} else {
  app.on("second-instance", () => {
    if (!mainWindow) return;
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.focus();
  });

  app.whenReady().then(() => {
    app.setName(PRODUCT_NAME);
    Menu.setApplicationMenu(null);
    applicationOrigin = readApplicationUrl();
    startUrl = `${applicationOrigin}/billing/dashboard`;
    configureSession();
    ipcMain.handle("desktop:get-device-identity", () => getDeviceIdentity());
    createWindow();
  }).catch((error) => {
    console.error(error);
    app.quit();
  });
}

app.on("window-all-closed", () => app.quit());
