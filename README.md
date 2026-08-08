# AV Smartbilling

Configurable billing and license-management platform with a browser Control Center and a locked customer-facing Electron shell.

## Current milestone

- Next.js 16 App Router, React 19, strict TypeScript, Tailwind CSS 4
- Responsive admin control center and client billing workspace
- Customer, license, device, plan, and settings routes
- Server-only Supabase repositories for live administration and browser-phase billing data
- Supabase PostgreSQL schemas, indexes, constraints, transactional billing functions, audit trail, and RLS
- Secure Supabase Auth cookie sessions with Next.js 16 session refresh
- Protected admin routes with active-profile and role authorization
- Server-only Supabase clients and validated environment boundaries
- Cryptographically secure license-key generation/hash utilities
- Zod request schemas ready for Route Handlers
- Electron desktop shell that exposes only activation and Billing Desk routes

Supabase Auth, live administration CRUD, browser-phase billing CRUD, license issuance, activation, validation, suspension, revocation, and device-slot reset are connected.

## Requirements

- Node.js 22.12+ (Node 24 LTS is supported)
- npm 10+
- A Supabase project for connected-data phases

## Run locally

```bash
cp .env.example .env.local
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000). The public Supabase URL and publishable/anon key must point to a configured project for sign-in. Server-only placeholders remain sufficient until license APIs are implemented.

If `node` is installed through nvm but is not on PATH:

```bash
nvm use 24
npm run dev
```

## Desktop development

The Electron application is deliberately a thin customer shell. It does not package the Next.js source, admin pages, Supabase service-role key, or license-signing private key. Start the web server first, then open a second terminal:

```bash
npm run desktop:dev
```

Development connects to `http://localhost:3000`. The shell permits only `/activate`, `/billing/*`, the required license/search APIs, and Next.js assets. `/admin`, `/login`, external navigation, popups, Node integration, and renderer permissions are blocked.

The application starts at the Billing Desk when its persistent license cookie is valid. A fresh, expired, revoked, or deactivated installation is redirected to the activation screen automatically.

To create the Windows installer, first deploy this Next.js application to an HTTPS server. On macOS/Linux run:

```bash
AVSB_APP_URL="https://billing.your-domain.example" npm run desktop:dist:win
```

Or in Windows PowerShell run:

```powershell
$env:AVSB_APP_URL="https://billing.your-domain.example"
npm run desktop:dist:win
```

The NSIS installer is written to `release/AV-Smartbilling-Setup-0.1.0.exe`. For a trusted customer release, configure a Windows code-signing certificate through electron-builder's `CSC_LINK` and `CSC_KEY_PASSWORD` environment variables before packaging.

This first Electron milestone still uses the hosted Next.js/Supabase billing repository and therefore requires connectivity for billing operations. It must not be described as the completed offline edition. Local SQLite, OS-protected grant storage, offline license verification, signed automatic updates, backup/migrations, and Windows clean-machine testing remain subsequent milestones.

## Verification

```bash
npm run lint
npm run typecheck
npm run build
```

Manual smoke test:

1. Open `/login`, sign in as a Supabase user with an active `profiles` row, and confirm the requested admin route opens.
2. Sign out from the profile control and confirm `/admin/dashboard` redirects back to `/login`.
3. Visit every admin sidebar route; open a customer and a license detail.
4. Switch to **Billing Desk** and visit every billing route.
5. Test at 375 px and desktop widths; confirm the mobile navigation opens and closes.
6. Confirm keyboard focus is visible and reduced-motion preference is respected.

## Supabase setup

1. Create a Supabase project.
2. Copy `.env.example` to `.env.local` and set the real keys.
3. Apply `supabase/migrations/202608080001_initial_license_platform.sql` with the Supabase CLI or SQL editor.
4. Apply `supabase/migrations/202608080002_browser_billing_workspace.sql`.
5. Apply `supabase/migrations/202608080003_invoice_customer_snapshots.sql`.
6. Apply `supabase/migrations/202608080004_license_lifecycle_functions.sql`.
7. Apply `supabase/migrations/202608080005_licensed_billing_sessions.sql`.
8. Create the first Auth user, then insert its UUID in `public.profiles` with the `OWNER` role.
9. Sign in and open `/billing/settings` to create the first billing workspace through the UI.

`SUPABASE_SERVICE_ROLE_KEY` and `LICENSE_SIGNING_PRIVATE_KEY` are server-only. Never expose them with a `NEXT_PUBLIC_` prefix or ship them in a browser/Electron bundle.

### Test license activation on localhost

1. Sign in as an `OWNER` or `ADMIN` and create an active customer and plan.
2. Open `/admin/licenses/new`, generate a license, and copy the plaintext key immediately.
3. Open `/activate` in another browser window, enter the key and a device name, and activate.
4. Return to the license detail page to see the registered device.
5. For a damaged/replaced computer, choose **Deactivate & free slot**, then activate from a new browser profile/device.
6. Use **Suspend** for a temporary block. Use **Revoke permanently** only to cancel the entire license.
7. On `/activate`, use **Validate stored activation** to test periodic online validation. Signed grants remain valid offline only until their `validUntil` timestamp.

The browser activation screen is a lifecycle simulator. Electron uses a persistent installation UUID and the computer hostname instead of the browser-generated ID. Hardware-backed identity, OS-protected grant storage, and fully local verification remain future hardening work.

### License signing configuration

These values are owned by AV Smartbilling and are not supplied by Supabase. Generate an Ed25519 key pair locally with Node.js:

```bash
node -e 'const { generateKeyPairSync } = require("node:crypto"); const { privateKey, publicKey } = generateKeyPairSync("ed25519"); console.log("PRIVATE=" + privateKey.export({ type: "pkcs8", format: "der" }).toString("base64url")); console.log("PUBLIC=" + publicKey.export({ type: "spki", format: "der" }).toString("base64url"));'
```

Set `LICENSE_SIGNING_PRIVATE_KEY` to the `PRIVATE` value and store it only in server-side secret storage. Keep the `PUBLIC` value for the future desktop verifier. `LICENSE_SIGNING_KEY_ID` is a version label such as `v1`; change it when rotating to a new key pair. `LICENSE_ISSUER` is a stable HTTPS identifier you control, such as `https://licenses.yourdomain.com`.

## Architecture

```text
Browser admin UI / Electron billing shell
          │
          ▼
Next.js Route Handlers ── server-only credentials/signing
          │
          ▼
Supabase Auth + PostgreSQL + RLS

Future offline billing operations ── local SQLite (no daily internet required)
```

Cloud tables hold platform identity, plans, licenses, devices, activations, and audit records. During browser development, billing data uses a separately scoped Supabase repository and schema. The later Electron adapter will replace that repository with local SQLite so normal desktop billing does not require internet.

## Planned next milestone

Exercise the packaged activation and billing flow on Windows, then introduce the local SQLite storage adapter, OS-protected license-grant storage, offline signature verification, integration tests, rate limiting, multi-line invoicing, and signed automatic updates.

For the complete implementation status, continuation order, and mandatory future Electron auto-update requirements, read [`PROJECT_HANDOFF.md`](./PROJECT_HANDOFF.md).
