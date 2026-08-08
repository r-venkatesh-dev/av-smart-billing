/* eslint-disable @typescript-eslint/no-require-imports -- Electron main-process module */
const { createCipheriv, createDecipheriv, createHash, createPublicKey, randomBytes, verify } = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const zlib = require("node:zlib");

function decodePart(value) {
  return JSON.parse(Buffer.from(value, "base64url").toString("utf8"));
}

function verifyGrant(record) {
  if (!record?.token || !record?.publicKey) throw new Error("No licensed activation is stored.");
  const parts = record.token.split(".");
  if (parts.length !== 3) throw new Error("Stored license grant is invalid.");
  const header = decodePart(parts[0]);
  const payload = decodePart(parts[1]);
  const key = createPublicKey({ key: Buffer.from(record.publicKey, "base64url"), type: "spki", format: "der" });
  if (header.alg !== "EdDSA" || !verify(null, Buffer.from(`${parts[0]}.${parts[1]}`), key, Buffer.from(parts[2], "base64url"))) throw new Error("Stored license signature is invalid.");
  if (payload.type !== "av-smartbilling-license" || payload.iss !== record.issuer || payload.aud !== "av-smartbilling-desktop" || payload.deviceId !== record.grant?.deviceId) throw new Error("Stored license grant does not belong to this application.");
  return { payload, validUntil: new Date(Number(payload.exp) * 1000).toISOString(), active: Number(payload.exp) * 1000 > Date.now() };
}

function createLicenseStore({ userDataPath, safeStorage }) {
  const licensePath = path.join(userDataPath, "license.dat");

  function read() {
    try {
      const encrypted = Buffer.from(fs.readFileSync(licensePath, "utf8"), "base64");
      return JSON.parse(safeStorage.decryptString(encrypted));
    } catch {
      return null;
    }
  }

  function write(record) {
    if (!safeStorage.isEncryptionAvailable()) throw new Error("Secure operating-system storage is unavailable.");
    fs.mkdirSync(path.dirname(licensePath), { recursive: true });
    const encrypted = safeStorage.encryptString(JSON.stringify(record));
    fs.writeFileSync(licensePath, encrypted.toString("base64"), { encoding: "utf8", mode: 0o600 });
  }

  function saveActivation(result, deviceFingerprint, licenseKey, previous) {
    if (!result?.grant || !result?.signed) throw new Error("Activation server returned an incomplete grant.");
    const backupKey = licenseKey
      ? createHash("sha256").update(`av-smartbilling-backup-v1:${licenseKey.replaceAll("-", "").toUpperCase()}`).digest("base64url")
      : previous?.backupKey;
    if (!backupKey) throw new Error("The backup encryption key is unavailable. Activate again with the license key.");
    const record = {
      token: result.signed.token,
      publicKey: result.signed.publicKey,
      issuer: result.signed.issuer,
      keyId: result.signed.keyId,
      validUntil: result.signed.validUntil,
      grant: result.grant,
      deviceFingerprint,
      backupKey,
      savedAt: new Date().toISOString(),
    };
    verifyGrant(record);
    write(record);
    return record;
  }

  function status() {
    const record = read();
    if (!record) return { activated: false, active: false };
    try {
      const verified = verifyGrant(record);
      return {
        activated: true,
        active: verified.active,
        validUntil: verified.validUntil,
        customerName: record.grant.customerName,
        planName: record.grant.planName,
        expiresAt: record.grant.expiresAt,
        deviceId: record.grant.deviceId,
      };
    } catch (error) {
      return { activated: false, active: false, error: error.message };
    }
  }

  function requireActive() {
    const record = read();
    if (!record) throw new Error("Activate this installation first.");
    const verified = verifyGrant(record);
    if (!verified.active) throw new Error("Online license validation is required before billing can continue.");
    return record;
  }

  function encryptSnapshot(snapshot) {
    const record = requireActive();
    const key = Buffer.from(record.backupKey, "base64url");
    const iv = randomBytes(12);
    const cipher = createCipheriv("aes-256-gcm", key, iv);
    const compressed = zlib.gzipSync(Buffer.from(JSON.stringify(snapshot)));
    const encrypted = Buffer.concat([cipher.update(compressed), cipher.final()]);
    return { version: 1, algorithm: "AES-256-GCM+GZIP", iv: iv.toString("base64url"), tag: cipher.getAuthTag().toString("base64url"), ciphertext: encrypted.toString("base64url") };
  }

  function decryptSnapshot(envelope) {
    const record = requireActive();
    if (envelope?.version !== 1 || envelope?.algorithm !== "AES-256-GCM+GZIP") throw new Error("Unsupported cloud backup format.");
    try {
      const decipher = createDecipheriv("aes-256-gcm", Buffer.from(record.backupKey, "base64url"), Buffer.from(envelope.iv, "base64url"));
      decipher.setAuthTag(Buffer.from(envelope.tag, "base64url"));
      const compressed = Buffer.concat([decipher.update(Buffer.from(envelope.ciphertext, "base64url")), decipher.final()]);
      return JSON.parse(zlib.gunzipSync(compressed).toString("utf8"));
    } catch {
      throw new Error("Cloud backup could not be decrypted with this license. Activate using the original license key.");
    }
  }

  return { read, saveActivation, status, requireActive, encryptSnapshot, decryptSnapshot };
}

module.exports = { createLicenseStore };
