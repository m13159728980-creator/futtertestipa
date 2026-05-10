# 部署结果

日期：2026-05-10

## 目标

- 服务器：`192.168.1.103`
- SSH 用户：`eapp`
- 工作目录：`/home/eapp/chat_server`
- 公网域名：`wdsj.fun`

## 已执行

本机安装 PuTTY 工具链后，使用 `plink/pscp` 以非交互方式完成部署：

```powershell
winget install --id PuTTY.PuTTY -e --accept-package-agreements --accept-source-agreements
```

远端主机密钥：

```text
ssh-ed25519 255 SHA256:7jTUgblTmQBg0cH1JPcpKjIJBTte/vpK2pyfmctUVIs
```

部署过程：

- 创建并授权 `/home/eapp/chat_server`。
- 上传服务端代码到临时目录 `/home/eapp/chat_server_upload`。
- 以 sudo 执行 `deploy.sh`。
- 安装 Node.js/npm/PostgreSQL/ufw/rsync 等依赖。
- 创建 PostgreSQL 数据库 `private_chat` 和用户 `chat_user`。
- 执行 migration：`001_initial.sql`。
- 创建并启动 systemd 服务：`chat-server.service`。
- 开放防火墙端口：TCP `3000`、TCP `3001`、UDP `5000-6000`。

## 验证结果

远端本机：

```bash
curl -fsS http://127.0.0.1:3000/api/health
systemctl is-active chat-server
ss -lntu | grep -E ':(3000|3001)\b'
```

结果：

```text
{"ok":true}
active
*:3000 LISTEN
*:3001 LISTEN
```

本机访问：

```powershell
Invoke-WebRequest -UseBasicParsing http://192.168.1.103:3000/api/health
Invoke-WebRequest -UseBasicParsing http://wdsj.fun:3000/api/health
```

结果：

- `http://192.168.1.103:3000/api/health` 返回 `200 {"ok":true}`
- `http://wdsj.fun:3000/api/health` 返回 `200 {"ok":true}`
- `wdsj.fun` 当前解析到 `122.138.97.22`

## 运行信息

- 服务目录：`/home/eapp/chat_server`
- systemd 服务名：`chat-server`
- API：`http://192.168.1.103:3000/api` 或 `http://wdsj.fun:3000/api`
- WebSocket：`ws://192.168.1.103:3001/ws` 或 `ws://wdsj.fun:3001/ws`

常用维护命令：

```bash
sudo systemctl status chat-server --no-pager
sudo journalctl -u chat-server -n 100 --no-pager
sudo systemctl restart chat-server
```
