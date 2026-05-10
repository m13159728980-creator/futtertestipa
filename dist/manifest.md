# APK 构建记录

日期：2026-05-10

## 构建产物

| 文件 | 大小 | 说明 |
| --- | ---: | --- |
| `dist/private-chat-debug.apk` | 203.80 MB | Debug APK，连接内网服务器 |
| `dist/private-chat-release.apk` | 79.66 MB | Release APK，连接公网域名 |

## 本次变更

- 注册页已取消用户名输入，只保留名字。
- 服务器注册时自动生成唯一 10 位数字 ID。
- 添加好友使用 10 位数字 ID。
- 聊天首页和设置页显示 `ID: 10位数字`。
- 界面改为更简洁的单输入框注册页和更轻量的聊天首页。

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
