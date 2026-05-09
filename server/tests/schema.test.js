const { calculateChecksum, runMigrations } = require('../database/migrate');
const { closeAllPools, closePool, getPool, query } = require('../database/db');

const requiredTables = [
  'account_deletions',
  'contacts',
  'group_members',
  'groups',
  'media_files',
  'message_reads',
  'messages',
  'sticker_packs',
  'users'
];

if (!process.env.TEST_DATABASE_URL) {
  console.log('Skipping database schema integration tests: TEST_DATABASE_URL is not set.');
}

afterEach(async () => {
  await closeAllPools();
});

test('calculateChecksum returns a stable sha256 hash for migration SQL', () => {
  expect(calculateChecksum('SELECT 1;\n')).toBe('b4e0497804e46e0a0b0b8c31975b062152d551bac49c3c2e80932567b4085dcd');
});

test('getPool keeps separate pools for separate connection strings', async () => {
  const first = getPool({ connectionString: 'postgres://user:pass@localhost:5432/one' });
  const second = getPool({ connectionString: 'postgres://user:pass@localhost:5432/two' });

  expect(second).not.toBe(first);
  expect(getPool({ connectionString: 'postgres://user:pass@localhost:5432/one' })).toBe(first);

  await closePool('postgres://user:pass@localhost:5432/one');
  expect(getPool({ connectionString: 'postgres://user:pass@localhost:5432/one' })).not.toBe(first);
});

if (!process.env.TEST_DATABASE_URL) {
  test.skip('skips database schema integration tests because TEST_DATABASE_URL is not set', () => {});
} else {
  test('runs migrations and creates all required chat schema tables', async () => {
    await runMigrations({ connectionString: process.env.TEST_DATABASE_URL });
    await closePool(process.env.TEST_DATABASE_URL);

    const { rows } = await query(
      `
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name = ANY($1)
        ORDER BY table_name
      `,
      [requiredTables]
    );

    expect(rows.map((row) => row.table_name)).toEqual(requiredTables);
  });

  test('creates critical columns from the approved chat schema', async () => {
    await runMigrations({ connectionString: process.env.TEST_DATABASE_URL });
    await closePool(process.env.TEST_DATABASE_URL);

    const { rows } = await query(
      `
        SELECT table_name, column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = ANY($1)
        ORDER BY table_name, column_name
      `,
      [requiredTables]
    );
    const columnsByTable = rows.reduce((tables, row) => {
      tables[row.table_name] = tables[row.table_name] || new Set();
      tables[row.table_name].add(row.column_name);
      return tables;
    }, {});

    expect(Array.from(columnsByTable.users)).toEqual(expect.arrayContaining(['avatar_index', 'token_version']));
    expect(columnsByTable.users.has('password_hash')).toBe(false);
    expect(Array.from(columnsByTable.messages)).toEqual(expect.arrayContaining(['burn_after', 'burn_started_at', 'media_id', 'deleted_at']));
    expect(columnsByTable.groups.has('burn_enabled')).toBe(true);
    expect(columnsByTable.group_members.has('removed_at')).toBe(true);
    expect(columnsByTable.account_deletions.has('purge_after')).toBe(true);
  });

  test('creates users account unique and format constraints', async () => {
    await runMigrations({ connectionString: process.env.TEST_DATABASE_URL });
    await closePool(process.env.TEST_DATABASE_URL);

    const { rows } = await query(
      `
        SELECT conname, contype, pg_get_constraintdef(oid) AS definition
        FROM pg_constraint
        WHERE conrelid = 'users'::regclass
          AND (contype = 'u' OR contype = 'c')
        ORDER BY conname
      `
    );

    expect(rows.some((row) => row.contype === 'u' && row.definition.includes('UNIQUE (account)'))).toBe(true);
    expect(rows.some((row) => row.contype === 'c' && row.definition.includes('^@[A-Za-z]{1,9}$'))).toBe(true);
  });
}
