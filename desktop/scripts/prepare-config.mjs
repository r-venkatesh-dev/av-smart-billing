import { mkdir, writeFile } from "node:fs/promises";

const rawUrl = process.env.AVSB_APP_URL;
if (!rawUrl) {
  console.error("AVSB_APP_URL is required. Example: AVSB_APP_URL=https://billing.example.com npm run desktop:dist:win");
  process.exit(1);
}

let url;
try {
  url = new URL(rawUrl);
} catch {
  console.error("AVSB_APP_URL must be a valid URL.");
  process.exit(1);
}

if (url.protocol !== "https:" || url.username || url.password) {
  console.error("AVSB_APP_URL must be an HTTPS origin without embedded credentials.");
  process.exit(1);
}

await mkdir("desktop/generated", { recursive: true });
await writeFile("desktop/generated/desktop-config.json", `${JSON.stringify({ appUrl: url.origin }, null, 2)}\n`, "utf8");
console.log(`Desktop server configured as ${url.origin}`);
