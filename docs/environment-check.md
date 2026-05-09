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
flutter : The term 'flutter' is not recognized as the name of a cmdlet, function, script file, or operable program. Che
ck the spelling of the name, or if a path was included, verify that the path is correct and try again.
At line:2 char:1
+ flutter --version
+ ~~~~~~~
    + CategoryInfo          : ObjectNotFound: (flutter:String) [], CommandNotFoundException
    + FullyQualifiedErrorId : CommandNotFoundException
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
- Flutter development: blocked by flutter
- APK build: blocked by Flutter
- Demo video: not verified; device/emulator/recorder checks still needed
