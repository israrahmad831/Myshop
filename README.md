# Paint & Hardware Shop Manager

A **shop management** application (not a POS) for paint & hardware stores, built with
**Flutter · Supabase · Hive · Riverpod · Material 3**.

Inventory is managed by hand in the real world — this app stores information,
creates receipts, manages customer *khata* (udhaar), and looks up prices fast.
**Creating a receipt or khata entry never changes stock.**

---

## Features

| Area | What's included |
|------|-----------------|
| **Auth** | Google Sign-In, Email/Password, email verification, forgot/reset password, logout |
| **Multi-shop** | Own multiple shops, each fully isolated; auto-open a single shop, remember the last opened |
| **Members** | Owner / Admin / Staff / Viewer roles, invite by email, change roles, remove |
| **Products** | Image, brand, category, purchase/selling price, **manual** stock, unit, barcode, description; add/edit/delete/search/filter |
| **Receipts** | Independent records with instant product **type-ahead**, quantities, per-line & per-receipt discounts, PDF / print / share, history |
| **Customers** | Name, phone, address, notes; instant search |
| **Khata (Udhaar)** | Per-customer ledger, running balance ("owes you"/"you owe"), edit/delete, fully independent of receipts/inventory |
| **Dashboard** | Today's receipts, totals, khata receivable/payable, recent activity |
| **Offline** | Hive cache + outbox; create/edit offline and auto-sync on reconnect |
| **UI** | Material 3, light/dark, empty/error/loading states, confirmation dialogs |

---

## Architecture

Clean Architecture + Repository pattern + Riverpod.

```
lib/
├─ main.dart                 # boot: Hive + Supabase init
├─ app.dart                  # MaterialApp.router, theme, sync trigger
├─ core/
│  ├─ config/                # env (dart-define), constants
│  ├─ theme/                 # M3 light/dark + theme controller
│  ├─ router/                # go_router + auth/verify redirects
│  ├─ error/                 # Failure types + error mapper
│  ├─ network/               # connectivity
│  ├─ local/                 # Hive boot, LocalCache, Outbox, SyncEngine
│  ├─ data/                  # OfflineRepository mixin (read cache / write outbox)
│  ├─ storage/               # image uploader
│  ├─ utils/                 # formatters, validators
│  └─ widgets/               # AsyncView, EmptyState, dialogs, snackbars
└─ features/<feature>/
   ├─ domain/                # entities
   ├─ data/                  # repositories
   └─ presentation/          # providers + screens

supabase/
├─ schema.sql                # tables, UUID PKs, indexes, triggers, view
├─ policies.sql              # Row Level Security (shop-scoped, role-based)
├─ storage.sql               # product-images bucket + policies
└─ functions.sql             # RPCs: accept_invite, record_product_search, dashboard_summary
```

Each feature repository is **offline-first**: reads hit the network, cache to
Hive, and fall back to cache when offline; writes update the cache and either
hit Supabase or queue in the outbox for replay on reconnect.

---

## 1. Backend setup (Supabase)

1. Create a project at [supabase.com](https://supabase.com).
2. Open **SQL Editor** and run, **in this order**:
   1. `supabase/schema.sql`
   2. `supabase/policies.sql`
   3. `supabase/storage.sql`
   4. `supabase/functions.sql`
3. **Auth → Providers**: enable **Email** and **Google**.
   - For Google, add your OAuth client IDs and set the authorized redirect.
4. **Auth → URL Configuration**: add the redirect URL
   `io.shopmanager://login-callback` (used for email verification & password reset).
5. Grab your **Project URL** and **anon public key** from **Project Settings → API**.

Row Level Security is enabled on every table — every query is automatically
scoped to shops the signed-in user belongs to, with role checks
(owner > admin > staff > viewer).

---

## 2. Flutter setup

> Requires the Flutter SDK (>= 3.24 recommended). Install from
> [flutter.dev](https://docs.flutter.dev/get-started/install).

```bash
# From the project root — generate the platform folders (android/ios/etc.)
flutter create .

# Install dependencies
flutter pub get
```

### Run with your keys (no secrets are committed)

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=YOUR_IOS_CLIENT_ID.apps.googleusercontent.com
```

Tip: put these in a `run.json`/VS Code launch config or a `--dart-define-from-file`
JSON so you don't retype them.

---

## 3. Google Sign-In platform config

- **Android**: add your app's SHA-1/SHA-256 to the Supabase/Google console;
  put `google-services.json` in `android/app/` (git-ignored).
- **iOS**: add `GoogleService-Info.plist` to `ios/Runner/` and set the reversed
  client ID URL scheme in `Info.plist`.

## 4. Deep links (email verification / password reset)

Register the custom scheme `io.shopmanager` so Supabase redirects reopen the app:

- **Android** — intent filter in `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="io.shopmanager" android:host="login-callback"/>
  </intent-filter>
  ```
- **iOS** — add a URL type with scheme `io.shopmanager` in `Info.plist`.

When a recovery link opens the app, `app.dart` listens for
`AuthChangeEvent.passwordRecovery` and routes to the reset-password screen.

---

## Data model (summary)

- `profiles` — mirror of `auth.users` (name/avatar), kept in sync by a trigger.
- `shops` — owned by a profile; each holds name/address/phone/logo/currency/footer.
- `shop_members` — membership + role. Owner auto-added by a trigger on shop create.
- `shop_invites` — invite-by-email; accepted via the `accept_invite` RPC.
- `products` — info only; `current_stock` is **manual**. Trigram index for type-ahead.
- `customers` — contacts.
- `receipts` + `receipt_items` — independent records; per-shop sequential
  `receipt_number` assigned by a concurrency-safe trigger. No stock effects.
- `khata_transactions` — ledger entries; running balance via the
  `customer_khata_balances` view (also computed client-side for offline).

---

## Notes & next steps

- **Reports** (daily/monthly/top-searched/low-stock) are backed by data already
  present (`product_search_stats`, receipts, `dashboard_summary` RPC) — screens
  can be added under `features/reports/`.
- **Notifications** for unpaid khata: `flutter_local_notifications` is included;
  schedule reminders from the khata module.
- Run `flutter analyze` and `flutter test` before release.

---

## License

Proprietary — built for a paint & hardware business.
