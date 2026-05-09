# 开发文档

本文记录 GRAM 客户端和后端的常见开发、资源替换、构建与部署操作。

## 修改 API_BASE_URL 和 WS_URL

客户端网络入口定义在 `app/lib/core/config/app_config.dart`：

```dart
static const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.1.103:3000/api',
);

static const String wsUrl = String.fromEnvironment(
  'WS_URL',
  defaultValue: 'ws://192.168.1.103:3001/ws',
);
```

开发时优先使用 `--dart-define` 覆盖，不需要改源码：

```bash
cd app
flutter run \
  --dart-define=API_BASE_URL=http://192.168.1.103:3000/api \
  --dart-define=WS_URL=ws://192.168.1.103:3001/ws
```

Debug APK：

```bash
flutter build apk --debug \
  --dart-define=API_BASE_URL=http://192.168.1.103:3000/api \
  --dart-define=WS_URL=ws://192.168.1.103:3001/ws
```

Release APK：

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=http://wdsj.fun:3000/api \
  --dart-define=WS_URL=ws://wdsj.fun:3001/ws
```

如果启用 HTTPS 和反向代理，请将地址改为 `https://wdsj.fun/api` 与 `wss://wdsj.fun/ws`。

## 替换 9 个默认头像

默认头像 catalog 位于 `app/lib/core/constants/avatar_catalog.dart`。当前固定包含 9 个条目，索引为 `0` 到 `8`。

替换头像时需要保持固定 catalog 行为：

- 保持 `avatarCatalog` 长度为 9。
- 保持每个 `AvatarCatalogEntry.index` 的数值和顺序稳定。
- 可以替换 `label`、`icon`、`color` 或后续扩展为本地图片资源，但不要让同一个历史索引指向不同语义的用户数据。
- 保持 `avatarByIndex()` 的越界回退行为，越界时返回第一个头像。
- 修改后运行 `flutter test test/avatar_catalog_test.dart test/default_avatar_test.dart`。

如果从 Material Icon 改为图片资源，建议新增字段而不是删除现有字段，并同步更新渲染组件 `app/lib/widgets/default_avatar.dart` 和测试。

## 添加 server sticker packs

客户端官方贴纸 catalog 位于 `app/lib/core/constants/sticker_catalog.dart`。后端静态贴纸文件应放在：

```text
server/storage/stickers
```

添加新贴纸包时：

1. 在 `server/storage/stickers/<pack_id>/` 放入贴纸图片，例如 `01.png` 到 `16.png`。
2. 如需整包下载，在 `server/storage/stickers/` 放入 `<pack_id>.zip`。
3. 在 `sticker_catalog.dart` 新增或调整 `StickerPack`，确保：
   - `id` 与目录名一致。
   - `downloadPath` 指向 `/stickers/<pack_id>.zip`。
   - 每个 `remotePath` 指向 `/stickers/<pack_id>/<file>.png`。
   - 每个 `assetPath` 对应客户端内置资源路径。
4. 更新 `app/pubspec.yaml` 中的 assets 声明。
5. 运行 `flutter test test/sticker_catalog_test.dart`。

部署脚本会创建 `/home/eapp/chat_server/storage/stickers`，但不会覆盖现有运行时 `storage` 目录。线上新增贴纸时，需要单独同步 sticker 文件或在首次部署前放入仓库对应目录。

## 部署到 /home/eapp/chat_server

后端部署脚本位于 `server/deploy.sh`，默认部署目录为 `/home/eapp/chat_server`，默认服务名为 `chat-server`。

在服务器上执行：

```bash
cd server
sudo APP_DIR=/home/eapp/chat_server \
  APP_USER=eapp \
  PUBLIC_DOMAIN=wdsj.fun \
  LAN_HOST=服务器内网或局域网地址 \
  CHAT_DB_PASSWORD=请替换为强密码 \
  ./deploy.sh
```

脚本会执行：

- 安装 Node.js、npm、PostgreSQL、rsync、ufw 等依赖。
- 创建 `eapp` 用户和 `/home/eapp/chat_server`。
- 同步后端代码，保留 `.env`、`node_modules` 和 `storage`。
- 初始化 PostgreSQL 数据库与账号。
- 运行 `npm install` 和 `npm run migrate`。
- 创建并启动 systemd 服务。
- 放行 TCP `3000`、TCP `3001`、UDP `5000-6000`。

部署后检查：

```bash
systemctl status chat-server --no-pager
curl -fsS http://127.0.0.1:3000/api/health
```

## 构建 Debug/Release APK

Debug 构建适合局域网联调：

```bash
cd app
flutter pub get
flutter build apk --debug \
  --dart-define=API_BASE_URL=http://192.168.1.103:3000/api \
  --dart-define=WS_URL=ws://192.168.1.103:3001/ws
```

Release 构建适合交付或公网测试：

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=http://wdsj.fun:3000/api \
  --dart-define=WS_URL=ws://wdsj.fun:3001/ws
```

产物位置：

```text
app/build/app/outputs/flutter-apk/app-debug.apk
app/build/app/outputs/flutter-apk/app-release.apk
```

Release 签名请按 Flutter/Android 的正式签名流程配置 `key.properties` 和 release signingConfig；不要把生产密钥提交到仓库。

## 截屏尝试检测限制

Android 的 `FLAG_SECURE` 可以阻止系统截屏、录屏或让截图结果黑屏。当前客户端的安全窗口能力在 `app/lib/native/secure_window_channel.dart` 和 `app/lib/core/services/secure_window_service.dart` 中封装。

需要注意：

- `FLAG_SECURE` 的常见表现是截图黑屏或系统直接阻止截图。
- 应用通常无法可靠获知用户是否尝试截图，这是 Android 系统层面的限制。
- “检测截屏尝试”只能作为后续扩展能力评估，不能作为当前可靠安全承诺。
- 不同厂商 ROM、系统版本、投屏工具和录屏入口的表现可能不同，测试结论需要按目标设备复核。

## WebRTC Mesh 限制

当前通话使用 WebRTC Mesh 思路：参与者之间直接建立连接，后端主要负责信令。该方案适合少量成员通话，但存在天然限制：

- 每个成员需要与其他成员分别建立连接，人数增加时连接数快速上升。
- 上行带宽、CPU 编解码开销和电量消耗会随人数明显增加。
- NAT 环境复杂时需要 STUN/TURN；仅靠信令服务不能保证所有网络都能打通。
- 大群通话或高可靠公网通话后续应评估 SFU/MCU 架构。

因此当前 Mesh 更适合一对一或小规模群通话，不建议直接承诺大型会议能力。

## 处理公网域名 wdsj.fun

后端配置中 `PUBLIC_DOMAIN` 默认是 `wdsj.fun`。没有反向代理时，公网客户端可以直接访问：

```text
http://wdsj.fun:3000/api
ws://wdsj.fun:3001/ws
```

域名处理步骤：

1. 将 `wdsj.fun` 的 DNS A 记录指向服务器公网 IP。
2. 确认云安全组和服务器防火墙放行 TCP `3000`、TCP `3001`，通话需要 UDP `5000-6000`。
3. 后端 `.env` 或部署环境中设置 `PUBLIC_DOMAIN=wdsj.fun`，必要时设置完整 `PUBLIC_URL`。
4. 客户端构建时使用公网 `API_BASE_URL` 和 `WS_URL`。
5. 如使用 Nginx/HTTPS，配置 HTTP 反代到 `127.0.0.1:3000`，WebSocket 反代到 `127.0.0.1:3001`，并把客户端地址改为 `https://wdsj.fun/api` 和 `wss://wdsj.fun/ws`。

WebSocket 反向代理必须保留 `Upgrade` 和 `Connection` 头，否则客户端会连接失败。
