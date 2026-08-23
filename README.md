# AV Smartbilling

Configurable billing and license-management platform with a browser Control Center and a customer-facing offline Electron application.

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
- Electron Billing Desk with local SQLite as its working database
- Barcode-first Quick POS with keyboard shortcuts, held bills, cash/UPI/card/credit checkout, and automatic local stock deduction
- Product categories, barcode, purchase/selling price, HSN/SAC, per-product stock thresholds, and immutable inventory movements
- Professional GST invoices with discounts, CGST/SGST/IGST, A4 output, and configurable 58mm/80mm thermal receipts
- OS-protected license grant storage and offline signature verification
- Explicit encrypted, versioned cloud backup and restore for computer migration

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

The Electron application is an isolated local Billing Desk. It packages its own renderer and SQLite repository, but does not package the Next.js source, admin pages, Supabase service-role key, or license-signing private key. For local activation/API development, start the web server first and then open a second terminal:

```bash
npm run desktop:dev
```

Development connects license and cloud operations to `http://localhost:3000`. Products, customers, invoices, payments, reports, settings and printing use local SQLite and continue working when that server is stopped. External navigation, popups, Node integration, and renderer permissions are blocked.

The application starts at the local Billing Desk while its signed offline grant remains valid. A fresh or expired installation opens activation/validation. The grant and backup encryption key are protected through the operating system's secure-storage service.

The production desktop URL defaults to `https://av-smart-billing.vercel.app`. To create the Windows installer, run:

```bash
npm run desktop:dist:win
```

Use `AVSB_APP_URL` only when deliberately building for a different HTTPS deployment:

```bash
AVSB_APP_URL="https://another-deployment.example" npm run desktop:dist:win
```

The NSIS installer is written to `release/AV-Smartbilling-Setup-0.3.0.exe`. For a trusted customer release, configure a Windows code-signing certificate through electron-builder's `CSC_LINK` and `CSC_KEY_PASSWORD` environment variables before packaging.

To create both Apple Silicon and Intel macOS installers:

```bash
npm run desktop:dist:mac
```

The DMG files are written to `release/AV-Smartbilling-0.3.0-arm64.dmg` and `release/AV-Smartbilling-0.3.0-x64.dmg`. Public distribution should use an Apple Developer ID certificate and notarization; unsigned local builds may be blocked by Gatekeeper.

Normal desktop billing is offline. Internet is used only for initial activation, periodic license validation, explicit encrypted cloud backup/restore, and future updates. Automatic updates and clean-machine installer testing remain subsequent milestones.

## Mobile development

The Android-first Flutter application lives in [`mobile`](./mobile). Its first milestone uses local SQLite for products, customers, invoices and stock, with internet required only for license activation and periodic validation. Camera barcode scanning and PDF/WhatsApp sharing are included. See [`mobile/README.md`](./mobile/README.md) for setup and scope.

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
8. Apply `supabase/migrations/202608080006_desktop_cloud_backups.sql`.
9. Apply `supabase/migrations/202608090001_pos_inventory_and_backup_history.sql`.
10. Apply `supabase/migrations/202608090002_product_delete_semantics.sql`.
11. Apply `supabase/migrations/202608230001_public_subscription_checkout.sql`.
12. Create the first Auth user, then insert its UUID in `public.profiles` with the `OWNER` role.
13. Sign in and open `/billing/settings` to create the first browser billing workspace if it is still needed.

`SUPABASE_SERVICE_ROLE_KEY` and `LICENSE_SIGNING_PRIVATE_KEY` are server-only. Never expose them with a `NEXT_PUBLIC_` prefix or ship them in a browser/Electron bundle.

### Razorpay subscription checkout

The unauthenticated purchase flow is available at `/subscribe`. Configure these server-only Vercel environment variables before accepting payments:

- `RAZORPAY_KEY_ID`: live key ID (the only Razorpay value sent to Checkout)
- `RAZORPAY_KEY_SECRET`: live key secret
- `RAZORPAY_WEBHOOK_SECRET`: a separate strong secret configured in the Razorpay dashboard
- `SUBSCRIPTION_LICENSE_CREATED_BY`: UUID of an active `OWNER` or `ADMIN` row in `public.profiles`

In Razorpay, enable automatic capture and register the live webhook URL `https://av-smart-billing.vercel.app/api/webhooks/razorpay` for `payment.captured`, `payment.failed`, and `order.paid`. The server also verifies Checkout signatures, fetches the payment, confirms its order/amount/currency, and explicitly captures an authorized payment before generating a license. Never add the key secret or webhook secret to a `NEXT_PUBLIC_` variable.

### Test license activation on localhost

1. Sign in as an `OWNER` or `ADMIN` and create an active customer and plan.
2. Open `/admin/licenses/new`, generate a license, and copy the plaintext key immediately.
3. Open `/activate` in another browser window, enter the key and a device name, and activate.
4. Return to the license detail page to see the registered device.
5. For a damaged/replaced computer, choose **Deactivate & free slot**, then activate from a new browser profile/device.
6. Use **Suspend** for a temporary block. Use **Revoke permanently** only to cancel the entire license.
7. On `/activate`, use **Validate stored activation** to test periodic online validation. Signed grants remain valid offline only until their `validUntil` timestamp.

The browser activation screen is a lifecycle simulator. Electron uses a persistent installation UUID and the computer hostname, protects the signed grant with the operating system security service, and verifies its Ed25519 signature locally. Hardware-backed identity remains future hardening work.

### License signing configuration

These values are owned by AV Smartbilling and are not supplied by Supabase. Generate an Ed25519 key pair locally with Node.js:

```bash
node -e 'const { generateKeyPairSync } = require("node:crypto"); const { privateKey, publicKey } = generateKeyPairSync("ed25519"); console.log("PRIVATE=" + privateKey.export({ type: "pkcs8", format: "der" }).toString("base64url")); console.log("PUBLIC=" + publicKey.export({ type: "spki", format: "der" }).toString("base64url"));'
```

Set `LICENSE_SIGNING_PRIVATE_KEY` to the `PRIVATE` value and store it only in server-side secret storage. Keep the `PUBLIC` value for the future desktop verifier. `LICENSE_SIGNING_KEY_ID` is a version label such as `v1`; change it when rotating to a new key pair. `LICENSE_ISSUER` is a stable HTTPS identifier you control, such as `https://licenses.yourdomain.com`.

## Architecture

```text
Browser admin UI
          │
          ▼
Next.js Route Handlers ── server-only credentials/signing
          │
          ▼
Supabase Auth + PostgreSQL + RLS

Electron Billing Desk ── local SQLite (no daily internet required)
          │ explicit encrypted backup/restore only
          └───────────────────────────────► Supabase billing_backups
```

Cloud tables hold platform identity, plans, licenses, devices, activations, audit records, and opaque encrypted desktop snapshots. Electron uses SQLite for operational billing; the browser billing tables remain available without becoming the desktop source of truth.

## Planned next milestone

Exercise the packaged activation and billing flow on Windows, then introduce the local SQLite storage adapter, OS-protected license-grant storage, offline signature verification, integration tests, rate limiting, multi-line invoicing, and signed automatic updates.

For the complete implementation status, continuation order, and mandatory future Electron auto-update requirements, read [`PROJECT_HANDOFF.md`](./PROJECT_HANDOFF.md).
