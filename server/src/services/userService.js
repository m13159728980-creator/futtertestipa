const db = require('../../database/db');
const crypto = require('crypto');

const ACCOUNT_PATTERN = /^\d{10}$/;
const ACCOUNT_MESSAGE = '\u8bf7\u8f93\u516510\u4f4d\u6570\u5b57ID';
const NAME_MESSAGE = '\u8bf7\u8f93\u5165\u540d\u5b57';
const DUPLICATE_ACCOUNT_MESSAGE = 'ID\u5df2\u88ab\u5360\u7528';
const DELETE_CONFIRMATION_MESSAGE = '\u8bf7\u8f93\u5165\u6b63\u786eID\u786e\u8ba4\u6ce8\u9500';
const AVATAR_MESSAGE = '\u5934\u50cf\u7f16\u53f7\u5fc5\u987b\u57280\u52308\u4e4b\u95f4';
const USER_NOT_FOUND_MESSAGE = '\u7528\u6237\u4e0d\u5b58\u5728';

class UserServiceError extends Error {
  constructor(message, statusCode) {
    super(message);
    this.name = 'UserServiceError';
    this.statusCode = statusCode;
  }
}

function mapUser(row) {
  if (!row) {
    return null;
  }

  return {
    id: Number(row.id),
    account: row.account,
    displayName: row.displayName || row.display_name,
    avatarIndex: Number(row.avatarIndex ?? row.avatar_index),
    tokenVersion: Number(row.tokenVersion ?? row.token_version ?? 0),
    deletedAt: row.deletedAt ?? row.deleted_at ?? null
  };
}

function serializeUser(user) {
  return {
    id: Number(user.id),
    account: user.account,
    displayName: user.displayName,
    avatarIndex: Number(user.avatarIndex)
  };
}

function normalizeDisplayName(input) {
  const displayName = String(input || '').trim();
  if (!displayName || [...displayName].length > 24) {
    throw new UserServiceError(NAME_MESSAGE, 400);
  }
  return displayName;
}

function validateAccount(account) {
  if (!ACCOUNT_PATTERN.test(String(account || ''))) {
    throw new UserServiceError(ACCOUNT_MESSAGE, 400);
  }
}

function generatePublicId() {
  return String(crypto.randomInt(1000000000, 10000000000));
}

function isDuplicateError(error) {
  return error && error.code === '23505';
}

function createPostgresUserRepository(query = db.query) {
  return {
    async findByAccount(account) {
      const { rows } = await query(
        `
          SELECT id, account, display_name, avatar_index, token_version, deleted_at
          FROM users
          WHERE account = $1
          LIMIT 1
        `,
        [account]
      );
      return mapUser(rows[0]);
    },

    async findActiveByAccount(account) {
      const { rows } = await query(
        `
          SELECT id, account, display_name, avatar_index, token_version, deleted_at
          FROM users
          WHERE account = $1
            AND deleted_at IS NULL
          LIMIT 1
        `,
        [account]
      );
      return mapUser(rows[0]);
    },

    async findActiveById(id) {
      const { rows } = await query(
        `
          SELECT id, account, display_name, avatar_index, token_version, deleted_at
          FROM users
          WHERE id = $1
            AND deleted_at IS NULL
          LIMIT 1
        `,
        [id]
      );
      return mapUser(rows[0]);
    },

    async create({ account, displayName, avatarIndex }) {
      const { rows } = await query(
        `
          INSERT INTO users (account, display_name, avatar_index)
          VALUES ($1, $2, $3)
          RETURNING id, account, display_name, avatar_index, token_version, deleted_at
        `,
        [account, displayName, avatarIndex]
      );
      return mapUser(rows[0]);
    },

    async updateAvatar(id, avatarIndex) {
      const { rows } = await query(
        `
          UPDATE users
          SET avatar_index = $2
          WHERE id = $1
            AND deleted_at IS NULL
          RETURNING id, account, display_name, avatar_index, token_version, deleted_at
        `,
        [id, avatarIndex]
      );
      return mapUser(rows[0]);
    },

    async softDelete(id) {
      const { rows } = await query(
        `
          WITH deleted_user AS (
            UPDATE users
            SET deleted_at = NOW(),
                token_version = token_version + 1
            WHERE id = $1
              AND deleted_at IS NULL
            RETURNING id, account, display_name, avatar_index, token_version, deleted_at
          ),
          scheduled_deletion AS (
            INSERT INTO account_deletions (user_id, purge_after)
            SELECT id, NOW() + INTERVAL '30 days'
            FROM deleted_user
            ON CONFLICT (user_id) DO UPDATE
            SET requested_at = NOW(),
                purge_after = EXCLUDED.purge_after,
                completed_at = NULL
            RETURNING user_id
          )
          SELECT id, account, display_name, avatar_index, token_version, deleted_at
          FROM deleted_user
        `,
        [id]
      );
      return mapUser(rows[0]);
    }
  };
}

function createUserService(options = {}) {
  const repository = options.repository || options.userRepository || createPostgresUserRepository(options.query);
  const publicIdGenerator = options.publicIdGenerator || generatePublicId;

  async function isAccountAvailable(account) {
    validateAccount(account);
    const existing = repository.findActiveByAccount
      ? await repository.findActiveByAccount(account)
      : await repository.findByAccount(account);
    return !existing;
  }

  async function register({ displayName, name }) {
    const normalizedDisplayName = normalizeDisplayName(displayName ?? name);

    for (let attempt = 0; attempt < 20; attempt += 1) {
      const account = publicIdGenerator();
      validateAccount(account);
      const existing = await repository.findByAccount(account);
      if (existing) {
        continue;
      }

      try {
        const avatarIndex = Math.floor(Math.random() * 9);
        return mapUser(await repository.create({ account, displayName: normalizedDisplayName, avatarIndex }));
      } catch (error) {
        if (isDuplicateError(error)) {
          continue;
        }
        throw error;
      }
    }

    throw new UserServiceError(DUPLICATE_ACCOUNT_MESSAGE, 409);
  }

  async function validateTokenPayload(payload) {
    if (!payload || !payload.userId || !payload.account || !Number.isInteger(Number(payload.tokenVersion))) {
      return null;
    }

    const user = await repository.findActiveById(payload.userId);
    if (!user || user.account !== payload.account || Number(user.tokenVersion) !== Number(payload.tokenVersion)) {
      return null;
    }

    return user;
  }

  async function updateAvatar(userId, avatarIndex) {
    if (!Number.isInteger(avatarIndex) || avatarIndex < 0 || avatarIndex > 8) {
      throw new UserServiceError(AVATAR_MESSAGE, 400);
    }

    const user = await repository.updateAvatar(userId, avatarIndex);
    if (!user) {
      throw new UserServiceError(USER_NOT_FOUND_MESSAGE, 404);
    }
    return user;
  }

  async function softDelete(userId, confirmationAccount) {
    const activeUser = await repository.findActiveById(userId);
    if (!activeUser) {
      throw new UserServiceError(USER_NOT_FOUND_MESSAGE, 404);
    }

    if (confirmationAccount !== activeUser.account) {
      throw new UserServiceError(DELETE_CONFIRMATION_MESSAGE, 400);
    }

    const deletedUser = await repository.softDelete(userId);
    if (!deletedUser) {
      throw new UserServiceError(USER_NOT_FOUND_MESSAGE, 404);
    }
    return deletedUser;
  }

  return {
    isAccountAvailable,
    register,
    serializeUser,
    softDelete,
    updateAvatar,
    validateTokenPayload
  };
}

module.exports = {
  ACCOUNT_MESSAGE,
  DELETE_CONFIRMATION_MESSAGE,
  DUPLICATE_ACCOUNT_MESSAGE,
  NAME_MESSAGE,
  UserServiceError,
  createPostgresUserRepository,
  createUserService,
  serializeUser
};
