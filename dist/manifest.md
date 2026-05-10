# APK 构建记录

日期：2026-05-10

## 构建产物

| 文件 | 大小 | 说明 |
| --- | ---: | --- |
| `dist/private-chat-debug.apk` | 179.54 MB | Debug APK，连接内网服务器 |
| `dist/private-chat-release.apk` | 79.74 MB | Release APK，连接公网域名 |

## Debug APK

命令：

```powershell
cd app
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.103:3000/api --dart-define=WS_URL=ws://192.168.1.103:3001/ws
```

结果：

- 成功生成：`app/build/app/outputs/flutter-apk/app-debug.apk`
- 已复制到：`dist/private-chat-debug.apk`

## Release APK

命令：

```powershell
cd app
flutter build apk --release --dart-define=API_BASE_URL=http://wdsj.fun:3000/api --dart-define=WS_URL=ws://wdsj.fun:3001/ws
```

结果：

- 成功生成：`app/build/app/outputs/flutter-apk/app-release.apk`
- 已复制到：`dist/private-chat-release.apk`
- 当前 release 使用 Flutter 模板里的 debug signing config，适合内测安装；正式上架前需要替换为生产 keystore。

## 本机环境修复记录

- 将 Android `compileSdk` 和 `targetSdk` 固定为 `36`，匹配当前插件和已安装 SDK。
- 本机 `C:\tmp\android-sdk\platforms\android-34` 缺少 `android.jar`，已用已安装的 `android-35/android.jar` 补齐以满足旧插件解析资源需求。
- Windows 下 Pub 缓存位于 `C:`、项目位于 `E:`，Kotlin 增量缓存会输出跨盘符相对路径异常；已在 `app/android/gradle.properties` 设置 `kotlin.incremental=false`，后续构建更稳定。
