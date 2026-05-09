# Private Chat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved Flutter Android private chat app, Node.js/Express/PostgreSQL backend, deployment tooling, APK outputs, and Chinese documentation in verified phases.

**Architecture:** The backend owns identity, permissions, REST APIs, PostgreSQL persistence, WebSocket delivery, offline sync, burn-state coordination, file storage, and WebRTC signaling. The Flutter app owns Telegram-style UI, local encrypted storage, secure credentials, Android secure-window protection, media capture/compression, and WebRTC peer connections. Each phase ends with tests or runnable checks before moving to the next phase.

**Tech Stack:** Flutter/Dart, Riverpod, sqflite, flutter_secure_storage, AES-256-GCM, Android MethodChannel, Node.js, Express, ws, PostgreSQL, Jest, supertest, WebRTC, systemd, ufw.

---

## File Structure Map

### Root

- `.gitignore`: ignore build outputs, local secrets, generated APKs, and transient tool files.
- `README.md`: Chinese quick start and delivery index.
- `docs/development.md`: Chinese developer guide for server address changes, avatars, stickers, backend, deployment, and APK builds.
- `docs/superpowers/specs/2026-05-09-private-chat-design.md`: approved design spec.
- `docs/superpowers/plans/2026-05-09-private-chat-implementation.md`: this plan.
- `dist/`: generated APKs and delivery artifacts; ignored except optional manifest files.

### Backend: `server/`

- `server/package.json`: backend scripts and dependencies.
- `server/app.js`: process entrypoint; starts API and WebSocket servers.
- `server/.env.example`: LAN and public-domain config examples.
- `server/database/db.js`: PostgreSQL pool and transaction helpers.
- `server/database/migrate.js`: migration runner.
- `server/database/migrations/001_initial.sql`: schema for users, contacts, groups, messages, reads, media, stickers, deletions.
- `server/src/config.js`: environment parsing with defaults.
- `server/src/auth/token.js`: JWT-style signed token creation and verification.
- `server/src/middleware/auth.js`: Express auth middleware.
- `server/src/api/authRoutes.js`: register, validate, account availability.
- `server/src/api/userRoutes.js`: avatar, account deletion, profile.
- `server/src/api/contactRoutes.js`: contact list and add contact.
- `server/src/api/groupRoutes.js`: create groups, manage roles and members.
- `server/src/api/messageRoutes.js`: offline sync.
- `server/src/api/mediaRoutes.js`: upload/download local files.
- `server/src/api/stickerRoutes.js`: official sticker pack list and zip download.
- `server/src/api/healthRoutes.js`: health endpoint.
- `server/src/services/userService.js`: account validation, uniqueness, token version, soft delete.
- `server/src/services/groupService.js`: group code generation and role checks.
- `server/src/services/messageService.js`: message persistence, read receipts, revoke, burn state, offline sync.
- `server/src/services/mediaService.js`: file limits, safe names, storage paths.
- `server/src/websocket/socketServer.js`: WebSocket auth, routing, online sessions, reconnect support.
- `server/src/webrtc/signaling.js`: call invite, accept, reject, hangup, SDP, ICE relay.
- `server/src/jobs/burnCleanupJob.js`: server-side burn expiry fallback.
- `server/src/jobs/accountPurgeJob.js`: 30 day soft-delete purge job.
- `server/src/utils/errors.js`: typed API errors.
- `server/src/utils/ids.js`: UUID and 8 digit group code helpers.
- `server/tests/*.test.js`: Jest and supertest coverage.
- `server/deploy.sh`: deployment to `/home/eapp/chat_server`.

### Flutter App: `app/`

- `app/pubspec.yaml`: Flutter dependencies and assets.
- `app/lib/main.dart`: app bootstrap, localization, providers, theme.
- `app/lib/core/config/app_config.dart`: `--dart-define` API and WS URLs.
- `app/lib/core/constants/avatar_catalog.dart`: 9 fixed avatars.
- `app/lib/core/constants/sticker_catalog.dart`: official sticker pack index model.
- `app/lib/core/themes/app_theme.dart`: light and dark Telegram-style themes.
- `app/lib/core/utils/account_validator.dart`: display name and account validation.
- `app/lib/core/utils/time_format.dart`: timestamps and call duration formatting.
- `app/lib/core/utils/crypto_service.dart`: AES-256-GCM helpers and hash names.
- `app/lib/core/services/api_service.dart`: HTTP client.
- `app/lib/core/services/secure_storage_service.dart`: token, user, and master key.
- `app/lib/core/services/local_database_service.dart`: encrypted sqflite access.
- `app/lib/core/services/websocket_service.dart`: auth, reconnect, event stream.
- `app/lib/core/services/webrtc_service.dart`: peer connection orchestration.
- `app/lib/core/services/media_service.dart`: compression, recording metadata, media cache.
- `app/lib/core/services/secure_window_service.dart`: secure window calls.
- `app/lib/models/*.dart`: user, group, member, message, media, call, settings.
- `app/lib/providers/*.dart`: auth, chat, group, call, settings, connectivity providers.
- `app/lib/screens/*.dart`: create account, chat list, chat, group, call, settings, app lock.
- `app/lib/widgets/*.dart`: avatars, bubbles, timers, composer, emoji, stickers, media tiles, call controls.
- `app/lib/native/secure_window_channel.dart`: MethodChannel wrapper.
- `app/android/app/src/main/kotlin/.../MainActivity.kt`: Android `FLAG_SECURE` MethodChannel implementation.
- `app/test/*.dart`: unit and widget tests.

---

## Phase 0: Environment and Scaffold

### Task 0.1: Capture Toolchain State

**Files:**
- Create: `docs/environment-check.md`

- [ ] **Step 1: Run local tool checks**

Run:

```powershell
git --version
node --version
npm --version
flutter --version
java -version
adb version
psql --version
```

Expected: each installed tool prints a version. Missing tools print command-not-found errors that must be copied into `docs/environment-check.md`.

- [ ] **Step 2: Write the environment report**

Create `docs/environment-check.md` with this structure:

```markdown
# Environment Check

Date: 2026-05-09

## Installed

- Git: record the exact `git --version` output, or record the exact command-not-found error.
- Node.js: record the exact `node --version` output, or record the exact command-not-found error.
- npm: record the exact `npm --version` output, or record the exact command-not-found error.
- Flutter: record the exact `flutter --version` output, or record the exact command-not-found error.
- Java/JDK: record the exact `java -version` output, or record the exact command-not-found error.
- Android adb: record the exact `adb version` output, or record the exact command-not-found error.
- PostgreSQL psql: record the exact `psql --version` output, or record the exact command-not-found error.

## Build Implications

- Backend development: write `ready` or `blocked by` followed by the missing command name.
- Flutter development: write `ready` or `blocked by` followed by the missing command name.
- APK build: write `ready` or `blocked by` followed by the missing Android/Flutter/JDK component.
- Demo video: write `ready` or `blocked by` followed by the missing device, emulator, or recorder.
```

- [ ] **Step 3: Commit**

Run:

```powershell
git add docs/environment-check.md
git commit -m "docs: capture environment check"
```

Expected: commit succeeds.

### Task 0.2: Scaffold Backend Project

**Files:**
- Create: `server/package.json`
- Create: `server/app.js`
- Create: `server/src/config.js`
- Create: `server/src/api/healthRoutes.js`
- Create: `server/tests/health.test.js`

- [ ] **Step 1: Add backend dependency manifest**

Create `server/package.json`:

```json
{
  "name": "private-chat-server",
  "version": "0.1.0",
  "private": true,
  "type": "commonjs",
  "scripts": {
    "start": "node app.js",
    "dev": "node app.js",
    "test": "jest --runInBand",
    "migrate": "node database/migrate.js"
  },
  "dependencies": {
    "bcryptjs": "^2.4.3",
    "cors": "^2.8.5",
    "dotenv": "^16.4.7",
    "express": "^4.21.2",
    "jsonwebtoken": "^9.0.2",
    "mime-types": "^2.1.35",
    "multer": "^1.4.5-lts.1",
    "pg": "^8.13.1",
    "uuid": "^11.0.5",
    "ws": "^8.18.0"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "supertest": "^7.0.0"
  }
}
```

- [ ] **Step 2: Add config module**

Create `server/src/config.js` exporting parsed ports, database URL, JWT secret, storage path, LAN URL, public URL, and offline retention days.

- [ ] **Step 3: Add health route and app entry**

Create `server/src/api/healthRoutes.js` with `GET /api/health` returning `{ "ok": true }`. Create `server/app.js` to mount JSON middleware, CORS, health route, and start API server only when run directly.

- [ ] **Step 4: Add health test**

Create `server/tests/health.test.js`:

```javascript
const request = require('supertest');
const { createApp } = require('../app');

test('GET /api/health returns ok', async () => {
  const app = createApp();
  const res = await request(app).get('/api/health');
  expect(res.status).toBe(200);
  expect(res.body).toEqual({ ok: true });
});
```

- [ ] **Step 5: Run tests**

Run:

```powershell
cd server
npm install
npm test
```

Expected: health test passes.

- [ ] **Step 6: Commit**

Run:

```powershell
git add server
git commit -m "feat: scaffold backend service"
```

Expected: commit succeeds.

### Task 0.3: Scaffold Flutter Project

**Files:**
- Create/Modify: `app/`
- Create: `app/lib/core/config/app_config.dart`
- Create: `app/lib/core/utils/account_validator.dart`
- Create: `app/test/account_validator_test.dart`

- [ ] **Step 1: Create Flutter app**

Run:

```powershell
flutter create app --platforms android
```

Expected: Flutter creates `app/` with Android project files.

- [ ] **Step 2: Add required dependencies**

Modify `app/pubspec.yaml` to include these dependencies:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  http: ^1.2.2
  web_socket_channel: ^3.0.1
  flutter_secure_storage: ^9.2.2
  sqflite: ^2.4.1
  path_provider: ^2.1.5
  path: ^1.9.0
  cryptography: ^2.7.0
  uuid: ^4.5.1
  image: ^4.5.2
  file_picker: ^8.1.7
  record: ^5.2.0
  permission_handler: ^11.3.1
  flutter_webrtc: ^0.12.5
  intl: ^0.19.0
```

- [ ] **Step 3: Add account validator**

Create `app/lib/core/utils/account_validator.dart`:

```dart
class AccountValidator {
  static final RegExp accountPattern = RegExp(r'^@[A-Za-z]{1,9}$');

  static String? validateDisplayName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '请输入名字';
    if (trimmed.runes.length > 24) return '名字最多24字符';
    return null;
  }

  static String? validateAccount(String value) {
    if (!accountPattern.hasMatch(value)) {
      return '账号必须是英文，且以@开头';
    }
    return null;
  }
}
```

- [ ] **Step 4: Add account validator tests**

Create `app/test/account_validator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/utils/account_validator.dart';

void main() {
  test('accepts valid account', () {
    expect(AccountValidator.validateAccount('@ZCMX'), isNull);
  });

  test('rejects account without at prefix', () {
    expect(AccountValidator.validateAccount('ZCMX'), '账号必须是英文，且以@开头');
  });

  test('rejects account with digits', () {
    expect(AccountValidator.validateAccount('@ZCMX1'), '账号必须是英文，且以@开头');
  });

  test('rejects blank display name', () {
    expect(AccountValidator.validateDisplayName('   '), '请输入名字');
  });
}
```

- [ ] **Step 5: Run Flutter tests**

Run:

```powershell
cd app
flutter pub get
flutter test
```

Expected: tests pass.

- [ ] **Step 6: Commit**

Run:

```powershell
git add app
git commit -m "feat: scaffold flutter app"
```

Expected: commit succeeds.

---

## Phase 1: Backend Core

### Task 1.1: Database Schema and Migration Runner

**Files:**
- Create: `server/database/db.js`
- Create: `server/database/migrate.js`
- Create: `server/database/migrations/001_initial.sql`
- Create: `server/tests/schema.test.js`

- [ ] **Step 1: Add SQL migration**

Create `server/database/migrations/001_initial.sql` with tables for `users`, `contacts`, `groups`, `group_members`, `messages`, `message_reads`, `media_files`, `sticker_packs`, and `account_deletions`. Enforce `users.account` uniqueness, account length <= 10, group role enum values, message status enum values, and group code uniqueness.

- [ ] **Step 2: Add migration runner**

Create `server/database/db.js` for a `pg.Pool` and `server/database/migrate.js` that reads migration files in order, records applied files in `schema_migrations`, and wraps each migration in a transaction.

- [ ] **Step 3: Add schema smoke test**

Create `server/tests/schema.test.js` that uses a test database URL from `TEST_DATABASE_URL`, runs migrations, and verifies `users`, `groups`, and `messages` exist. If `TEST_DATABASE_URL` is missing, skip with a clear message.

- [ ] **Step 4: Run migration test**

Run:

```powershell
cd server
npm test -- schema.test.js
```

Expected: PASS when `TEST_DATABASE_URL` is set, otherwise SKIP with a clear message.

- [ ] **Step 5: Commit**

Run:

```powershell
git add server/database server/tests/schema.test.js
git commit -m "feat: add database schema"
```

Expected: commit succeeds.

### Task 1.2: Authentication and Users

**Files:**
- Create: `server/src/auth/token.js`
- Create: `server/src/middleware/auth.js`
- Create: `server/src/services/userService.js`
- Create: `server/src/api/authRoutes.js`
- Create: `server/src/api/userRoutes.js`
- Modify: `server/app.js`
- Create: `server/tests/auth.test.js`

- [ ] **Step 1: Write auth tests**

Create tests for:

- `GET /api/users/check-account?account=@ZCMX` returns available.
- `POST /api/auth/register` rejects `ZCMX`.
- `POST /api/auth/register` rejects `@ZCMX1`.
- `POST /api/auth/register` accepts `@ZCMX`, returns numeric `id`, token, and `avatarIndex` 0-8.
- duplicate account returns 409 and message `账号已被注册`.
- `POST /api/auth/validate` accepts a valid token.

- [ ] **Step 2: Implement token and auth middleware**

Use `jsonwebtoken` with `JWT_SECRET` from config. Token payload includes `userId`, `account`, and `tokenVersion`.

- [ ] **Step 3: Implement user service and routes**

Implement account regex `^@[A-Za-z]{1,9}$`, display name rune-length approximation using JavaScript string spread (`[...displayName].length`), random avatar index 0-8, and soft-delete exclusion.

- [ ] **Step 4: Run auth tests**

Run:

```powershell
cd server
npm test -- auth.test.js
```

Expected: all auth tests pass.

- [ ] **Step 5: Commit**

Run:

```powershell
git add server/src server/tests/auth.test.js server/app.js
git commit -m "feat: add account registration"
```

Expected: commit succeeds.

### Task 1.3: Contacts, Groups, and Permissions

**Files:**
- Create: `server/src/services/groupService.js`
- Create: `server/src/api/contactRoutes.js`
- Create: `server/src/api/groupRoutes.js`
- Modify: `server/app.js`
- Create: `server/tests/groups.test.js`

- [ ] **Step 1: Write group tests**

Create tests for:

- adding a contact by account.
- creating a group requires at least 2 selected member user IDs in addition to the owner.
- generated `groupCode` is exactly 8 digits.
- owner can rename group.
- admin can rename group and remove members.
- member cannot remove another member.
- owner can set admin.

- [ ] **Step 2: Implement contact routes**

Add authenticated `GET /api/contacts` and `POST /api/contacts`.

- [ ] **Step 3: Implement group service**

Generate 8 digit group codes with collision retry. Store owner in `group_members` with role `owner`, selected users with role `member`, and enforce role checks.

- [ ] **Step 4: Implement group routes**

Add create, get, patch, add member, remove member, set role, and soft delete where owner is required.

- [ ] **Step 5: Run group tests**

Run:

```powershell
cd server
npm test -- groups.test.js
```

Expected: all group tests pass.

- [ ] **Step 6: Commit**

Run:

```powershell
git add server/src server/tests/groups.test.js server/app.js
git commit -m "feat: add contacts and groups"
```

Expected: commit succeeds.

### Task 1.4: Messages, WebSocket, Burn State, and Offline Sync

**Files:**
- Create: `server/src/services/messageService.js`
- Create: `server/src/websocket/socketServer.js`
- Create: `server/src/jobs/burnCleanupJob.js`
- Create: `server/src/api/messageRoutes.js`
- Modify: `server/app.js`
- Create: `server/tests/messages.test.js`
- Create: `server/tests/websocket.test.js`

- [ ] **Step 1: Write message tests**

Create tests for:

- persisting a private text message.
- group message fan-out target list includes active members.
- read receipt creates `message_reads`.
- revoke succeeds within 5 minutes and fails after 5 minutes.
- burn start records `burn_started_at`.
- sync returns messages from the last 7 days only.

- [ ] **Step 2: Implement message service**

Implement create, read, delivered, revoke, burn start, burn expire, and sync methods.

- [ ] **Step 3: Implement WebSocket server**

Authenticate first `auth` event, map user IDs to sockets, route message events, and broadcast group events to online members.

- [ ] **Step 4: Implement burn cleanup job**

Run periodic query for burn messages whose `burn_started_at + burn_after` has expired, mark `burned`, and notify connected users.

- [ ] **Step 5: Run tests**

Run:

```powershell
cd server
npm test -- messages.test.js websocket.test.js
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

Run:

```powershell
git add server/src server/tests/messages.test.js server/tests/websocket.test.js server/app.js
git commit -m "feat: add messaging and websocket sync"
```

Expected: commit succeeds.

### Task 1.5: Media, Stickers, Account Deletion, and Deployment

**Files:**
- Create: `server/src/services/mediaService.js`
- Create: `server/src/api/mediaRoutes.js`
- Create: `server/src/api/stickerRoutes.js`
- Create: `server/src/jobs/accountPurgeJob.js`
- Create: `server/deploy.sh`
- Create: `server/.env.example`
- Modify: `server/app.js`
- Create: `server/tests/media.test.js`
- Create: `server/tests/deploy-script.test.js`

- [ ] **Step 1: Write media and deletion tests**

Create tests for:

- rejecting files larger than 50 MB.
- storing allowed upload metadata in `media_files`.
- returning sticker pack metadata.
- account deletion sets `deleted_at`, writes `account_deletions`, increments token version, and excludes user from account checks.

- [ ] **Step 2: Implement media and sticker routes**

Use `multer` local temporary upload, safe file names, SHA-256 metadata, and storage under `server/storage/media`. Serve sticker zips from `server/storage/stickers`.

- [ ] **Step 3: Implement account deletion**

Add authenticated `DELETE /api/users/me` requiring account confirmation in the request body. Soft delete and schedule purge after 30 days.

- [ ] **Step 4: Add deployment script**

Create executable `server/deploy.sh` that installs dependencies, creates PostgreSQL database/user, runs migrations, installs systemd unit, opens ports 3000, 3001, and UDP 5000-6000, and checks `/api/health`. Include no destructive reset by default.

- [ ] **Step 5: Run backend test suite**

Run:

```powershell
cd server
npm test
```

Expected: all backend tests pass or database-dependent tests skip only when test DB is missing.

- [ ] **Step 6: Commit**

Run:

```powershell
git add server
git commit -m "feat: add media storage and deployment"
```

Expected: commit succeeds.

---

## Phase 2: Flutter Core and Auth

### Task 2.1: App Config, Theme, Localization, and Avatars

**Files:**
- Create: `app/lib/core/config/app_config.dart`
- Create: `app/lib/core/themes/app_theme.dart`
- Create: `app/lib/core/constants/avatar_catalog.dart`
- Create: `app/lib/widgets/default_avatar.dart`
- Create: `app/lib/l10n/app_zh.arb`
- Create: `app/lib/l10n/app_en.arb`
- Modify: `app/lib/main.dart`
- Create: `app/test/avatar_catalog_test.dart`

- [ ] **Step 1: Write avatar catalog test**

Test that the catalog has exactly 9 avatars and each index is 0-8.

- [ ] **Step 2: Implement config and theme**

Read `API_BASE_URL` and `WS_URL` from `String.fromEnvironment` with LAN defaults. Add light and dark Telegram-style themes.

- [ ] **Step 3: Implement localization**

Add Chinese and English strings for account creation, chat, settings, errors, and connection status. Configure `flutter_localizations`.

- [ ] **Step 4: Implement avatar widget**

Render fixed colored circular avatars with Material icons. Do not expose upload or camera controls.

- [ ] **Step 5: Run Flutter tests**

Run:

```powershell
cd app
flutter test
```

Expected: tests pass.

- [ ] **Step 6: Commit**

Run:

```powershell
git add app
git commit -m "feat: add flutter app shell"
```

Expected: commit succeeds.

### Task 2.2: Secure Storage, API Client, Auth Provider, and Account Creation UI

**Files:**
- Create: `app/lib/models/user.dart`
- Create: `app/lib/core/services/api_service.dart`
- Create: `app/lib/core/services/secure_storage_service.dart`
- Create: `app/lib/providers/auth_provider.dart`
- Create: `app/lib/screens/create_account_screen.dart`
- Create: `app/lib/screens/chat_list_screen.dart`
- Modify: `app/lib/main.dart`
- Create: `app/test/create_account_screen_test.dart`

- [ ] **Step 1: Write widget tests**

Test that invalid account text shows `账号必须是英文，且以@开头`, blank name shows `请输入名字`, and valid form enables the start button.

- [ ] **Step 2: Implement secure storage**

Store token, user JSON, and a generated 32 byte base64 master key in `flutter_secure_storage`. Generate the master key when missing after successful registration.

- [ ] **Step 3: Implement API client and auth provider**

Add register, validate, check account, logout local, and an `deleteAccount(accountConfirmation)` API method that will be called by the settings flow in Task 4.2.

- [ ] **Step 4: Implement account creation screen**

Use the approved validation rules, real-time account availability call with debounce, and no onboarding screens.

- [ ] **Step 5: Implement initial route logic**

On app start, validate token. Valid credentials enter `ChatListScreen`; invalid credentials clear storage and show account creation.

- [ ] **Step 6: Run tests**

Run:

```powershell
cd app
flutter test
```

Expected: tests pass.

- [ ] **Step 7: Commit**

Run:

```powershell
git add app
git commit -m "feat: add account creation flow"
```

Expected: commit succeeds.

---

## Phase 3: Flutter Messaging

### Task 3.1: Local Encryption and Database

**Files:**
- Create: `app/lib/core/utils/crypto_service.dart`
- Create: `app/lib/core/services/local_database_service.dart`
- Create: `app/lib/models/message.dart`
- Create: `app/test/crypto_service_test.dart`
- Create: `app/test/local_database_service_test.dart`

- [ ] **Step 1: Write crypto tests**

Test AES-256-GCM encrypt/decrypt round trip, wrong key failure, and stable hash filename generation.

- [ ] **Step 2: Implement crypto service**

Use `cryptography` package AES-GCM with 32 byte keys and random nonce.

- [ ] **Step 3: Implement local database service**

Create encrypted message persistence using `sqflite`, with encrypted content blob and searchable non-sensitive fields.

- [ ] **Step 4: Run tests**

Run:

```powershell
cd app
flutter test test/crypto_service_test.dart test/local_database_service_test.dart
```

Expected: tests pass.

- [ ] **Step 5: Commit**

Run:

```powershell
git add app
git commit -m "feat: add encrypted local storage"
```

Expected: commit succeeds.

### Task 3.2: WebSocket Client, Chat Providers, and Chat UI

**Files:**
- Create: `app/lib/core/services/websocket_service.dart`
- Create: `app/lib/providers/chat_provider.dart`
- Create: `app/lib/providers/group_provider.dart`
- Create: `app/lib/screens/chat_screen.dart`
- Create: `app/lib/screens/group_screen.dart`
- Create: `app/lib/widgets/chat_bubble.dart`
- Create: `app/lib/widgets/message_composer.dart`
- Create: `app/test/chat_bubble_test.dart`

- [ ] **Step 1: Write UI tests**

Test that my messages align right and use green styling, other messages align left and use gray styling, and burn messages show the timer area.

- [ ] **Step 2: Implement WebSocket service**

Authenticate after connect, expose a typed event stream, send events, and reconnect with exponential backoff.

- [ ] **Step 3: Implement chat providers**

Load local messages, sync from backend, send text, handle delivered/read/revoked/burn events, and update unread counts.

- [ ] **Step 4: Implement chat screens**

Add top bars, message list animation, composer, emoji panel entry button, attachment button, and group sender labels.

- [ ] **Step 5: Run tests**

Run:

```powershell
cd app
flutter test
```

Expected: tests pass.

- [ ] **Step 6: Commit**

Run:

```powershell
git add app
git commit -m "feat: add chat messaging ui"
```

Expected: commit succeeds.

### Task 3.3: Burn Timers and Android Secure Window

**Files:**
- Create: `app/lib/core/services/secure_window_service.dart`
- Create: `app/lib/native/secure_window_channel.dart`
- Modify: `app/android/app/src/main/kotlin/*/MainActivity.kt`
- Create: `app/lib/widgets/burn_timer.dart`
- Modify: `app/lib/screens/chat_screen.dart`
- Modify: `app/lib/screens/group_screen.dart`
- Create: `app/test/burn_timer_test.dart`

- [ ] **Step 1: Write timer tests**

Test that `BurnTimer` formats 5, 10, 30, and 60 second durations and calls expiry callback at zero.

- [ ] **Step 2: Implement secure window MethodChannel**

Add Dart service methods `enable()`, `disable()`, and `setEnabled(bool)`. Add Android Kotlin channel that calls `window.setFlags(LayoutParams.FLAG_SECURE, LayoutParams.FLAG_SECURE)` and clears the flag when disabled.

- [ ] **Step 3: Wire secure surfaces**

Force secure window on burn mode and call screens. Respect global privacy setting for all chat screens.

- [ ] **Step 4: Implement burn UI**

Add flame menu options 5 seconds, 10 seconds, 30 seconds, 1 minute, and off. Show countdown in bubble and animate fade/shrink removal.

- [ ] **Step 5: Run tests and Android build check**

Run:

```powershell
cd app
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.103:3000/api --dart-define=WS_URL=ws://192.168.1.103:3001/ws
```

Expected: tests pass and debug APK builds if Android toolchain is available.

- [ ] **Step 6: Commit**

Run:

```powershell
git add app
git commit -m "feat: add burn timers and secure window"
```

Expected: commit succeeds.

---

## Phase 4: Media, Stickers, Settings, and Calls

### Task 4.1: Media, Emoji, Stickers, and Cache Cleanup

**Files:**
- Create: `app/lib/core/services/media_service.dart`
- Create: `app/lib/core/constants/sticker_catalog.dart`
- Create: `app/lib/widgets/emoji_picker.dart`
- Create: `app/lib/widgets/sticker_pack_viewer.dart`
- Create: `app/lib/widgets/media_message_tile.dart`
- Modify: `app/lib/widgets/message_composer.dart`
- Create: `app/test/media_service_test.dart`

- [ ] **Step 1: Write media tests**

Test image target width cap, 50 MB file rejection, 60 second voice duration rejection, and hashed media filename generation.

- [ ] **Step 2: Implement media service**

Add image compression, media directory creation, upload/download calls, and cache cleanup preserving encrypted database records.

- [ ] **Step 3: Implement emoji and sticker UI**

Add recent 24 emoji local persistence and official sticker pack display from server metadata.

- [ ] **Step 4: Run tests**

Run:

```powershell
cd app
flutter test
```

Expected: tests pass.

- [ ] **Step 5: Commit**

Run:

```powershell
git add app
git commit -m "feat: add media stickers and cache cleanup"
```

Expected: commit succeeds.

### Task 4.2: Settings, Privacy, Notifications, and Account Deletion

**Files:**
- Create: `app/lib/models/settings.dart`
- Create: `app/lib/providers/settings_provider.dart`
- Create: `app/lib/screens/settings_screen.dart`
- Create: `app/lib/screens/app_lock_screen.dart`
- Modify: `app/lib/providers/auth_provider.dart`
- Create: `app/test/settings_screen_test.dart`

- [ ] **Step 1: Write settings tests**

Test language choices, avatar selection limited to 9 indexes, secure screen switch calls secure window service, and account deletion requires exact account confirmation.

- [ ] **Step 2: Implement settings provider**

Persist settings locally, apply language immediately, and expose privacy, notification, chat, data usage, and theme settings.

- [ ] **Step 3: Implement settings screen**

Add all approved menu sections without avatar upload/camera options.

- [ ] **Step 4: Implement account deletion flow**

Require typing the account, call `DELETE /api/users/me`, clear local database and secure storage, then navigate to account creation.

- [ ] **Step 5: Run tests**

Run:

```powershell
cd app
flutter test
```

Expected: tests pass.

- [ ] **Step 6: Commit**

Run:

```powershell
git add app
git commit -m "feat: add settings and account deletion"
```

Expected: commit succeeds.

### Task 4.3: WebRTC One-to-One and Mesh Group Calls

**Files:**
- Create: `app/lib/models/call_session.dart`
- Create: `app/lib/core/services/webrtc_service.dart`
- Create: `app/lib/providers/call_provider.dart`
- Create: `app/lib/screens/call_screen.dart`
- Create: `app/lib/widgets/call_controls.dart`
- Modify: `server/src/webrtc/signaling.js`
- Modify: `server/src/websocket/socketServer.js`
- Create: `server/tests/calls.test.js`
- Create: `app/test/call_provider_test.dart`

- [ ] **Step 1: Write signaling tests**

Test `call.invite`, `call.accept`, `call.reject`, `call.hangup`, `call.sdp`, and `call.ice` are relayed only to intended online participants.

- [ ] **Step 2: Implement backend signaling**

Add call rooms, participant state, max 8 group participants, and event relay.

- [ ] **Step 3: Implement Flutter WebRTC service**

Use `flutter_webrtc`, default STUN `stun:stun.l.google.com:19302`, local media capture, peer connection map for mesh group calls, speaker/mic/camera toggles, and hangup cleanup.

- [ ] **Step 4: Implement call UI**

Add incoming call screen, outgoing call state, active call duration, one-to-one controls, group grid, voice avatar chips, and local-only mute for group members.

- [ ] **Step 5: Run tests**

Run:

```powershell
cd server
npm test -- calls.test.js
cd ..\app
flutter test test/call_provider_test.dart
```

Expected: tests pass. Manual device verification is still required for real camera/microphone media.

- [ ] **Step 6: Commit**

Run:

```powershell
git add server app
git commit -m "feat: add webrtc call flows"
```

Expected: commit succeeds.

---

## Phase 5: Documentation, Deployment, APKs, and Demo

### Task 5.1: Chinese Documentation

**Files:**
- Create: `README.md`
- Create: `docs/development.md`

- [ ] **Step 1: Write README**

Cover project purpose, directory layout, local backend run, local Flutter run, LAN config, public domain config, and delivery artifact locations.

- [ ] **Step 2: Write development guide**

Cover:

- changing `API_BASE_URL` and `WS_URL`.
- replacing the 9 default avatars while preserving fixed catalog behavior.
- adding server sticker packs under `server/storage/stickers`.
- deploying to `/home/eapp/chat_server`.
- building Debug and Release APKs.
- known limits of screenshot attempt detection and WebRTC Mesh.

- [ ] **Step 3: Commit**

Run:

```powershell
git add README.md docs/development.md
git commit -m "docs: add Chinese development guide"
```

Expected: commit succeeds.

### Task 5.2: Deploy Server

**Files:**
- Modify: `server/deploy.sh`
- Create: `docs/deployment-result.md`

- [ ] **Step 1: Copy server to target**

Run:

```powershell
scp -r server eapp@192.168.1.103:/home/eapp/chat_server
```

Expected: files copy to the target host.

- [ ] **Step 2: Run deploy script**

Run:

```powershell
ssh eapp@192.168.1.103 "cd /home/eapp/chat_server && chmod +x deploy.sh && ./deploy.sh"
```

Expected: dependencies install, migrations run, service starts, and health check passes.

- [ ] **Step 3: Verify endpoints**

Run:

```powershell
curl http://192.168.1.103:3000/api/health
curl http://wdsj.fun:3000/api/health
```

Expected: both return `{"ok":true}` if public DNS and firewall are routed correctly. If `wdsj.fun` fails but LAN works, record the DNS/firewall/router issue.

- [ ] **Step 4: Record deployment result**

Create `docs/deployment-result.md` with exact commands, success output, and any blockers.

- [ ] **Step 5: Commit**

Run:

```powershell
git add docs/deployment-result.md server/deploy.sh
git commit -m "docs: record deployment result"
```

Expected: commit succeeds.

### Task 5.3: Build APKs

**Files:**
- Create: `dist/manifest.md`

- [ ] **Step 1: Build debug APK**

Run:

```powershell
cd app
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.103:3000/api --dart-define=WS_URL=ws://192.168.1.103:3001/ws
```

Expected: debug APK builds under `app/build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 2: Build release APK**

Run:

```powershell
cd app
flutter build apk --release --dart-define=API_BASE_URL=http://wdsj.fun:3000/api --dart-define=WS_URL=ws://wdsj.fun:3001/ws
```

Expected: release APK builds under `app/build/app/outputs/flutter-apk/app-release.apk`.

- [ ] **Step 3: Copy APKs to dist**

Run:

```powershell
New-Item -ItemType Directory -Force dist
Copy-Item app\build\app\outputs\flutter-apk\app-debug.apk dist\private-chat-debug.apk
Copy-Item app\build\app\outputs\flutter-apk\app-release.apk dist\private-chat-release.apk
```

Expected: both APKs exist in `dist/`.

- [ ] **Step 4: Write dist manifest**

Create `dist/manifest.md` with build date, dart defines used, APK paths, file sizes, and any signing caveats.

- [ ] **Step 5: Commit manifest only**

Run:

```powershell
git add dist/manifest.md
git commit -m "docs: record apk build artifacts"
```

Expected: manifest commits. APK binaries remain ignored unless the user explicitly requests tracking them in git.

### Task 5.4: Demo Video and Final Verification

**Files:**
- Create: `docs/final-verification.md`

- [ ] **Step 1: Run full automated checks**

Run:

```powershell
cd server
npm test
cd ..\app
flutter test
flutter analyze
```

Expected: tests and analysis pass, or documented toolchain blockers exist.

- [ ] **Step 2: Manual acceptance checklist**

Verify and record:

- account creation with `@ZCMX` style account.
- duplicate account warning.
- private text chat.
- group creation with at least 2 selected contacts.
- burn-after-reading countdown and deletion.
- secure-window enabled on protected Android screens.
- message revoke within 5 minutes.
- media size rejection.
- one-to-one call signaling.
- group call signaling with at least 3 participants if devices/emulators are available.
- settings language switch.
- account deletion confirmation.

- [ ] **Step 3: Record demo video**

If a device/emulator and recording tool are available, record about 3 minutes showing account creation, private burn chat, secure screenshot behavior, group creation, and call flow. Save the video path in `docs/final-verification.md`.

- [ ] **Step 4: Commit final verification**

Run:

```powershell
git add docs/final-verification.md
git commit -m "docs: add final verification report"
```

Expected: commit succeeds.

---

## Execution Notes

- Prefer implementing one task at a time with tests first.
- Do not start Flutter UI work that depends on backend contracts before the matching backend task has passed.
- Do not claim APK or deployment success without command output recorded in the corresponding docs file.
- Keep credentials out of committed files except the user-provided deployment target documented in the approved spec.
- If a missing local tool blocks APK or video work, document the blocker in `docs/environment-check.md` or `docs/final-verification.md` and continue with source delivery.
