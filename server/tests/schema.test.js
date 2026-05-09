const { closePool, query } = require('../database/db');
const { runMigrations } = require('../database/migrate');

if (!process.env.TEST_DATABASE_URL) {
  console.log('Skipping schema.test.js: TEST_DATABASE_URL is not set.');
}

afterAll(async () => {
  await closePool();
});

if (!process.env.TEST_DATABASE_URL) {
  test.skip('skips schema migration test because TEST_DATABASE_URL is not set', () => {});
} else {
  test('runs initial migrations and creates core schema tables', async () => {
    await runMigrations({ connectionString: process.env.TEST_DATABASE_URL });
    await closePool();

    const { rows } = await query(
      `
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name = ANY($1)
        ORDER BY table_name
      `,
      [['groups', 'messages', 'users']]
    );

    expect(rows.map((row) => row.table_name)).toEqual(['groups', 'messages', 'users']);
  });
}
