#!/usr/bin/env bash
set -euo pipefail

APP_USER="${APP_USER:-eapp}"
APP_DIR="${APP_DIR:-/home/eapp/chat_server}"
SERVICE_NAME="${SERVICE_NAME:-chat-server}"
REPO_DIR="${REPO_DIR:-$(pwd)}"
DB_NAME="${DB_NAME:-private_chat}"
DB_USER="${DB_USER:-chat_user}"
DB_PASSWORD="${CHAT_DB_PASSWORD:-chat_password_change_me}"

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
  --exclude .env \
  --exclude node_modules \
  --exclude storage \
  "$REPO_DIR/" "$APP_DIR/"

cd "$APP_DIR"
if [ ! -f "$APP_DIR/.env" ]; then
  cp "$APP_DIR/.env.example" "$APP_DIR/.env"
  {
    echo "DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@localhost:5432/${DB_NAME}"
    echo "STORAGE_PATH=${APP_DIR}/storage"
  } >>"$APP_DIR/.env"
  chown "$APP_USER:$APP_USER" "$APP_DIR/.env"
fi

sudo -u postgres psql -v ON_ERROR_STOP=1 \
  -v db_user="$DB_USER" \
  -v db_password="$DB_PASSWORD" <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = :'db_user') THEN
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', :'db_user', :'db_password');
  ELSE
    EXECUTE format('ALTER ROLE %I LOGIN PASSWORD %L', :'db_user', :'db_password');
  END IF;
END
$$;
SQL

if ! sudo -u postgres psql -v db_name="$DB_NAME" -tAc "SELECT 1 FROM pg_database WHERE datname = :'db_name'" | grep -q 1; then
  sudo -u postgres psql -v ON_ERROR_STOP=1 \
    -v db_name="$DB_NAME" \
    -v db_user="$DB_USER" \
    -c 'CREATE DATABASE :"db_name" OWNER :"db_user";'
fi
sudo -u postgres psql -v ON_ERROR_STOP=1 \
  -v db_name="$DB_NAME" \
  -v db_user="$DB_USER" \
  -c 'ALTER DATABASE :"db_name" OWNER TO :"db_user";'

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
  if curl -fsS "http://127.0.0.1:${API_PORT:-3000}/api/health" >/dev/null; then
    echo "Deployment healthy."
    exit 0
  fi
  sleep 2
done

systemctl status "${SERVICE_NAME}" --no-pager
exit 1
