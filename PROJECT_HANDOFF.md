# AV Smartbilling — Project Handoff and Continuation Summary

Last updated: 8 August 2026

## Product goal

AV Smartbilling is a configurable, offline-first billing platform intended for distribution to multiple business customers as a licensed Windows desktop application.

The product has two connected parts:

1. **Cloud administration platform** — manages business customers, plans, licenses, device activations, license status, validation rules, and audit history.
2. **Client billing application** — allows each licensed business to manage products, customers, invoices, payments, taxes, reports, printing, and business configuration. Normal billing must work without internet.

The same billing application will support different businesses through per-business settings such as company details, branding, GSTIN, currency, tax configuration, invoice numbering, footer, and printer configuration.

## Mandatory architecture decisions

- Develop and stabilize the application as a normal Next.js localhost web application first.
- Do not integrate Electron until browser UI, authentication, database flows, billing logic, licensing, and offline architecture are stable and tested.
- Use Next.js Route Handlers and server functionality rather than a separate Express, Node, or .NET backend initially.
- Use Supabase PostgreSQL, Auth, and RLS for cloud administration and licensing data.
- Never expose the Supabase service-role key or private signing key in browser or Electron client bundles.
- Route license activation and validation through server-side Next.js endpoints.
- Store operational billing data in local SQLite when Electron is introduced.
- Internet may be required for activation, periodic validation, optional backup/sync, and updates, but not for normal billing.
- Desktop clients will verify signed license payloads using a public key. The private signing key remains server-side.
- A fully offline application cannot be completely piracy-proof; the target is practical protection using signed payloads, device limits, periodic validation, revocation, and secure local storage.

## Work completed

The project is located at:

```text
/Users/ittest/Documents/Personal/billing-platform
```

### Application foundation

- Next.js 16.3.0 using the App Router.
- React 19.2.8.
- Strict TypeScript.
- Tailwind CSS 4.
- ESLint configuration.
- Responsive, commercial SaaS-style visual system.
- AV Smartbilling theme adapted from the NR Photography visual system: green, ink, paper, editorial serif headings, sharp surfaces, and restrained uppercase actions.
- Native/system font stack so production builds do not depend on downloading Google Fonts.
- Shared UI components, formatting utilities, status badges, search fields, loading state, empty states, and not-found handling.
- Responsive sidebar and mobile navigation.
- Separate **Control Center** and **Billing Desk** workspaces.

### Implemented routes

Public:

- `/`
- `/login`
- `/activate`
- `/api/license/activate`
- `/api/license/validate`

Administration:

- `/admin/dashboard`
- `/admin/customers`
- `/admin/customers/[id]`
- `/admin/customers/new`
- `/admin/customers/[id]/edit`
- `/admin/licenses`
- `/admin/licenses/new`
- `/admin/licenses/[id]`
- `/admin/devices`
- `/admin/plans`
- `/admin/plans/new`
- `/admin/plans/[id]/edit`
- `/admin/settings`

Billing workspace:

- `/billing/dashboard`
- `/billing/customers`
- `/billing/customers/new`
- `/billing/products`
- `/billing/products/new`
- `/billing/products/[id]/edit`
- `/billing/invoices`
- `/billing/invoices/new`
- `/billing/payments`
- `/billing/payments/new`
- `/billing/reports`
- `/billing/settings`

### Current UI capabilities

- Live admin overview metrics and six-month growth from Supabase.
- Live customer create, edit, list and detail flows with validation and audit records.
- Live license lists/details and activated-device reads.
- Live plan create/edit cards and platform license-policy settings.
- Tenant-scoped browser billing workspace, customer, product, invoice, payment and report screens.
- Transactional invoice numbering, stock deduction, money/tax calculation and payment reconciliation in PostgreSQL.
- Searchable themed dropdowns, a custom due-date calendar, and product restocking/edit support.
- Meaningful database-backed empty and workspace-setup states.
- Navigation between admin and billing workspaces.

### Domain and security foundation

- Typed domain models for customers, plans, licenses, and devices.
- Zod validation schemas for license generation, activation, validation, and device actions.
- Cryptographically random license-key generator using a format such as `NRP7-X4KD-92MQ-8LZT`.
- Ambiguous key characters are excluded.
- SHA-256 license-key hashing helper.
- Masked license-key hint helper so full plaintext keys do not need to be displayed or retained.
- Validated public and server environment-variable boundaries.
- A privileged Supabase client isolated in a server module.
- Dependencies installed for Supabase, validation, future signed payloads, and icons.

### Phase 2 authentication and authorization

- Supabase password authentication is implemented with Server Actions and server-managed cookies.
- A Next.js 16 `proxy.ts` refreshes sessions and redirects unauthenticated `/admin` requests to `/login` while preserving the requested path.
- The admin layout performs the secure authorization check against the authenticated user's active `profiles` row.
- A server-only authorization data-access module exposes active profile DTOs, role checks, and the mutation-role matrix matching database RLS.
- Login validation, pending/error states, expired-session messaging, safe local redirects, and logout are implemented.
- The app shell displays the authenticated administrator's name and role instead of a hard-coded demo user.
- Protected pages are deferred to request time so builds do not contact Supabase.

### Supabase migration

The initial migration is:

```text
supabase/migrations/202608080001_initial_license_platform.sql
```

It creates:

- `profiles`
- `customers`
- `plans`
- `licenses`
- `devices`
- `license_activations`
- `audit_logs`

It includes:

- UUID primary keys.
- Foreign keys and delete behavior.
- Enum types for roles and statuses.
- Validation constraints.
- Created/updated timestamps.
- Automatic `updated_at` triggers.
- Search and relationship indexes.
- A unique active-device fingerprint constraint per license.
- Row Level Security policies.
- Role-based administration for owner, admin, support, and viewer users.
- Removal of anonymous table privileges.
- Basic, Professional, and Business seed plans.

The browser billing migration is:

```text
supabase/migrations/202608080002_browser_billing_workspace.sql
```

It adds platform settings, billing businesses, billing customers, products, invoices, invoice items, payments, tenant RLS, audit-write policy, and transactional invoice/payment functions. This is the browser development adapter; Electron still requires local SQLite later.

### Documentation and environment configuration

- `.env.example` documents browser-safe and server-only variables.
- `README.md` contains setup commands, architecture notes, manual smoke tests, and the next milestone.
- `PROJECT_HANDOFF.md` is this continuation document.

## Important current limitations

The visual route structure and architecture foundation are implemented, but this is not yet a complete production billing system.

- A real Supabase project, applied migration, Auth user, and matching active `profiles` row are required before login can succeed.
- Authentication integration tests have not yet been added.
- Browser-first license generation, activation and validation Route Handlers are implemented, including Ed25519 signed device grants.
- Admin license suspension, permanent revocation and device-slot reset/deactivation are implemented with confirmations and audit writes.
- `/activate` provides a localhost lifecycle simulator; Electron-side public-key verification and OS-protected grant storage remain future work.
- The initial invoice form currently creates a single-product invoice; multi-line invoice editing remains.
- SQLite and true offline persistence are not yet implemented.
- Browser print/PDF invoice output and reports are implemented; backup/sync and update delivery are not yet implemented.
- A locked Electron thin shell has been added for customer-facing activation and Billing Desk access. It packages no admin source or server secrets and blocks admin/login navigation.
- The first desktop shell still connects to the hosted Next.js/Supabase application. SQLite, true offline operation, protected grant storage and automatic updates remain future work.

Do not describe browser Supabase billing persistence as the completed offline desktop storage layer.

## Verification status

The current source passes:

```bash
npm run lint
npm run typecheck
npm run build
```

The production build uses:

```text
next build --webpack
```

Webpack was selected because Turbopack's CSS worker was unable to bind an internal port in the managed development sandbox. This was an environment-specific Turbopack panic, not a source or TypeScript failure.

The last verified build generated all 18 routes successfully and the dependency audit reported zero vulnerabilities.

## Local development commands

```bash
cd /Users/ittest/Documents/Personal/billing-platform
nvm use 24
cp .env.example .env.local
npm install
npm run dev
```

Open `http://localhost:3000`.

Node 24.13.1 is installed at `/Users/ittest/.nvm/versions/node/v24.13.1`, but the shell used during the first session did not automatically place it on `PATH`. Use `nvm use 24` when necessary.

## Recommended next implementation order

### Phase 2 — Authentication and authorization

1. Configure the Supabase project and apply the initial migration. **Environment setup remains.**
2. Implement Supabase Auth with secure server-managed cookie sessions. **Implemented.**
3. Add the first `OWNER` profile. **Environment setup remains.**
4. Protect `/admin` routes and redirect unauthenticated users to `/login`. **Implemented.**
5. Enforce roles in the data-access layer and all admin mutations. **The role-enforcing boundary is implemented; apply it as mutations are added.**
6. Add logout, expired-session handling, loading states, and authentication tests. **UI/session behavior is implemented; integration tests remain.**

### Phase 3 — Live administration data

1. Introduce repository interfaces for customers, plans, licenses, and devices. **Implemented as server-only data modules.**
2. Replace typed mock repositories with Supabase-backed repositories. **Implemented.**
3. Implement customer create, edit, view, and disable. **Implemented; destructive deletion remains intentionally absent.**
4. Implement plan create and edit. **Implemented.**
5. Add server-side validation, pagination, search, error handling, toasts, and confirmation dialogs. **Validation and error states are implemented; pagination/search/toasts remain.**
6. Write audit records for sensitive mutations. **Implemented for customer and plan mutations.**

### Phases 4–6 — License lifecycle

1. Implement `POST /api/license/generate`.
2. Return a newly generated plaintext license key only at creation time while storing its secure hash and masked hint.
3. Implement activation with status, expiry, customer, existing-device, and device-limit checks in a database transaction.
4. Implement signed activation payloads with key versioning.
5. Implement validation, deactivation, reset-device, suspend, revoke, and extension flows.
6. Record successful and rejected activation events.
7. Prevent race conditions from allowing activation beyond device limits.
8. Add tests for expiry, revoked/suspended licenses, inactive customers, duplicate devices, device limits, reset, and validation windows.

Required endpoints:

- `POST /api/license/generate`
- `POST /api/license/activate`
- `POST /api/license/validate`
- `POST /api/license/deactivate`
- `POST /api/license/reset-device`
- `POST /api/license/revoke`

### Phases 7–9 — Billing and offline architecture

1. Define the billing domain: business profile, customers, products, invoices, invoice items, payments, taxes, and local settings.
2. Implement deterministic money and tax calculations without floating-point currency errors.
3. Define invoice numbering, edit/cancel rules, payment reconciliation, and audit behavior.
4. Create a storage interface usable by an in-browser development adapter and later SQLite.
5. Implement billing CRUD, search, print layouts, reports, loading/error states, and tests.
6. Test the complete browser application locally before introducing Electron.

### Later phases — Electron and Windows distribution

Only after the browser application is stable:

1. Add Electron as a thin desktop wrapper without rewriting React pages. **Implemented as a locked hosted-app shell.**
2. Add local SQLite and secure storage.
3. Add device fingerprinting and local verification of signed license payloads.
4. Package a Windows installer and `.exe`.
5. Test normal billing with no internet on a clean Windows machine.
6. Test initial activation, offline validation window, expiry, suspension, revocation, device reset, updates, and clock-tampering scenarios.

## Mandatory future requirement: Electron auto-update

The Electron desktop application must include a secure, interruption-safe automatic update system.

- Check a trusted update endpoint for the latest compatible application version.
- Download updates in the background when internet is available.
- Verify the downloaded update package and its publisher/signature before installation.
- Reject incomplete, modified, unsigned, incorrectly signed, or untrusted update packages.
- Prompt the user to restart and install only after the update is fully downloaded and verified.
- Normal offline billing must continue when the internet is unavailable or the update service cannot be reached.
- Update checks and downloads must never block invoice creation, payment entry, printing, or other normal billing work.
- An update must never interrupt an active billing operation.
- Defer restart/install prompts while an invoice, payment, print job, database transaction, backup, or migration is active.
- Preserve local SQLite data and create a recoverable backup before any update that includes a database migration.
- Make installation failures recoverable through rollback or a safe retry path.
- Use HTTPS and a trusted publishing channel. Do not allow an update URL supplied by an untrusted client or license payload.
- Keep update signing credentials outside the application source, browser bundle, Electron renderer, and packaged client.
- Record update status and errors locally for troubleshooting without storing secrets.
- Provide clear states such as checking, update available, downloading, ready to restart, installed, failed, and offline.
- Allow administrators to configure update channels only if channels are pre-authorized and signed, for example `stable` and `beta`.

Recommended implementation direction when Electron work begins:

- Run update orchestration in the Electron main process, never the renderer.
- Expose only a minimal, typed IPC bridge for update status and user-approved restart.
- Enable Electron context isolation and disable Node integration in the renderer.
- Prefer a mature signed-update mechanism compatible with the selected Windows installer format.
- Test update behavior while online, offline, during billing, after interrupted downloads, with invalid signatures, and across database-schema upgrades.

## Instruction for the next chat

Read this file, the root `AGENTS.md`, `README.md`, the initial Supabase migration, and the existing source before making changes. Continue from Phase 2 rather than recreating the scaffold or redesigning the completed route structure. Preserve the browser-first architecture and do not add Electron prematurely.
