# AV Smartbilling Mobile

Android-first, offline billing companion for AV Smartbilling. Products, customers, invoices and stock are stored in a local SQLite database. Internet is required only for initial activation and periodic license validation.

## Current first milestone

- Existing AV Smartbilling license activation with mobile-scoped signed grants
- Offline products, stock and customers
- Camera barcode scanning
- Touch-first POS with cash, UPI, card and credit sales
- GST calculation using integer paise
- Local invoice history
- A4 PDF invoice generation, system printing and WhatsApp/share-sheet delivery
- Paired Bluetooth thermal printing with 58 mm and 80 mm receipt layouts
- Date-range sales reports with CSV, Excel and PDF exports
- Optional PIN and fingerprint app lock
- Incremental, per-entity cloud push for products, customers and invoices
- Business and GST identity settings

Cloud restore and multi-device synchronization remain intentionally outside this milestone. The restore screen is included as a disabled preview for a later phase.

The selected master artwork for the Android launcher icon is stored at
`assets/branding/app-logo.png`. Android density and
adaptive-icon resources are generated from that master.

## Run

Flutter is installed locally at `/Users/ittest/development/flutter`. Add it to PATH or invoke it directly:

```bash
cd mobile
/Users/ittest/development/flutter/bin/flutter pub get
/Users/ittest/development/flutter/bin/flutter run
```

The production API defaults to `https://av-smart-billing.vercel.app`. For a local backend, pass the URL at build time. Android emulators reach the host through `10.0.2.2`:

```bash
/Users/ittest/development/flutter/bin/flutter run \
  --dart-define=AVSB_API_URL=http://10.0.2.2:3000
```

Android blocks cleartext HTTP by default in release builds. Use HTTPS for customer builds. Local HTTP is intended only for development.

## Verify

```bash
/Users/ittest/development/flutter/bin/flutter analyze
/Users/ittest/development/flutter/bin/flutter test
/Users/ittest/development/flutter/bin/flutter build apk --debug
```
