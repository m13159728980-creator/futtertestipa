# Environment Check

Date: 2026-05-09

## Tool Check Results

- Git:

```text
git version 2.54.0.windows.1
```

- Node.js:

```text
node : The term 'node' is not recognized as the name of a cmdlet, function, script file, or operable program. Check the
 spelling of the name, or if a path was included, verify that the path is correct and try again.
At line:2 char:1
+ node --version
+ ~~~~
    + CategoryInfo          : ObjectNotFound: (node:String) [], CommandNotFoundException
    + FullyQualifiedErrorId : CommandNotFoundException
```

- npm:

```text
npm : The term 'npm' is not recognized as the name of a cmdlet, function, script file, or operable program. Check the s
pelling of the name, or if a path was included, verify that the path is correct and try again.
At line:2 char:1
+ npm --version
+ ~~~
    + CategoryInfo          : ObjectNotFound: (npm:String) [], CommandNotFoundException
    + FullyQualifiedErrorId : CommandNotFoundException
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

- Backend development: blocked by missing Node.js/npm
- Flutter development: blocked by flutter
- APK build: blocked by Flutter
- Demo video: not verified; device/emulator/recorder checks still needed
