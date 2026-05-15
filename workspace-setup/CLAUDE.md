# fythaniya — Unified Workspace

This is a Claude Code workspace that joins the **fythaniya** Flutter apps (local) and the **fythaniya** backend (live, running on a GCP VM) into one session, so that frontend and backend are always edited together and the API contract never drifts.

> فى ثانية ("in a second") — an Egyptian e-payment platform: mobile recharge, bill payment, B2B pay-later, wallet, and rewards.

## Workspace layout

```
~/fythaniya-workspace/
├── flutter-app/
│   ├── client/   → junction to  C:\Users\user\Desktop\Projects\fythaniya\fythaniya    (customer app, pubspec: fythaniya)
│   └── admin/    → junction to  C:\Users\user\Desktop\Projects\fythaniya\admin_app     (admin dashboard, pubspec: fythaniya_admin)
├── backend/      → SSHFS mount of omar_elzanaty_almobarmg@34.79.246.143:/home/omar_elzanaty_almobarmg/fythaniya-api  (LIVE server)
└── CLAUDE.md     → this file
```

`flutter-app/client` and `flutter-app/admin` are Windows directory junctions — editing through them edits the real repo at `C:\Users\user\Desktop\Projects\fythaniya`. `backend/` is a live SSHFS mount: **files shown there are the running production code on the VM.** Edit with care — there is no staging copy.

Note: the local repo at `C:\Users\user\Desktop\Projects\fythaniya` also contains its own `backend/` folder. That is a separate, possibly stale snapshot. The source of truth for the backend is the **mounted** `~/fythaniya-workspace/backend/`, not the local snapshot.

## Architecture overview

Three components, one API contract:

- **Backend** — Node.js (CommonJS) + Express 4 + Prisma 5 (PostgreSQL 16) + Socket.IO 4. Runs under PM2 as a 2-instance cluster behind an nginx reverse proxy. Provides a REST API under `/api/v1` and a Socket.IO channel for realtime request/notification updates.
- **Client app** (`flutter-app/client`) — the customer-facing Flutter app. Clean-ish layering: `core/` (constants, network, theme), `data/models`, `presentation/` (blocs, screens, widgets). Uses Dio for HTTP and `socket_io_client` for realtime.
- **Admin app** (`flutter-app/admin`) — the operations dashboard Flutter app (`fythaniya_admin`). Used by SUPER_ADMIN / TRANSACTION_PROCESSOR / B2B_MANAGER roles to process requests, manage services, approve B2B accounts, and watch SLAs.

Both Flutter apps talk to the **same** backend and **same** API base URL.

## Backend structure (`backend/`)

```
backend/
├── ecosystem.config.js        PM2 config — app name "fythaniya-api", 2-instance cluster
├── package.json               name: fythaniya-backend, v2.0.0
├── prisma/
│   ├── schema.prisma          21 models, 12 enums (Prisma enums MUST be one value per line — see "Gotchas")
│   └── seed.js                seeds admin accounts + service providers
└── src/
    ├── app.js                 entry point — Express app, Socket.IO setup, route mounting
    ├── config/
    │   ├── database.js        Prisma client singleton
    │   └── env.js             reads .env, exposes config.port / config.nodeEnv / etc.
    ├── middleware/index.js     requestLogger, errorHandler, apiLimiter, adminLimiter
    ├── utils/all.js            logger (winston), jwtUtils (verifyUser / verifyAdmin)
    ├── jobs/jobs.js            node-cron jobs (SLA checks, reminders) — started from app.js
    └── modules/
        ├── auth/auth.routes.js         /api/v1/auth
        ├── services/services.routes.js /api/v1/services
        ├── b2b/b2b.routes.js           /api/v1/b2b
        ├── admin/admin.routes.js       /api/v1/admin   (adminLimiter)
        └── user_routes.js              /api/v1/user
```

Route mounting in `src/app.js`:

| Mount path           | Router file                      | Limiter      |
|----------------------|----------------------------------|--------------|
| `/api/v1/auth`       | `modules/auth/auth.routes.js`    | apiLimiter   |
| `/api/v1/services`   | `modules/services/services.routes.js` | apiLimiter |
| `/api/v1/b2b`        | `modules/b2b/b2b.routes.js`      | apiLimiter   |
| `/api/v1/admin`      | `modules/admin/admin.routes.js`  | adminLimiter |
| `/api/v1/user`       | `modules/user_routes.js`         | apiLimiter   |
| `/api/v1/health`     | inline in `app.js`               | none         |

Prisma models (source of truth for every JSON shape): User, Admin, ServiceProvider, SubService, Request, Transaction, B2BAccount, B2BPayLater, GroupPayment, GroupPaymentMember, UserNotification, AdminNotification, RewardTransaction, Voucher, SpendingRecord, VaultDocument, BillReminder, Escalation, AuditLog, SystemConfig.

Realtime (Socket.IO): clients authenticate with a JWT in `handshake.auth.token`. Admins join `admin_room`; users join `user_<userId>`. The server emits request-status and notification events to those rooms.

## Flutter — client app (`flutter-app/client`)

Package name `fythaniya`. RTL Arabic UI (font: Cairo).

```
lib/
├── core/
│   ├── constants/constants.dart   AppConstants (baseUrl, socketUrl, timeouts, keys), AppRoutes, S (Arabic strings),
│   │                              and the k*Names maps that mirror backend enums
│   ├── network/
│   │   ├── api_client.dart        Dio singleton — ApiException.fromDio, token refresh, all REST calls
│   │   └── socket_service.dart    Socket.IO singleton — requestUpdate / newNotification ValueNotifiers
│   └── theme/                     app theme
├── data/
│   └── models/models.dart         all client-side models (fromJson / toJson) — MUST match backend JSON
└── presentation/
    ├── blocs/blocs.dart           all BLoCs
    ├── screens/                   splash, onboarding, auth, home, recharge, bill_payment,
    │                              transactions, notifications, wallet, rewards, profile, b2b
    └── widgets/                   shared widgets
```

The network layer is the API contract surface: **`api_client.dart`** (endpoints) and **`models.dart`** (JSON shapes). `constants.dart` also hard-codes enum-value translation maps (`kCategoryNames`, `kStatusNames`, `kTypeNames`, `kPayLaterStatus`) that mirror backend enums — if a backend enum gains/loses a value, these maps must be updated too.

## Flutter — admin app (`flutter-app/admin`)

Package name `fythaniya_admin`. The whole app is consolidated into four files under `lib/`:

```
lib/
├── admin_core.dart    theme (AC/AT/AD), AdminConstants (baseUrl, socketUrl, tokenKey),
│                      AdminRoutes, and ALL models (AdminModel, RequestItem, DashboardStats,
│                      B2BAccount, AdminNotification, ServiceProvider, SubService, AdminUser, PagedData)
├── admin_api.dart     AdminApiClient (Dio singleton), AdminApiException, all admin REST calls + socket
├── admin_blocs.dart   all admin BLoCs
└── main.dart          app entry, router
```

For the admin app, the API contract surface is **`admin_api.dart`** (endpoints) and the MODELS section of **`admin_core.dart`** (JSON shapes).

## API base URL

| What        | Value                              |
|-------------|------------------------------------|
| REST base   | `http://34.79.246.143/api/v1`      |
| Socket.IO   | `http://34.79.246.143`             |
| Health check| `http://34.79.246.143/api/v1/health` |

The VM runs the Node app on port **3000**; **nginx** reverse-proxies port **80 → 3000**, so the public URL has no port. This URL is hard-coded in three places that must stay in sync:

- `flutter-app/client/lib/core/constants/constants.dart` → `AppConstants.baseUrl` / `socketUrl`
- `flutter-app/admin/lib/admin_core.dart` → `AdminConstants.baseUrl` / `socketUrl`
- backend `.env` → `PORT` (3000) and nginx site config on the VM

The external IP `34.79.246.143` is an **ephemeral** GCP IP — it changes if the VM is stopped and restarted. If the API becomes unreachable, check the VM's current external IP in the GCP console and update both Flutter constants files. (A reserved static IP avoids this.)

## Backend — server / PM2 / deployment facts

- Host: GCP Compute Engine VM `fythaniya-api`, zone `europe-west1-b`, Ubuntu 24.04 LTS, project `dosadrivernew`
- SSH user: `omar_elzanaty_almobarmg`
- App directory on VM: `/home/omar_elzanaty_almobarmg/fythaniya-api`
- Process manager: PM2, app name **`fythaniya-api`**, 2-instance cluster mode
- Stack on the box: Node.js 20 LTS, PostgreSQL 16 (localhost:5432), nginx (:80 → :3000)

Run these over SSH on the VM (`ssh omar_elzanaty_almobarmg@34.79.246.143`):

```bash
# status
pm2 list
pm2 info fythaniya-api

# restart after a backend change (graceful, zero-downtime reload)
pm2 reload fythaniya-api
# hard restart if reload misbehaves
pm2 restart fythaniya-api

# logs
pm2 logs fythaniya-api            # live tail, both instances
pm2 logs fythaniya-api --lines 200   # last 200 lines
pm2 flush fythaniya-api           # clear logs

# after schema / dependency changes
cd /home/omar_elzanaty_almobarmg/fythaniya-api
npm install
npx prisma generate
npx prisma migrate deploy
pm2 reload fythaniya-api
```

## Flutter — run & build commands

Run from `flutter-app/client` or `flutter-app/admin` (or pass `-C`/`cd` first):

```bash
flutter pub get                              # fetch deps (run after pulling or editing pubspec)
flutter run                                  # run on the connected device / emulator
flutter run -d emulator-5554                 # target a specific device
flutter analyze                              # static analysis — run before committing

# release builds
flutter build apk --release                  # Android APK
flutter build appbundle --release            # Android App Bundle (Play Store)
flutter build ios --release                  # iOS (client app only; admin_app has no ios/ folder)
```

The client app has `android/`, `ios/`, and `web/`. The admin app currently has `android/` only.

## ⚠️ Strict rules — API contract sync

These are non-negotiable. The entire point of this workspace is that the backend and the Flutter apps are edited as one unit.

1. **A backend endpoint change is not done until the Flutter side is updated in the SAME task.** Whenever you add, remove, rename, or change the behaviour of an endpoint under `src/modules/**`, you must, in the same task, update the corresponding Flutter service file (`flutter-app/client/lib/core/network/api_client.dart` and/or `flutter-app/admin/lib/admin_api.dart`) **and** the corresponding model in `flutter-app/client/lib/data/models/models.dart` and/or the MODELS section of `flutter-app/admin/lib/admin_core.dart`. Never leave them out of sync. If an endpoint is used by both apps, update both.

2. **Never change a JSON field name in the backend without updating the Flutter model in the same task.** Renaming a field in a Prisma model, a controller response, or a request body means immediately renaming it in every `fromJson` / `toJson` in the affected Flutter models. This includes nested objects (`user`, `serviceProvider`, `subService`, `processor`, `pagination`) and the `data` / `pagination` envelope used by `PagedData`.

Corollaries that follow from the same principle:

- **Enum changes propagate to Dart.** Adding/removing a value in a Prisma enum (`RequestStatus`, `RequestType`, `ServiceCategory`, `PayLaterStatus`, `AdminRole`, etc.) requires updating the mirroring maps in the client's `constants.dart` (`kCategoryNames`, `kStatusNames`, `kTypeNames`, `kPayLaterStatus`) and any `contains([...])` role/status checks in the Dart models.
- **Verify before declaring done.** After a cross-cutting change, grep both Flutter apps for the old field/endpoint/enum name to confirm nothing was missed, and run `flutter analyze` in each affected app.
- **Deploy is part of the task.** A backend change only takes effect once it is live: after editing files in the `backend/` mount, restart the process with `pm2 reload fythaniya-api` on the VM (see commands above). An un-reloaded edit will make the Flutter side look "out of sync" when it is actually just not deployed.

## Gotchas

- **Prisma enum syntax.** `prisma/schema.prisma` enums must list **one value per line**. Prisma 5.20+ rejects single-line `enum X { A B }` with "This line is not an enum value definition". If you ever regenerate or hand-edit the schema, keep values on separate lines.
- **`user_routes.js` require depth.** `src/modules/user_routes.js` sits one level shallower than the other modules (which live in `src/modules/<name>/`). Its requires must be `../config/...`, `../utils/...`, `../middleware/...` — not `../../...`. A wrong path here causes a silent PM2 crash-loop on startup.
- **The `backend/` mount is production.** There is no staging environment. Treat edits there as live changes; reload PM2 deliberately.
- **`.env` placeholders.** Firebase / Twilio / SendGrid keys on the VM are placeholders — push notifications, SMS, and email won't work until real credentials are added.
