const db = require('../../database/db');

function createPostgresAccountPurgeRepository(query = db.query) {
  return {
    async listDueDeletions(now) {
      const { rows } = await query(
        `
          SELECT user_id, purge_after
          FROM account_deletions
          WHERE purge_after <= $1
            AND completed_at IS NULL
          ORDER BY purge_after ASC
        `,
        [now]
      );
      return rows.map((row) => ({
        userId: Number(row.user_id),
        purgeAfter: row.purge_after
      }));
    },

    async purgeUser(userId) {
      const { rowCount } = await query('DELETE FROM users WHERE id = $1 AND deleted_at IS NOT NULL', [userId]);
      return rowCount > 0;
    },

    async markCompleted(userId, completedAt) {
      await query(
        'UPDATE account_deletions SET completed_at = $2 WHERE user_id = $1 AND completed_at IS NULL',
        [userId, completedAt]
      );
    }
  };
}

function createAccountPurgeJob(options = {}) {
  const repository = options.repository || createPostgresAccountPurgeRepository(options.query);
  const now = options.now || (() => new Date());
  const intervalMs = options.intervalMs || 60 * 60 * 1000;
  let timer = null;

  async function runOnce() {
    const completedAt = now();
    const due = await repository.listDueDeletions(completedAt);
    let purged = 0;
    let completed = 0;

    for (const deletion of due) {
      if (await repository.purgeUser(deletion.userId)) {
        purged += 1;
        await repository.markCompleted(deletion.userId, completedAt);
        completed += 1;
      }
    }

    return { processed: due.length, purged, completed };
  }

  function start() {
    if (!timer) {
      timer = setInterval(runOnce, intervalMs);
    }
    return timer;
  }

  function stop() {
    if (timer) {
      clearInterval(timer);
      timer = null;
    }
  }

  return {
    runOnce,
    start,
    stop
  };
}

module.exports = {
  createAccountPurgeJob,
  createPostgresAccountPurgeRepository
};
