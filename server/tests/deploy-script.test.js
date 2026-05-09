const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

test('deploy.sh is an idempotent Ubuntu/Debian deployment script for the chat server', () => {
  const scriptPath = path.join(__dirname, '..', 'deploy.sh');
  const script = fs.readFileSync(scriptPath, 'utf8');
  const indexEntry = execFileSync('git', ['ls-files', '--stage', '--', 'server/deploy.sh'], {
    cwd: path.join(__dirname, '..', '..'),
    encoding: 'utf8'
  });

  expect(script.startsWith('#!/usr/bin/env bash')).toBe(true);
  expect(indexEntry).toMatch(/^100755 /);
  expect(script).toContain('apt-get');
  expect(script).toContain('nodejs');
  expect(script).toContain('postgresql');
  expect(script).toContain('/home/eapp/chat_server');
  expect(script).toContain('npm install');
  expect(script).toContain('npm run migrate');
  expect(script).toContain('systemctl');
  expect(script).toContain('ufw allow 3000/tcp');
  expect(script).toContain('ufw allow 3001/tcp');
  expect(script).toContain('ufw allow 5000:6000/udp');
  expect(script).toContain('curl');
  expect(script).toContain('http://127.0.0.1:${API_PORT:-3000}/api/health');
  expect(script).not.toMatch(/rm\s+-rf\s+\$?APP_DIR/);
  expect(script).not.toContain('git reset --hard');
});

test('deploy.sh provisions PostgreSQL database and user before migrations', () => {
  const script = fs.readFileSync(path.join(__dirname, '..', 'deploy.sh'), 'utf8');
  const databaseSetupIndex = script.indexOf('CREATE DATABASE');
  const migrationIndex = script.indexOf('npm run migrate');

  expect(script).toContain('DB_NAME="${DB_NAME:-private_chat}"');
  expect(script).toContain('DB_USER="${DB_USER:-chat_user}"');
  expect(script).toContain('DB_PASSWORD="${CHAT_DB_PASSWORD:-chat_password_change_me}"');
  expect(script).toContain('sudo -u postgres psql');
  expect(script).toContain('[[ "$DB_NAME" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]');
  expect(script).toContain('[[ "$DB_USER" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]');
  expect(script).toContain('sql_literal()');
  expect(script).toContain('CREATE ROLE');
  expect(script).toContain('CREATE DATABASE');
  expect(script).toContain('ALTER DATABASE');
  expect(databaseSetupIndex).toBeGreaterThan(-1);
  expect(migrationIndex).toBeGreaterThan(databaseSetupIndex);
});

test('deploy.sh avoids psql variables inside dollar-quoted SQL blocks', () => {
  const script = fs.readFileSync(path.join(__dirname, '..', 'deploy.sh'), 'utf8');

  expect(script).not.toContain('DO $$');
  expect(script).not.toContain(":'db_user'");
  expect(script).not.toContain(':"db_name"');
  expect(script).not.toMatch(/<<'?SQL'?/);
});

test('deploy.sh does not reset existing database role password by default', () => {
  const script = fs.readFileSync(path.join(__dirname, '..', 'deploy.sh'), 'utf8');

  expect(script).toContain('FORCE_DB_PASSWORD_UPDATE="${FORCE_DB_PASSWORD_UPDATE:-0}"');
  expect(script).toContain('if [ "$FORCE_DB_PASSWORD_UPDATE" = "1" ] && [ -n "${CHAT_DB_PASSWORD:-}" ]; then');
  expect(script).not.toMatch(/ELSE\s+[\s\S]*ALTER ROLE[\s\S]*PASSWORD/);
});

test('deploy.sh preserves .env and creates one with DATABASE_URL when missing', () => {
  const script = fs.readFileSync(path.join(__dirname, '..', 'deploy.sh'), 'utf8');

  expect(script).toContain('--exclude .env');
  expect(script).toContain('--exclude storage');
  expect(script).toContain('if [ ! -f "$APP_DIR/.env" ]; then');
  expect(script).toContain('cp "$APP_DIR/.env.example" "$APP_DIR/.env"');
  expect(script).toContain('DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@localhost:5432/${DB_NAME}');
  expect(script).toContain('extract_database_url_password()');
  expect(script).toContain('existing_db_password="$(extract_database_url_password "$APP_DIR/.env")"');
  expect(script).toContain('if [ -z "${CHAT_DB_PASSWORD:-}" ] && [ -n "$existing_db_password" ]; then');
  expect(script).toContain('DB_PASSWORD="$existing_db_password"');
});

test('.env.example documents required deployment defaults', () => {
  const envPath = path.join(__dirname, '..', '.env.example');
  const env = fs.readFileSync(envPath, 'utf8');

  expect(env).toContain('API_PORT=3000');
  expect(env).toContain('WS_PORT=3001');
  expect(env).toContain('DATABASE_URL=');
  expect(env).toContain('JWT_SECRET=');
  expect(env).toContain('STORAGE_PATH=');
  expect(env).toContain('LAN_HOST=192.168.1.103');
  expect(env).toContain('PUBLIC_DOMAIN=wdsj.fun');
});
