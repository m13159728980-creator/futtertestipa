const fs = require('fs/promises');
const path = require('path');
const { closePool, getPool } = require('./db');

const migrationsDir = path.join(__dirname, 'migrations');

async function ensureMigrationsTable(client) {
  await client.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      filename TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
}

async function getAppliedMigrations(client) {
  const { rows } = await client.query('SELECT filename FROM schema_migrations ORDER BY filename');
  return new Set(rows.map((row) => row.filename));
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

  try {
    await ensureMigrationsTable(client);
    const applied = await getAppliedMigrations(client);
    const files = await readMigrationFiles(directory);
    const appliedNow = [];

    for (const filename of files) {
      if (applied.has(filename)) {
        continue;
      }

      const sql = await fs.readFile(path.join(directory, filename), 'utf8');

      try {
        await client.query('BEGIN');
        await client.query(sql);
        await client.query('INSERT INTO schema_migrations (filename) VALUES ($1)', [filename]);
        await client.query('COMMIT');
        appliedNow.push(filename);
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      }
    }

    return appliedNow;
  } finally {
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
  runMigrations
};
