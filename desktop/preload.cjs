/* eslint-disable @typescript-eslint/no-require-imports -- sandboxed Electron preload entrypoint */
const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("avSmartbillingDesktop", {
  isDesktop: true,
  getDeviceIdentity: () => ipcRenderer.invoke("desktop:get-device-identity"),
});
