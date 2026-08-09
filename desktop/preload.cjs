/* eslint-disable @typescript-eslint/no-require-imports -- sandboxed Electron preload entrypoint */
const { contextBridge, ipcRenderer } = require("electron");

const channels = new Set([
  "app:bootstrap",
  "license:activate", "license:validate",
  "billing:dashboard",
  "billing:customers", "billing:save-customer", "billing:delete-customer",
  "billing:products", "billing:generate-sku", "billing:save-product", "billing:delete-product",
  "billing:inventory", "billing:adjust-stock",
  "billing:invoices", "billing:invoice", "billing:create-invoice",
  "billing:create-pos-sale", "billing:held-bills", "billing:hold-bill", "billing:delete-held-bill",
  "billing:payments", "billing:record-payment",
  "billing:settings", "billing:save-settings", "billing:reports",
  "cloud:status", "cloud:backup", "cloud:restore",
]);

contextBridge.exposeInMainWorld("avSmartbilling", {
  invoke(channel, input) {
    if (!channels.has(channel)) return Promise.resolve({ ok: false, message: "Unsupported desktop operation." });
    return ipcRenderer.invoke(channel, input);
  },
});
