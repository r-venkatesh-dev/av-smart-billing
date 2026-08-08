async function request(url, options = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30_000);
  try {
    const response = await fetch(url, { ...options, signal: controller.signal });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok || payload.ok === false) throw new Error(payload.message || `Server request failed (${response.status}).`);
    return payload;
  } catch (error) {
    if (error.name === "AbortError") throw new Error("The server did not respond in time.");
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

function createCloudClient(baseUrl) {
  return {
    activate: (input) => request(`${baseUrl}/api/license/activate`, { method: "POST", headers: { "Content-Type": "application/json", "User-Agent": "AV-Smartbilling-Desktop" }, body: JSON.stringify(input) }),
    validate: (input) => request(`${baseUrl}/api/license/validate`, { method: "POST", headers: { "Content-Type": "application/json", "User-Agent": "AV-Smartbilling-Desktop" }, body: JSON.stringify(input) }),
    pushBackup: (token, body) => request(`${baseUrl}/api/desktop/backup`, { method: "PUT", headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}`, "User-Agent": "AV-Smartbilling-Desktop" }, body: JSON.stringify(body) }),
    pullBackup: (token) => request(`${baseUrl}/api/desktop/backup`, { method: "GET", headers: { Authorization: `Bearer ${token}`, "User-Agent": "AV-Smartbilling-Desktop" } }),
  };
}

module.exports = { createCloudClient };
