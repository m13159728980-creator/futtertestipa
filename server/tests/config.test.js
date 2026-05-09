const originalEnv = process.env;

function loadConfig(env = {}) {
  jest.resetModules();
  process.env = { ...originalEnv, ...env };
  return require('../src/config');
}

afterEach(() => {
  process.env = originalEnv;
  jest.resetModules();
});

test('uses default numeric config values', () => {
  const config = loadConfig({
    API_PORT: undefined,
    WS_PORT: undefined,
    OFFLINE_RETENTION_DAYS: undefined
  });

  expect(config.apiPort).toBe(3000);
  expect(config.wsPort).toBe(3001);
  expect(config.offlineRetentionDays).toBe(7);
});

test('falls back when API_PORT is malformed', () => {
  const config = loadConfig({ API_PORT: '3000abc' });

  expect(config.apiPort).toBe(3000);
});

test('falls back when WS_PORT is malformed', () => {
  const config = loadConfig({ WS_PORT: '3001abc' });

  expect(config.wsPort).toBe(3001);
});

test('falls back when OFFLINE_RETENTION_DAYS is malformed', () => {
  const config = loadConfig({ OFFLINE_RETENTION_DAYS: '7abc' });

  expect(config.offlineRetentionDays).toBe(7);
});

test('falls back when API_PORT uses exponential notation', () => {
  const config = loadConfig({ API_PORT: '1e3' });

  expect(config.apiPort).toBe(3000);
});

test('falls back when API_PORT uses hexadecimal notation', () => {
  const config = loadConfig({ API_PORT: '0x50' });

  expect(config.apiPort).toBe(3000);
});

test('accepts decimal API_PORT with surrounding whitespace', () => {
  const config = loadConfig({ API_PORT: ' 4000 ' });

  expect(config.apiPort).toBe(4000);
});

test('falls back when API_PORT is below valid port range', () => {
  const config = loadConfig({ API_PORT: '-1' });

  expect(config.apiPort).toBe(3000);
});

test('falls back when API_PORT is above valid port range', () => {
  const config = loadConfig({ API_PORT: '70000' });

  expect(config.apiPort).toBe(3000);
});

test('accepts valid WS_PORT override', () => {
  const config = loadConfig({ WS_PORT: '4000' });

  expect(config.wsPort).toBe(4000);
});

test('falls back when OFFLINE_RETENTION_DAYS is not positive', () => {
  const config = loadConfig({ OFFLINE_RETENTION_DAYS: '0' });

  expect(config.offlineRetentionDays).toBe(7);
});
