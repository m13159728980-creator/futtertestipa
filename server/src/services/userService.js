const db = require('../../database/db');

const ACCOUNT_PATTERN = /^@[A-Za-z]{1,9}$/;
const ACCOUNT_MESSAGE = '账号必须是英文，且以@开头';
const NAME_MESSAGE = '请输入名字';
const DUPLICATE_ACCOUNT_MESSAGE = '账号已被注册';

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

function isDuplicateError(error) {
  return error && error.code === '23505';
}

function createPostgresUserRepository(query = db.query) {
  return {
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
          UPDATE users
          SET deleted_at = NOW(),
              token_version = token_version + 1
          WHERE id = $1
            AND deleted_at IS NULL
          RETURNING id, account, display_name, avatar_index, token_version, deleted_at
        `,
        [id]
      );
      return mapUser(rows[0]);
    }
  };
}

function createUserService(options = {}) {
  const repository = options.repository || options.userRepository || createPostgresUserRepository(options.query);

  async function isAccountAvailable(account) {
    validateAccount(account);
    const existing = await repository.findActiveByAccount(account);
    return !existing;
  }

  async function register({ account, displayName, name }) {
    validateAccount(account);
    const normalizedDisplayName = normalizeDisplayName(displayName ?? name);
    const existing = await repository.findActiveByAccount(account);

    if (existing) {
      throw new UserServiceError(DUPLICATE_ACCOUNT_MESSAGE, 409);
    }

    try {
      const avatarIndex = Math.floor(Math.random() * 9);
      return mapUser(await repository.create({ account, displayName: normalizedDisplayName, avatarIndex }));
    } catch (error) {
      if (isDuplicateError(error)) {
        throw new UserServiceError(DUPLICATE_ACCOUNT_MESSAGE, 409);
      }
      throw error;
    }
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
      throw new UserServiceError('头像编号必须在0到8之间', 400);
    }

    const user = await repository.updateAvatar(userId, avatarIndex);
    if (!user) {
      throw new UserServiceError('用户不存在', 404);
    }
    return user;
  }

  async function softDelete(userId) {
    const user = await repository.softDelete(userId);
    if (!user) {
      throw new UserServiceError('用户不存在', 404);
    }
    return user;
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
  DUPLICATE_ACCOUNT_MESSAGE,
  NAME_MESSAGE,
  UserServiceError,
  createPostgresUserRepository,
  createUserService,
  serializeUser
};
