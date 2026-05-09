# Private Chat Flutter App Design

Date: 2026-05-09

## Scope

Build a complete Telegram-style private chat Android app with a Flutter client and a Node.js/Express/PostgreSQL backend. The delivery target is the full specification, implemented in phases so each subsystem can be verified before adding the next one.

The server deployment target is:

```text
Host: 192.168.1.103
SSH: eapp / Eapp1010A.
Directory: /home/eapp/chat_server
Public domain: wdsj.fun
```

Development defaults use the LAN address:

```text
API_BASE_URL=http://192.168.1.103:3000/api
WS_URL=ws://192.168.1.103:3001/ws
```

Release builds can switch to the public domain:

```text
API_BASE_URL=http://wdsj.fun:3000/api
WS_URL=ws://wdsj.fun:3001/ws
```

If TLS and reverse proxying are later configured, the same configuration layer can use:

```text
API_BASE_URL=https://wdsj.fun/api
WS_URL=wss://wdsj.fun/ws
```

## Delivery Strategy

Use phased full delivery:

1. Create the Flutter and server project foundations.
2. Implement backend API, PostgreSQL migrations, WebSocket runtime, and deployment script.
3. Implement account creation, secure credential storage, automatic login, and default avatars.
4. Implement chat list, private chat, group chat, WebSocket message sync, read receipts, and offline sync.
5. Implement burn-after-reading messages, Android `FLAG_SECURE`, local encrypted message storage, and cache handling.
6. Implement image, voice, file, emoji, and sticker flows.
7. Implement one-to-one and mesh group WebRTC calls.
8. Implement settings, privacy controls, account deletion, notifications, and final polish.
9. Build Debug and Release APKs, deploy the server, and create a short demo video if the local environment supports recording.

This avoids coupling high-risk features such as WebRTC, Android security flags, database migrations, and APK signing into one untestable change.

## Architecture

The system has three main runtime parts:

- Flutter Android client
- Express REST API on TCP 3000
- WebSocket and WebRTC signaling server on TCP 3001

PostgreSQL stores users, contacts, groups, messages, reads, media metadata, account deletion requests, and sticker pack metadata. Media and sticker files are stored on local disk under the server working directory.

The backend is responsible for identity, authorization, group permissions, message fan-out, offline sync, soft deletion, and WebRTC signaling. The client is responsible for local encrypted storage, media compression, UI state, secure window flags, and call media capture.

## Flutter Project Structure

```text
lib/
+-- main.dart
+-- core/
|   +-- config/
|   +-- themes/
|   +-- constants/
|   +-- utils/
|   +-- services/
+-- l10n/
+-- models/
+-- providers/
+-- screens/
+-- widgets/
+-- native/
```

Key services:

- `ApiService`: authenticated HTTP calls and retries.
- `WebSocketService`: connection lifecycle, auth, reconnect with exponential backoff, message dispatch.
- `WebRTCService`: peer connection creation, SDP and ICE exchange, one-to-one and mesh group call handling.
- `SecureStorageService`: token, user summary, and locally generated master key.
- `LocalDatabaseService`: encrypted `sqflite` persistence.
- `CryptoService`: AES-256-GCM encryption and hash helpers.
- `SecureWindowService`: Android `FLAG_SECURE` through a MethodChannel or maintained plugin.
- `MediaService`: image compression, voice recording metadata, media hashing, and cache cleanup.

State management can use Riverpod. It should keep authentication, conversations, groups, calls, settings, and connectivity separated.

## Client Features

### Account Creation

The app opens directly to account creation on first launch. There is no onboarding, advertising screen, or membership layer.

Validation rules:

```text
display_name: not blank, max 24 characters, accepts Chinese, English, numbers, and Emoji
account: matches ^@[A-Za-z]{1,9}$, max 10 characters including @
```

The client checks account uniqueness in real time with `GET /api/users/check-account`. Registering creates the user, receives a token, stores it in `flutter_secure_storage`, generates a device-local AES master key, and enters the chat list.

If stored credentials fail validation on a later launch, the client clears session state and returns to account creation.

### Default Avatars

The avatar library has exactly 9 built-in options:

1. Blue background with white person icon
2. Green background with white chat bubble
3. Orange background with white star
4. Purple background with white lock
5. Red background with white heart
6. Yellow background with white smile
7. Brown background with white coffee cup
8. Gray background with white camera
9. Cyan/green background with white group icon

Avatars are rendered as Flutter widgets or bundled vector/icon assets. Users cannot upload or capture custom avatars. The server randomly assigns an avatar at registration, and settings can change only to one of these 9 indexes.

### Chats

Chat list shows private and group conversations, unread counts, last message previews, and a red reconnecting banner when the socket is unavailable.

Private chat layout:

- Top bar: contact name, burn-after-reading flame menu, call buttons, more menu.
- Message list: right-aligned green bubbles for me, left-aligned gray bubbles for others.
- Composer: emoji button, input, attachment button, send or hold-to-record control.

Group chat layout:

- Top bar: group name, call menu, burn status, member menu.
- Messages show sender display name truncated to 12 characters.
- A member drawer supports member viewing and mentions.
- `@all` is limited to owner and admins.

Supported messages:

- Text with Unicode Emoji
- Images compressed to max 1080p width
- Voice messages up to 60 seconds with waveform UI
- Files up to 50 MB
- Stickers from official server packs
- Call event messages
- Revoked message notices

Message revocation is allowed within 5 minutes after sending. Burn-after-reading messages cannot be forwarded.

### Burn-After-Reading

Private chats support burn timers of 5 seconds, 10 seconds, 30 seconds, 1 minute, or off. When enabled, newly sent messages include `burnAfter`.

Group burn mode can be enabled by the owner or an admin. It applies to all new group messages with a fixed 30 second timer. Members cannot disable it individually.

Read flow:

1. Receiver marks a burn message read.
2. Server records `burn_started_at` and broadcasts `message.burn.start`.
3. Clients display a remaining-time indicator on the bubble.
4. When the timer expires, clients remove the message locally and notify the server.
5. Server marks the message `burned` and broadcasts `message.burn.expire`.
6. A backend cleanup job also expires stale burn messages as a consistency fallback.

### Android Screen Security

The client uses Android `WindowManager.LayoutParams.FLAG_SECURE` for protected surfaces.

It is forced on for:

- Chat screens when global privacy protection is enabled
- Burn-after-reading mode
- Call screens
- App lock screen

The Android secure window flag makes screenshots and screen recordings black in supported system paths. Android does not provide a fully reliable public API to detect every screenshot attempt. The app will show warnings and clear sensitive bubble content on lifecycle/focus signals where possible, but the guaranteed protection is the secure window flag, not universal attempt detection.

### Local Storage and Encryption

Messages use `sqflite` for local persistence. Message content and sensitive metadata are encrypted with AES-256-GCM before writing. Because account creation has no password, the database master key is generated locally on first login and stored in `flutter_secure_storage`.

Media files are stored under the app documents directory:

```text
media/<hash(messageId)>.<ext>
```

Settings include cache cleanup that preserves encrypted chat records while deleting thumbnails and temporary media.

### Settings

Settings include:

- Language: Simplified Chinese and English, applied immediately
- Default avatar selection from the 9 built-ins
- Notifications: enable, sound, vibration
- Privacy: secure screen global switch, default burn timer, app lock, online status privacy
- Chat settings: font size, send key behavior, hold-to-record
- Data usage: Wi-Fi-only media loading, auto-download size limit
- Account safety: account, UID, account deletion
- Cache cleanup
- About: version, privacy policy, server status

Account deletion requires typing the account name. The client clears local storage and calls the backend soft-delete endpoint. The backend marks the user for physical purge after 30 days.

## Backend Structure

```text
/home/eapp/chat_server/
+-- app.js
+-- package.json
+-- .env.example
+-- database/
|   +-- migrations/
|   +-- db.js
+-- src/
|   +-- api/
|   +-- auth/
|   +-- websocket/
|   +-- webrtc/
|   +-- storage/
|   +-- jobs/
|   +-- utils/
+-- storage/
|   +-- media/
|   +-- stickers/
|   +-- tmp/
+-- deploy.sh
```

The server will run API and WebSocket listeners in the same Node process or two coordinated servers in one process. The process is managed by systemd on the deployment target.

## Database Design

Core tables:

```text
users
contacts
groups
group_members
messages
message_reads
media_files
sticker_packs
account_deletions
```

Important constraints:

- `users.account` is unique and limited to 10 characters.
- Groups have an 8 digit unique `group_code`.
- Group roles are `owner`, `admin`, and `member`.
- Messages use UUID IDs.
- Offline sync returns messages from the most recent 7 days.
- Soft-deleted users and groups remain available for cleanup jobs but are excluded from normal queries.

## API Design

REST endpoints:

```text
POST   /api/auth/register
POST   /api/auth/validate
GET    /api/users/check-account?account=@ZCMX
PATCH  /api/users/me/avatar
DELETE /api/users/me
GET    /api/contacts
POST   /api/contacts
POST   /api/groups
GET    /api/groups/:id
PATCH  /api/groups/:id
POST   /api/groups/:id/members
DELETE /api/groups/:id/members/:userId
POST   /api/messages/sync
POST   /api/media/upload
GET    /api/media/:id
GET    /api/stickers/packs
GET    /stickers/:pack.zip
GET    /api/health
```

WebSocket events:

```text
auth
message.send
message.delivered
message.read
message.revoke
message.burn.start
message.burn.expire
group.member.added
group.member.removed
call.invite
call.accept
call.reject
call.hangup
call.sdp
call.ice
presence.update
```

The message envelope follows the requested shape:

```json
{
  "id": "uuid",
  "fromId": 123,
  "toId": 456,
  "toType": "user",
  "type": "text",
  "content": "encrypted-content",
  "timestamp": 1700000000,
  "burnAfter": 0,
  "status": "sent"
}
```

## WebRTC Design

Use WebRTC Mesh for one-to-one and group calls. The server does not relay media. It only relays signaling through WebSocket.

Default ICE servers:

```text
stun:stun.l.google.com:19302
```

If public-network calling is unreliable, a later phase can add Coturn. The deployment script opens UDP 5000-6000 as requested, but browser/mobile WebRTC may still use dynamically negotiated local ports unless a TURN server is introduced.

One-to-one call states:

```text
idle -> inviting -> ringing -> connecting -> active -> ended
```

Group calls maintain a room with up to 8 participants. Each participant creates a peer connection to every other participant. Voice calls show avatar chips and names. Video calls show a responsive grid. Muting a participant in a group call is local-only.

## Deployment

`deploy.sh` will:

1. Verify it is running on a supported Debian/Ubuntu-style system.
2. Install Node.js, npm, PostgreSQL, and required OS packages if missing.
3. Create the database and database user.
4. Install server dependencies.
5. Create `.env` from `.env.example` when needed.
6. Run SQL migrations.
7. Create storage directories.
8. Install and start a systemd service.
9. Open TCP 3000, TCP 3001, and UDP 5000-6000 using `ufw` when available.
10. Check `/api/health`.

The script should be idempotent where practical. It must not delete existing production data unless explicitly invoked with a documented reset flag.

## Build and Environment

The implementation phase will check the local Windows environment for:

- Flutter SDK
- Android SDK and platform tools
- JDK
- Node.js and npm
- PostgreSQL client tools
- Git
- Video recording capability

If a tool is missing and can be installed safely, install or configure it. If installation requires unavailable privileges, interactive license approval, or external installers that cannot be automated, document the blocker and the exact command the user can run.

Flutter build targets:

```text
flutter build apk --debug --dart-define=API_BASE_URL=... --dart-define=WS_URL=...
flutter build apk --release --dart-define=API_BASE_URL=... --dart-define=WS_URL=...
```

Debug and release APKs should be copied to a documented `dist/` directory if builds succeed.

## Testing and Verification

Verification checkpoints:

- Account validation rejects invalid account formats and duplicate accounts.
- Registration creates a user, assigns one of 9 avatars, and returns a token.
- Automatic login succeeds with valid credentials and returns to account creation on invalid credentials.
- WebSocket reconnect uses exponential backoff and resumes sync.
- Private messages deliver, show read receipts, and persist locally encrypted.
- Group creation requires at least 2 selected members and produces an 8 digit group code.
- Group permissions enforce owner/admin/member capabilities.
- Burn-after-reading starts on read, shows countdown, and removes messages from both clients.
- `FLAG_SECURE` is enabled on protected Android screens.
- Image upload compresses to the configured size.
- Voice recording rejects clips over 60 seconds.
- File upload rejects files over 50 MB.
- One-to-one calls exchange SDP/ICE and can hang up cleanly.
- Mesh group calls support join/leave signaling and local mute.
- Account deletion clears local data and soft deletes server data.
- `deploy.sh` completes and `/api/health` responds on the target server.

## Documentation Deliverables

Create Chinese documentation covering:

- How to change server addresses, including LAN and `wdsj.fun`.
- How to replace the 9 default avatar assets while keeping the no-upload rule.
- How to add new official sticker packs on the server.
- How to run the backend locally.
- How to deploy to `/home/eapp/chat_server`.
- How to build Debug and Release APKs.

## Known Constraints

- Android `FLAG_SECURE` reliably blocks screenshots and recordings by rendering protected surfaces black, but screenshot attempt detection is best-effort.
- WebRTC Mesh is suitable for the requested LAN-first deployment and up to 8 users, but it scales poorly compared with an SFU.
- Public-domain calling through `wdsj.fun` may require TURN if clients are behind restrictive NATs.
- Because account creation has no password, local encryption uses a device-generated key rather than password-derived key material.
- Demo video creation depends on local screen recording support and an available Android emulator or device.
