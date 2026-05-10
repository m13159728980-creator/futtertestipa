const { assertAppliedMigrationChecksum, calculateChecksum, runMigrations } = require('../database/migrate');
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

test('assertAppliedMigrationChecksum passes when stored checksum matches current checksum', () => {
  expect(() => {
    assertAppliedMigrationChecksum('001_initial.sql', 'abc123', 'abc123');
  }).not.toThrow();
});

test('assertAppliedMigrationChecksum throws when an applied migration has no stored checksum', () => {
  expect(() => {
    assertAppliedMigrationChecksum('001_initial.sql', null, 'abc123');
  }).toThrow('pre-checksum migration table must be reconciled/reset before continuing');
});

test('assertAppliedMigrationChecksum throws when an applied migration checksum changed', () => {
  expect(() => {
    assertAppliedMigrationChecksum('001_initial.sql', 'old-checksum', 'new-checksum');
  }).toThrow('Migration checksum mismatch for 001_initial.sql');
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

  test('creates critical columns with expected metadata from the approved chat schema', async () => {
    await runMigrations({ connectionString: process.env.TEST_DATABASE_URL });
    await closePool(process.env.TEST_DATABASE_URL);

    const { rows } = await query(
      `
        SELECT table_name, column_name, data_type, character_maximum_length
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = ANY($1)
        ORDER BY table_name, column_name
      `,
      [requiredTables]
    );
    const columnsByTable = rows.reduce((tables, row) => {
      tables[row.table_name] = tables[row.table_name] || {};
      tables[row.table_name][row.column_name] = row;
      return tables;
    }, {});

    expect(Object.keys(columnsByTable.users)).toEqual(expect.arrayContaining([
      'id',
      'account',
      'display_name',
      'avatar_index',
      'token_version',
      'deleted_at',
      'created_at'
    ]));
    expect(columnsByTable.users.password_hash).toBeUndefined();
    expect(columnsByTable.users.id.data_type).toBe('bigint');
    expect(columnsByTable.users.display_name.character_maximum_length).toBe(24);

    expect(Object.keys(columnsByTable.messages)).toEqual(expect.arrayContaining([
      'from_id',
      'to_id',
      'to_type',
      'type',
      'content',
      'media_id',
      'burn_after',
      'burn_started_at',
      'status',
      'created_at',
      'deleted_at'
    ]));

    expect(Object.keys(columnsByTable.groups)).toEqual(expect.arrayContaining(['name', 'burn_enabled']));
    expect(columnsByTable.groups.name.character_maximum_length).toBe(50);
    expect(columnsByTable.group_members.removed_at).toBeDefined();
    expect(columnsByTable.account_deletions.purge_after).toBeDefined();
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
    expect(rows.some((row) => row.contype === 'c' && row.definition.includes('^[0-9]{10}$'))).toBe(true);
  });
}
