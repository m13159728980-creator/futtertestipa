# GRAM 私密聊天

GRAM 是一个面向移动端的私密聊天项目，包含 Flutter Android 客户端和 Node.js 后端。当前实现覆盖账号注册登录、联系人与群聊、文�?媒体/贴纸消息、阅后即焚、基础安全窗口、WebSocket 实时消息，以�?WebRTC Mesh 通话信令�?
## 目录结构

```text
.
├── app/                 # Flutter 客户�?�?  ├── lib/             # 页面、Provider、服务、模型和配置
�?  ├── android/         # Android 工程
�?  └── test/            # Flutter 单元/组件测试
├── server/              # Node.js/Express 后端
�?  ├── app.js           # HTTP API �?WebSocket 入口
�?  ├── database/        # 数据库连接和迁移
�?  ├── src/             # API、服务、认证、WebRTC 信令
�?  ├── storage/         # 运行时媒体与贴纸存储目录
�?  └── tests/           # Jest 后端测试
└── docs/                # 开发、部署和环境文档
```

## 后端本地运行

后端默认使用 PostgreSQL，HTTP API 监听 `10080`，WebSocket 监听 `10081`�?
```bash
cd server
npm install
npm run migrate
npm run dev
```

常用环境变量�?
```env
DATABASE_URL=postgres://postgres:postgres@localhost:5432/private_chat
JWT_SECRET=change-me-in-development
STORAGE_PATH=./storage
LAN_HOST=192.168.1.103
PUBLIC_DOMAIN=wdsj.fun
API_PORT=10080
WS_PORT=10081
```

健康检查地址�?
```text
http://127.0.0.1:10080/api/health
```

## Flutter 本地运行

```bash
cd app
flutter pub get
flutter test
flutter run
```

客户端接口地址�?`app/lib/core/config/app_config.dart` 中通过 Dart define 注入，默认值为�?
```text
API_BASE_URL=http://192.168.1.103:10080/api
WS_URL=ws://192.168.1.103:10081/ws
```

运行时可覆盖�?
```bash
flutter run \
  --dart-define=API_BASE_URL=http://192.168.1.103:10080/api \
  --dart-define=WS_URL=ws://192.168.1.103:10081/ws
```

## LAN 配置

手机和开发机需要处于同一局域网。将 `192.168.1.103` 替换为后端机器的局域网 IP，并确保防火墙放行：

- TCP `10080`：HTTP API�?- TCP `10081`：WebSocket�?- UDP `5000-6000`：WebRTC 通话候选端口范围�?
后端可通过 `LAN_HOST` �?`LAN_URL` 调整局域网地址；客户端通过 `API_BASE_URL` �?`WS_URL` 指向同一台后端�?
## wdsj.fun 公网配置

公网访问使用域名 `wdsj.fun`。后端默�?`PUBLIC_DOMAIN=wdsj.fun`，未设置 `PUBLIC_URL` 时会生成 `http://wdsj.fun:10080`�?
客户端公网构建示例：

```bash
cd app
flutter build apk --release \
  --dart-define=API_BASE_URL=http://wdsj.fun:10080/api \
  --dart-define=WS_URL=ws://wdsj.fun:10081/ws
```

如果服务器前置了 Nginx、HTTPS 或反向代理，应同步改为实际入口，例如 `https://wdsj.fun/api` �?`wss://wdsj.fun/ws`，并保证代理转发 WebSocket 升级请求�?
## 交付 artifact 位置

Android 构建产物位于�?
```text
app/build/app/outputs/flutter-apk/app-debug.apk
app/build/app/outputs/flutter-apk/app-release.apk
```

后端部署脚本为：

```text
server/deploy.sh
```

默认部署目录为：

```text
/home/eapp/chat_server
```
