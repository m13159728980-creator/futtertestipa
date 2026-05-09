# Private Chat Flutter 客户端

这是 Private Chat 的 Flutter 客户端脚手架，当前包含 Android 工程、基础依赖、应用配置入口和账号校验工具。

## 开发

```powershell
$flutterBin = Join-Path $env:USERPROFILE 'flutter\bin'
$env:Path = "$flutterBin;" + [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
flutter pub get
flutter test
flutter analyze
```

后续聊天、登录、存储和实时通信界面将在此工程中逐步实现。
