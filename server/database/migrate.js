const fs = require('fs/promises');
const crypto = require('crypto');
const path = require('path');
const { closePool, getPool } = require('./db');

const migrationsDir = path.join(__dirname, 'migrations');
const migrationLockKey = 912357001;

function calculateChecksum(sql) {
  return crypto.createHash('sha256').update(sql).digest('hex');
}

async function ensureMigrationsTable(client) {
  await client.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      filename TEXT PRIMARY KEY,
      checksum TEXT NOT NULL,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
}

async function getAppliedMigrations(client) {
  const { rows } = await client.query('SELECT filename, checksum FROM schema_migrations ORDER BY filename');
  return new Map(rows.map((row) => [row.filename, row.checksum]));
}

async function readMigrationFiles(directory = migrationsDir) {
  const filenames = await fs.readdir(directory);
  return filenames
    .filter((filename) => filename.endsWith('.sql'))
    .sort();
}

async function runMigrations(options = {}) {
  const pool = getPool({ connectionString: options.connectionString });
  const directory = options.migrationsDir || migrationsDir;
  const client = await pool.connect();
  let lockAcquired = false;

  try {
    await client.query('SELECT pg_advisory_lock($1)', [migrationLockKey]);
    lockAcquired = true;
    await ensureMigrationsTable(client);
    const applied = await getAppliedMigrations(client);
    const files = await readMigrationFiles(directory);
    const appliedNow = [];

    for (const filename of files) {
      const sql = await fs.readFile(path.join(directory, filename), 'utf8');
      const checksum = calculateChecksum(sql);

      if (applied.has(filename)) {
        if (applied.get(filename) !== checksum) {
          throw new Error(`Migration checksum mismatch for ${filename}`);
        }

        continue;
      }

      try {
        await client.query('BEGIN');
        await client.query(sql);
        await client.query('INSERT INTO schema_migrations (filename, checksum) VALUES ($1, $2)', [filename, checksum]);
        await client.query('COMMIT');
        appliedNow.push(filename);
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      }
    }

    return appliedNow;
  } finally {
    if (lockAcquired) {
      await client.query('SELECT pg_advisory_unlock($1)', [migrationLockKey]);
    }
    client.release();
  }
}

if (require.main === module) {
  runMigrations()
    .then((applied) => {
      if (applied.length > 0) {
        console.log(`Applied migrations: ${applied.join(', ')}`);
      } else {
        console.log('No pending migrations.');
      }
    })
    .catch((error) => {
      console.error(error);
      process.exitCode = 1;
    })
    .finally(async () => {
      await closePool();
    });
}

module.exports = {
  calculateChecksum,
  runMigrations
};
