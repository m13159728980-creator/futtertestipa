# Environment Check

Date: 2026-05-09

## Tool Check Results

- Git:

```text
git version 2.54.0.windows.1
```

- Node.js:

```text
Initial check: node was not found.
After installing OpenJS.NodeJS.LTS with winget and refreshing PATH:
v24.15.0
```

- npm:

```text
Initial PowerShell check before Node installation:
npm : The term 'npm' is not recognized as the name of a cmdlet, function, script file, or operable program. Check the s
pelling of the name, or if a path was included, verify that the path is correct and try again.
At line:2 char:1
+ npm --version
+ ~~~
    + CategoryInfo          : ObjectNotFound: (npm:String) [], CommandNotFoundException
    + FullyQualifiedErrorId : CommandNotFoundException

After installing OpenJS.NodeJS.LTS, `npm --version` is blocked by PowerShell execution policy:
npm : File C:\Program Files\nodejs\npm.ps1 cannot be loaded because running scripts is disabled on this system.

Using the command shim works:
npm.cmd --version
11.12.1
```

- Flutter:

```text
Initial check: flutter was not found on PATH.
Flutter SDK exists at C:\Users\Administrator\flutter and works when C:\Users\Administrator\flutter\bin is prepended to PATH.

Flutter 3.41.9 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 00b0c91f06 (10 days ago) • 2026-04-29 10:03:19 -0700
Engine • hash 9161402dc0e134b3fb5adee5046b6e84b1a5e1c1 (revision 42d3d75a56) (10 days ago) • 2026-04-28 17:31:55.000Z
Tools • Dart 3.11.5 • DevTools 2.54.2

flutter doctor -v summary:
- Flutter: OK
- Android toolchain: Android SDK at C:\tmp\android-sdk, but some Android licenses not accepted.
- Connected devices: Windows desktop and Edge web. No Android device recorded yet.
- Network resources: checks for https://maven.google.com/ and https://github.com/ timed out.
```

- Java/JDK:

```text
openjdk version "21.0.11" 2026-04-21 LTS
OpenJDK Runtime Environment Temurin-21.0.11+10 (build 21.0.11+10-LTS)
OpenJDK 64-Bit Server VM Temurin-21.0.11+10 (build 21.0.11+10-LTS, mixed mode, sharing)
```

- Android adb:

```text
Android Debug Bridge version 1.0.26.29
```

- PostgreSQL psql:

```text
psql : The term 'psql' is not recognized as the name of a cmdlet, function, script file, or operable program. Check the
 spelling of the name, or if a path was included, verify that the path is correct and try again.
At line:2 char:1
+ psql --version
+ ~~~~
    + CategoryInfo          : ObjectNotFound: (psql:String) [], CommandNotFoundException
    + FullyQualifiedErrorId : CommandNotFoundException
```

## Build Implications

- Backend development: ready with `node` and `npm.cmd`; use `npm.cmd` in PowerShell unless execution policy is changed.
- Flutter development: ready when `C:\Users\Administrator\flutter\bin` is prepended to PATH for the shell.
- APK build: blocked by unaccepted Android licenses until `flutter doctor --android-licenses` succeeds.
- Demo video: not verified; device/emulator/recorder checks still needed
