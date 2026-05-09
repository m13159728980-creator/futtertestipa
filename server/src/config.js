require('dotenv').config();

function parseInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

const lanHost = process.env.LAN_HOST || '192.168.1.103';
const publicDomain = process.env.PUBLIC_DOMAIN || 'wdsj.fun';
const apiPort = parseInteger(process.env.API_PORT, 3000);
const wsPort = parseInteger(process.env.WS_PORT, 3001);

module.exports = {
  apiPort,
  wsPort,
  databaseUrl: process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/private_chat',
  jwtSecret: process.env.JWT_SECRET || 'change-me-in-production',
  storagePath: process.env.STORAGE_PATH || './storage',
  lanUrl: process.env.LAN_URL || `http://${lanHost}:${apiPort}`,
  publicUrl: process.env.PUBLIC_URL || `http://${publicDomain}:${apiPort}`,
  offlineRetentionDays: parseInteger(process.env.OFFLINE_RETENTION_DAYS, 7)
};
