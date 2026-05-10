require('dotenv').config();

function parseInteger(value, fallback, isValid = () => true) {
  const normalized = String(value).trim();
  if (!/^[0-9]+$/.test(normalized)) {
    return fallback;
  }

  const parsed = Number(normalized);
  return Number.isInteger(parsed) && isValid(parsed) ? parsed : fallback;
}

const lanHost = process.env.LAN_HOST || '192.168.1.103';
const publicDomain = process.env.PUBLIC_DOMAIN || 'wdsj.fun';
const isValidPort = (value) => value >= 1 && value <= 65535;
const isPositive = (value) => value > 0;
const apiPort = parseInteger(process.env.API_PORT, 10080, isValidPort);
const wsPort = parseInteger(process.env.WS_PORT, 10081, isValidPort);

module.exports = {
  apiPort,
  wsPort,
  databaseUrl: process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/private_chat',
  jwtSecret: process.env.JWT_SECRET || 'change-me-in-production',
  storagePath: process.env.STORAGE_PATH || './storage',
  lanUrl: process.env.LAN_URL || `http://${lanHost}:${apiPort}`,
  publicUrl: process.env.PUBLIC_URL || `http://${publicDomain}:${apiPort}`,
  offlineRetentionDays: parseInteger(process.env.OFFLINE_RETENTION_DAYS, 7, isPositive)
};
