/* eslint-disable @typescript-eslint/no-require-imports -- Electron main-process module */
const { randomBytes, scryptSync, timingSafeEqual } = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

function createDesktopPreferences({ userDataPath, safeStorage }) {
  const preferencesPath = path.join(userDataPath, "desktop-preferences.dat");

  function read() {
    try {
      const encrypted = Buffer.from(fs.readFileSync(preferencesPath, "utf8"), "base64");
      return JSON.parse(safeStorage.decryptString(encrypted));
    } catch {
      return { security: { enabled: false }, paymentQrPath: null, activity: [] };
    }
  }

  function write(value) {
    if (!safeStorage.isEncryptionAvailable()) throw new Error("Secure operating-system storage is unavailable.");
    fs.mkdirSync(path.dirname(preferencesPath), { recursive: true });
    const encrypted = safeStorage.encryptString(JSON.stringify(value));
    fs.writeFileSync(preferencesPath, encrypted.toString("base64"), { encoding: "utf8", mode: 0o600 });
  }

  function record(action, details = "") {
    const current = read();
    current.activity = [{ id: `${Date.now()}-${randomBytes(4).toString("hex")}`, action, details: String(details).slice(0, 300), createdAt: new Date().toISOString() }, ...(current.activity || [])].slice(0, 200);
    write(current);
  }

  function configurePin(pin, inactivityMinutes) {
    if (!/^\d{6}$/.test(String(pin))) throw new Error("Enter a 6-digit application PIN.");
    const salt = randomBytes(16);
    const hash = scryptSync(String(pin), salt, 32);
    const current = read();
    current.security = {
      enabled: true,
      pinSalt: salt.toString("base64"),
      pinHash: hash.toString("base64"),
      inactivityMinutes: Math.min(60, Math.max(1, Number(inactivityMinutes) || 5)),
      updatedAt: new Date().toISOString(),
    };
    write(current);
    record("APP_LOCK_ENABLED", `${current.security.inactivityMinutes}-minute inactivity timeout`);
    return status();
  }

  function verifyPin(pin) {
    const security = read().security || {};
    if (!security.enabled || !security.pinSalt || !security.pinHash) return true;
    const expected = Buffer.from(security.pinHash, "base64");
    const actual = scryptSync(String(pin), Buffer.from(security.pinSalt, "base64"), expected.length);
    const valid = timingSafeEqual(expected, actual);
    record(valid ? "APP_UNLOCKED" : "APP_UNLOCK_FAILED", valid ? "PIN verified" : "Incorrect PIN");
    return valid;
  }

  function disable(pin) {
    if (!verifyPin(pin)) throw new Error("The current PIN is incorrect.");
    const current = read();
    current.security = { enabled: false };
    write(current);
    record("APP_LOCK_DISABLED");
    return status();
  }

  function status() {
    const security = read().security || {};
    return { enabled: security.enabled === true, inactivityMinutes: security.inactivityMinutes || 5, touchIdAvailable: process.platform === "darwin" };
  }

  function setPaymentQrPath(value) {
    const current = read();
    current.paymentQrPath = value || null;
    write(current);
    record(value ? "PAYMENT_QR_UPDATED" : "PAYMENT_QR_REMOVED");
  }

  return {
    status,
    configurePin,
    verifyPin,
    disable,
    record,
    activity: () => read().activity || [],
    paymentQrPath: () => read().paymentQrPath || null,
    setPaymentQrPath,
  };
}

module.exports = { createDesktopPreferences };
