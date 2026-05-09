# 部署结果

日期：2026-05-10

## 目标

- 服务器：`192.168.1.103`
- SSH 用户：`eapp`
- 工作目录：`/home/eapp/chat_server`
- 公网域名：`wdsj.fun`

## 已执行检查

```powershell
Get-Command ssh
Get-Command scp
Test-NetConnection 192.168.1.103 -Port 22
Get-Command sshpass
Get-Command plink
Get-Command pscp
Get-Module -ListAvailable Posh-SSH
```

结果：

- Windows OpenSSH `ssh.exe` 和 `scp.exe` 可用。
- `192.168.1.103:22` TCP 可达。
- 当前非交互环境没有 `sshpass`、`plink`、`pscp` 或 `Posh-SSH`，无法自动输入密码执行部署。

## 阻塞项

本环境不能完成非交互密码 SSH 部署。需要以下任一条件：

- 在终端手动执行命令并输入密码。
- 为 `eapp@192.168.1.103` 配置 SSH key。
- 安装可用的非交互 SSH 工具。

## 手动部署命令

```powershell
scp -r server eapp@192.168.1.103:/home/eapp/chat_server
ssh eapp@192.168.1.103 "cd /home/eapp/chat_server && chmod +x deploy.sh && ./deploy.sh"
curl http://192.168.1.103:3000/api/health
curl http://wdsj.fun:3000/api/health
```

预期：

- `deploy.sh` 安装依赖、初始化 PostgreSQL、运行 migration、安装 systemd 服务。
- 防火墙开放 TCP `3000`、TCP `3001`、UDP `5000-6000`。
- LAN health 返回 `{"ok":true}`。
- `wdsj.fun` health 取决于 DNS、路由器端口转发和公网防火墙。
