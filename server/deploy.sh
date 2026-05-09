#!/usr/bin/env bash
set -euo pipefail

APP_USER="${APP_USER:-eapp}"
APP_DIR="${APP_DIR:-/home/eapp/chat_server}"
SERVICE_NAME="${SERVICE_NAME:-chat-server}"
REPO_DIR="${REPO_DIR:-$(pwd)}"
DB_NAME="${DB_NAME:-private_chat}"
DB_USER="${DB_USER:-chat_user}"
DB_PASSWORD="${CHAT_DB_PASSWORD:-chat_password_change_me}"
FORCE_DB_PASSWORD_UPDATE="${FORCE_DB_PASSWORD_UPDATE:-0}"

if ! [[ "$DB_NAME" =~ ^[a-z_][a-z0-9_]*$ ]]; then
  echo "DB_NAME must match ^[a-z_][a-z0-9_]*$" >&2
  exit 1
fi
if ! [[ "$DB_USER" =~ ^[a-z_][a-z0-9_]*$ ]]; then
  echo "DB_USER must match ^[a-z_][a-z0-9_]*$" >&2
  exit 1
fi

validate_db_password() {
  if ! [[ "$1" =~ ^[A-Za-z0-9_.~-]+$ ]]; then
    echo "DB_PASSWORD must match ^[A-Za-z0-9_.~-]+$ for DATABASE_URL safety" >&2
    exit 1
  fi
}

sql_literal() {
  printf "'%s'" "${1//\'/\'\'}"
}

extract_database_url_password() {
  local env_file="$1"
  local database_url
  database_url="$(grep -E '^DATABASE_URL=' "$env_file" | tail -n 1 | cut -d= -f2- || true)"
  if [[ "$database_url" =~ ^postgres://[^:]+:([^@]+)@ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}

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
  validate_db_password "$DB_PASSWORD"
  cp "$APP_DIR/.env.example" "$APP_DIR/.env"
  {
    echo "DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@localhost:5432/${DB_NAME}"
    echo "STORAGE_PATH=${APP_DIR}/storage"
  } >>"$APP_DIR/.env"
  chown "$APP_USER:$APP_USER" "$APP_DIR/.env"
else
  existing_db_password="$(extract_database_url_password "$APP_DIR/.env")"
  if [ -z "${CHAT_DB_PASSWORD:-}" ] && [ -n "$existing_db_password" ]; then
    validate_db_password "$existing_db_password"
    DB_PASSWORD="$existing_db_password"
  fi
fi

validate_db_password "$DB_PASSWORD"

db_user_literal="$(sql_literal "$DB_USER")"
db_name_literal="$(sql_literal "$DB_NAME")"
db_password_literal="$(sql_literal "$DB_PASSWORD")"

if ! sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname=${db_user_literal}" | grep -q 1; then
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE ROLE ${DB_USER} LOGIN PASSWORD ${db_password_literal};"
elif [ "$FORCE_DB_PASSWORD_UPDATE" = "1" ] && [ -n "${CHAT_DB_PASSWORD:-}" ]; then
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER ROLE ${DB_USER} LOGIN PASSWORD ${db_password_literal};"
fi

if ! sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname=${db_name_literal}" | grep -q 1; then
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
fi
sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};"

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
