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
  expect(script).not.toMatch(/rm\s+-rf\s+\$?APP_DIR/);
  expect(script).not.toContain('git reset --hard');
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
