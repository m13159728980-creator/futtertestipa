const { Pool } = require('pg');
const config = require('../src/config');

let pool;

function getPool(options = {}) {
  if (!pool) {
    pool = new Pool({
      connectionString: options.connectionString || process.env.TEST_DATABASE_URL || process.env.DATABASE_URL || config.databaseUrl
    });
  }

  return pool;
}

async function query(text, params) {
  return getPool().query(text, params);
}

async function transaction(callback) {
  const client = await getPool().connect();

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

async function closePool() {
  if (pool) {
    await pool.end();
    pool = undefined;
  }
}

module.exports = {
  getPool,
  query,
  transaction,
  closePool
};
