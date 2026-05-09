const { Pool } = require('pg');
const config = require('../src/config');

const pools = new Map();

function resolveConnectionString(options = {}) {
  return options.connectionString || process.env.TEST_DATABASE_URL || process.env.DATABASE_URL || config.databaseUrl;
}

function getPool(options = {}) {
  const connectionString = resolveConnectionString(options);

  if (!pools.has(connectionString)) {
    pools.set(connectionString, new Pool({ connectionString }));
  }

  return pools.get(connectionString);
}

async function query(text, params, options = {}) {
  return getPool(options).query(text, params);
}

async function transaction(callback, options = {}) {
  const client = await getPool(options).connect();

  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

async function closePool(connectionString) {
  const key = connectionString || resolveConnectionString();
  const pool = pools.get(key);

  if (pool) {
    await pool.end();
    pools.delete(key);
  }
}

async function closeAllPools() {
  await Promise.all(Array.from(pools.values(), (pool) => pool.end()));
  pools.clear();
}

module.exports = {
  closeAllPools,
  closePool,
  getPool,
  query,
  transaction
};
