# APK Build Manifest

Date: 2026-05-10

## Artifacts

| File | Size | Notes |
| --- | ---: | --- |
| `dist/private-chat-debug.apk` | 179.54 MB | Debug APK, LAN server build |
| `dist/private-chat-release.apk` | 79.66 MB | Release APK, public domain build with INTERNET permission |

## Current Endpoints

- API: `10080`
- WebSocket: `10081`
- Debug build: `http://192.168.1.103:10080/api`, `ws://192.168.1.103:10081/ws`
- Release build: `http://wdsj.fun:10080/api`, `ws://wdsj.fun:10081/ws`

## Recent Changes

- Registration no longer asks for a username.
- The server generates a unique 10 digit numeric account ID.
- Contacts are added by 10 digit ID.
- Chat list and settings display `ID: 10 digits`.
- The account creation and chat list UI were simplified.

## Debug APK

Command:

```powershell
cd app
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.103:10080/api --dart-define=WS_URL=ws://192.168.1.103:10081/ws
```

Result:

- Built: `app/build/app/outputs/flutter-apk/app-debug.apk`
- Copied to: `dist/private-chat-debug.apk`

## Release APK

Command:

```powershell
cd app
flutter build apk --release --dart-define=API_BASE_URL=http://wdsj.fun:10080/api --dart-define=WS_URL=ws://wdsj.fun:10081/ws
```

Result:

- Built: `app/build/app/outputs/flutter-apk/app-release.apk`
- Copied to: `dist/private-chat-release.apk`
- The release build currently uses the Flutter template debug signing config, which is suitable for internal testing. Replace it with a production keystore before store distribution.
