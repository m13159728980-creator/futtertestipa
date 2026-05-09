#!/usr/bin/env bash
set -euo pipefail

APP_USER="${APP_USER:-eapp}"
APP_DIR="${APP_DIR:-/home/eapp/chat_server}"
SERVICE_NAME="${SERVICE_NAME:-chat-server}"
REPO_DIR="${REPO_DIR:-$(pwd)}"

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This deployment script expects an Ubuntu/Debian host with apt-get." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl git nodejs npm postgresql postgresql-client rsync ufw

id -u "$APP_USER" >/dev/null 2>&1 || useradd --create-home --shell /bin/bash "$APP_USER"
mkdir -p "$APP_DIR" "$APP_DIR/storage/media" "$APP_DIR/storage/stickers" "$APP_DIR/storage/tmp"
chown -R "$APP_USER:$APP_USER" "$APP_DIR"

rsync -a --delete \
  --exclude node_modules \
  --exclude storage \
  "$REPO_DIR/" "$APP_DIR/"

cd "$APP_DIR"
npm install
npm run migrate

cat >/etc/systemd/system/${SERVICE_NAME}.service <<SERVICE
[Unit]
Description=Private Chat Server
After=network.target postgresql.service

[Service]
Type=simple
User=${APP_USER}
WorkingDirectory=${APP_DIR}
EnvironmentFile=-${APP_DIR}/.env
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
systemctl restart "${SERVICE_NAME}"

ufw allow 3000/tcp
ufw allow 3001/tcp
ufw allow 5000:6000/udp
ufw --force enable

for attempt in 1 2 3 4 5; do
  if curl -fsS "http://127.0.0.1:${API_PORT:-3000}/health" >/dev/null; then
    echo "Deployment healthy."
    exit 0
  fi
  sleep 2
done

systemctl status "${SERVICE_NAME}" --no-pager
exit 1
