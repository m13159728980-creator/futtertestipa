# 部署结果

日期�?026-05-10

## 目标

- 服务器：`192.168.1.103`
- SSH 用户：`eapp`
- 工作目录：`/home/eapp/chat_server`
- 公网域名：`wdsj.fun`

## 已执�?
已使�?PuTTY `plink/pscp` 完成非交互部署，并在远端执行�?
```bash
cd /home/eapp/chat_server_upload
sudo env APP_USER=eapp APP_DIR=/home/eapp/chat_server SERVICE_NAME=chat-server REPO_DIR=/home/eapp/chat_server_upload bash ./deploy.sh
```

本次部署应用了新迁移�?
```text
002_numeric_user_ids.sql
```

迁移效果�?
- 移除旧的 `@英文用户名` 数据库约束�?- 将已有用户账号转换为 10 位数�?ID�?- 增加新的 `^[0-9]{10}$` 约束�?- 重启 `chat-server` 服务�?
## 验证结果

健康检查：

```powershell
Invoke-WebRequest -UseBasicParsing http://wdsj.fun:10080/api/health
```

结果�?
```text
200 {"ok":true}
```

注册和加好友验证�?
- `POST http://wdsj.fun:10080/api/auth/register` 只传 `displayName` 可以成功注册�?- 返回用户 ID �?10 位数字，例如 `1699690584`�?- `POST http://wdsj.fun:10080/api/contacts` 使用 `{ "id": "10位数字ID" }` 可以成功添加好友�?
## 运行信息

- 服务目录：`/home/eapp/chat_server`
- systemd 服务名：`chat-server`
- API：`http://192.168.1.103:10080/api` �?`http://wdsj.fun:10080/api`
- WebSocket：`ws://192.168.1.103:10081/ws` �?`ws://wdsj.fun:10081/ws`

常用维护命令�?
```bash
sudo systemctl status chat-server --no-pager
sudo journalctl -u chat-server -n 100 --no-pager
sudo systemctl restart chat-server
```
