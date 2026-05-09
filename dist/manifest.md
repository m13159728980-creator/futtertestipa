# APK 构建记录

日期：2026-05-10

## Debug APK

命令：

```powershell
cd app
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.103:3000/api --dart-define=WS_URL=ws://192.168.1.103:3001/ws
```

结果：未生成 APK。

当前阻塞：

- 本机 Android SDK `C:\tmp\android-sdk\platforms\android-34` 缺少 `android.jar`。
- Gradle 在 `:file_picker:parseDebugLocalResources` 处理 `android-34/android.jar` 时失败。
- 当前环境未找到 `sdkmanager.bat`，无法自动重装 `platforms;android-34`。

已排除：

- Flutter/Dart 测试通过。
- `flutter analyze` 通过。
- 之前的 `record_linux` 依赖兼容问题已通过升级 `record` 到 `6.2.0` 解决。

## Release APK

命令计划：

```powershell
cd app
flutter build apk --release --dart-define=API_BASE_URL=http://wdsj.fun:3000/api --dart-define=WS_URL=ws://wdsj.fun:3001/ws
```

结果：未执行。原因是 Debug 构建已被本机 Android SDK platform 缺失阻塞。

## 修复方式

安装或修复 Android SDK platform：

```powershell
sdkmanager "platforms;android-34" "build-tools;34.0.0"
flutter doctor --android-licenses
```

然后重新执行 Debug 和 Release APK 构建命令。
