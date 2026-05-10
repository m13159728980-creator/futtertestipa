const { randomUUID } = require('crypto');
const db = require('../../database/db');

const REVOKE_WINDOW_MS = 5 * 60 * 1000;
const SYNC_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;
const VALID_TO_TYPES = new Set(['user', 'group']);
const VALID_TYPES = new Set(['text', 'image', 'voice', 'file', 'sticker', 'call_event', 'revoked', 'burn']);
const VALID_BURN_AFTER = new Set([0, 5, 10, 30, 60]);
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

class MessageServiceError extends Error {
  constructor(message, statusCode) {
    super(message);
    this.name = 'MessageServiceError';
    this.statusCode = statusCode;
  }
}

function toIso(value) {
  return value ? new Date(value).toISOString() : null;
}

function mapMessage(row) {
  if (!row) {
    return null;
  }

  return {
    id: row.id,
    fromId: Number(row.fromId ?? row.from_id),
    toId: Number(row.toId ?? row.to_id),
    toType: row.toType ?? row.to_type,
    type: row.type,
    content: row.content,
    timestamp: toIso(row.timestamp ?? row.created_at ?? row.createdAt),
    burnAfter: Number(row.burnAfter ?? row.burn_after ?? 0),
    burnStartedAt: toIso(row.burnStartedAt ?? row.burn_started_at),
    status: row.status,
    deletedAt: toIso(row.deletedAt ?? row.deleted_at)
  };
}

function uniqueNumbers(values) {
  return Array.from(new Set(values.map(Number))).filter((value) => Number.isInteger(value));
}

function createMemoryMessageRepository() {
  const messages = [];
  const reads = [];
  const groupMembers = new Map();
  const users = new Set();
  const privateBurnSettings = new Map();

  function activeGroupMemberIds(groupId) {
    return (groupMembers.get(Number(groupId)) || [])
      .filter((member) => !member.removedAt)
      .map((member) => Number(member.userId));
  }

  return {
    setActiveUsers(userIds) {
      users.clear();
      userIds.forEach((userId) => users.add(Number(userId)));
    },

    setGroupMembers(groupId, members) {
      groupMembers.set(Number(groupId), members.map((member) => ({
        userId: Number(member.userId),
        removedAt: member.removedAt ?? null
      })));
    },

    async createMessage(data) {
      const row = {
        id: data.id || randomUUID(),
        fromId: Number(data.fromId),
        toId: Number(data.toId),
        toType: data.toType,
        type: data.type,
        content: data.content ?? null,
        burnAfter: Number(data.burnAfter || 0),
        burnStartedAt: null,
        status: 'sent',
        createdAt: data.createdAt,
        deletedAt: null
      };
      messages.push(row);
      return mapMessage(row);
    },

    async findMessageById(id) {
      return mapMessage(messages.find((message) => message.id === id));
    },

    async userExists(userId) {
      return users.size === 0 || users.has(Number(userId));
    },

    async isActiveGroupMember(groupId, userId) {
      return activeGroupMemberIds(groupId).includes(Number(userId));
    },

    async groupTargetIds(groupId) {
      return activeGroupMemberIds(groupId);
    },

    async markDelivered(id) {
      const message = messages.find((candidate) => candidate.id === id);
      if (!message) {
        return null;
      }
      if (message.status === 'sent') {
        message.status = 'delivered';
      }
      return mapMessage(message);
    },

    async markRead(id, userId, readAt) {
      const message = messages.find((candidate) => candidate.id === id);
      if (!message) {
        return null;
      }
      if (!reads.some((read) => read.messageId === id && read.userId === Number(userId))) {
        reads.push({ messageId: id, userId: Number(userId), readAt });
      }
      if (!['revoked', 'burned'].includes(message.status)) {
        message.status = 'read';
      }
      return mapMessage(message);
    },

    async listReads(messageId) {
      return reads
        .filter((read) => read.messageId === messageId)
        .map((read) => ({ ...read, readAt: toIso(read.readAt) }));
    },

    async revokeMessage(id) {
      const message = messages.find((candidate) => candidate.id === id);
      if (!message) {
        return null;
      }
      message.status = 'revoked';
      message.content = null;
      return mapMessage(message);
    },

    async startBurn(id, startedAt) {
      const message = messages.find((candidate) => candidate.id === id);
      if (!message) {
        return null;
      }
      if (!message.burnStartedAt) {
        message.burnStartedAt = startedAt;
      }
      return mapMessage(message);
    },

    async findExpiredBurnMessages(now) {
      return messages
        .filter((message) =>
          message.burnAfter > 0 &&
          message.burnStartedAt &&
          !message.deletedAt &&
          !['revoked', 'burned'].includes(message.status) &&
          new Date(message.burnStartedAt).getTime() + message.burnAfter * 1000 <= now.getTime()
        )
        .map(mapMessage);
    },

    async markBurned(id, deletedAt) {
      const message = messages.find((candidate) => candidate.id === id);
      if (!message) {
        return null;
      }
      message.status = 'burned';
      message.deletedAt = deletedAt;
      return mapMessage(message);
    },

    async syncMessagesForUser(userId, since) {
      const activeGroups = Array.from(groupMembers.entries())
        .filter(([, members]) => members.some((member) => Number(member.userId) === Number(userId) && !member.removedAt))
        .map(([groupId]) => Number(groupId));

      return messages
        .filter((message) => !message.deletedAt)
        .filter((message) => new Date(message.createdAt).getTime() >= since.getTime())
        .filter((message) =>
          message.fromId === Number(userId) ||
          (message.toType === 'user' && message.toId === Number(userId)) ||
          (message.toType === 'group' && activeGroups.includes(message.toId))
        )
        .sort((left, right) => new Date(right.createdAt).getTime() - new Date(left.createdAt).getTime())
        .map(mapMessage);
    },

    async upsertPrivateBurnSetting(userAId, userBId, burnAfter, updatedAt) {
      const peerIds = sortedPrivatePeerIds(userAId, userBId);
      const row = {
        userAId: peerIds[0],
        userBId: peerIds[1],
        burnAfter: Number(burnAfter),
        updatedAt
      };
      privateBurnSettings.set(privateSettingKey(userAId, userBId), row);
      return mapPrivateBurnSetting(row);
    },

    async getPrivateBurnSetting(userAId, userBId) {
      return mapPrivateBurnSetting(privateBurnSettings.get(privateSettingKey(userAId, userBId)));
    }
  };
}

function createPostgresMessageRepository(query = db.query) {
  return {
    async createMessage(data) {
      const { rows } = await query(
        `
          INSERT INTO messages (id, from_id, to_id, to_type, type, content, burn_after, created_at)
          VALUES (COALESCE($1::uuid, gen_random_uuid()), $2, $3, $4, $5, $6, $7, $8)
          RETURNING id, from_id, to_id, to_type, type, content, burn_after, burn_started_at, status, created_at, deleted_at
        `,
        [data.id || null, data.fromId, data.toId, data.toType, data.type, data.content ?? null, data.burnAfter, data.createdAt]
      );
      return mapMessage(rows[0]);
    },

    async findMessageById(id) {
      const { rows } = await query(
        `
          SELECT id, from_id, to_id, to_type, type, content, burn_after, burn_started_at, status, created_at, deleted_at
          FROM messages
          WHERE id = $1
          LIMIT 1
        `,
        [id]
      );
      return mapMessage(rows[0]);
    },

    async userExists(userId) {
      const { rows } = await query(
        `
          SELECT 1
          FROM users
          WHERE id = $1
            AND deleted_at IS NULL
          LIMIT 1
        `,
        [userId]
      );
      return rows.length > 0;
    },

    async isActiveGroupMember(groupId, userId) {
      const { rows } = await query(
        `
          SELECT 1
          FROM group_members
          WHERE group_id = $1
            AND user_id = $2
            AND removed_at IS NULL
          LIMIT 1
        `,
        [groupId, userId]
      );
      return rows.length > 0;
    },

    async groupTargetIds(groupId) {
      const { rows } = await query(
        `
          SELECT user_id
          FROM group_members
          WHERE group_id = $1
            AND removed_at IS NULL
          ORDER BY joined_at ASC, user_id ASC
        `,
        [groupId]
      );
      return rows.map((row) => Number(row.user_id));
    },

    async markDelivered(id) {
      const { rows } = await query(
        `
          UPDATE messages
          SET status = CASE WHEN status = 'sent' THEN 'delivered' ELSE status END
          WHERE id = $1
          RETURNING id, from_id, to_id, to_type, type, content, burn_after, burn_started_at, status, created_at, deleted_at
        `,
        [id]
      );
      return mapMessage(rows[0]);
    },

    async markRead(id, userId, readAt) {
      await query(
        `
          INSERT INTO message_reads (message_id, user_id, read_at)
          VALUES ($1, $2, $3)
          ON CONFLICT (message_id, user_id) DO NOTHING
        `,
        [id, userId, readAt]
      );
      const { rows } = await query(
        `
          UPDATE messages
          SET status = CASE WHEN status IN ('revoked', 'burned') THEN status ELSE 'read' END
          WHERE id = $1
          RETURNING id, from_id, to_id, to_type, type, content, burn_after, burn_started_at, status, created_at, deleted_at
        `,
        [id]
      );
      return mapMessage(rows[0]);
    },

    async revokeMessage(id) {
      const { rows } = await query(
        `
          UPDATE messages
          SET status = 'revoked',
              content = NULL
          WHERE id = $1
          RETURNING id, from_id, to_id, to_type, type, content, burn_after, burn_started_at, status, created_at, deleted_at
        `,
        [id]
      );
      return mapMessage(rows[0]);
    },

    async startBurn(id, startedAt) {
      const { rows } = await query(
        `
          UPDATE messages
          SET burn_started_at = COALESCE(burn_started_at, $2)
          WHERE id = $1
          RETURNING id, from_id, to_id, to_type, type, content, burn_after, burn_started_at, status, created_at, deleted_at
        `,
        [id, startedAt]
      );
      return mapMessage(rows[0]);
    },

    async findExpiredBurnMessages(now) {
      const { rows } = await query(
        `
          SELECT id, from_id, to_id, to_type, type, content, burn_after, burn_started_at, status, created_at, deleted_at
          FROM messages
          WHERE burn_after > 0
            AND burn_started_at IS NOT NULL
            AND deleted_at IS NULL
            AND status NOT IN ('revoked', 'burned')
            AND burn_started_at + (burn_after * INTERVAL '1 second') <= $1
        `,
        [now]
      );
      return rows.map(mapMessage);
    },

    async markBurned(id, deletedAt) {
      const { rows } = await query(
        `
          UPDATE messages
          SET status = 'burned',
              deleted_at = $2
          WHERE id = $1
          RETURNING id, from_id, to_id, to_type, type, content, burn_after, burn_started_at, status, created_at, deleted_at
        `,
        [id, deletedAt]
      );
      return mapMessage(rows[0]);
    },

    async syncMessagesForUser(userId, since) {
      const { rows } = await query(
        `
          SELECT DISTINCT m.id, m.from_id, m.to_id, m.to_type, m.type, m.content, m.burn_after,
                 m.burn_started_at, m.status, m.created_at, m.deleted_at
          FROM messages m
          LEFT JOIN group_members gm
            ON gm.group_id = m.to_id
           AND m.to_type = 'group'
           AND gm.user_id = $1
           AND gm.removed_at IS NULL
          WHERE m.deleted_at IS NULL
            AND m.created_at >= $2
            AND (
              m.from_id = $1 OR
              (m.to_type = 'user' AND m.to_id = $1) OR
              (m.to_type = 'group' AND gm.user_id IS NOT NULL)
            )
          ORDER BY m.created_at DESC
        `,
        [userId, since]
      );
      return rows.map(mapMessage);
    },

    async upsertPrivateBurnSetting(userAId, userBId, burnAfter, updatedAt) {
      const [leftId, rightId] = sortedPrivatePeerIds(userAId, userBId);
      const { rows } = await query(
        `
          INSERT INTO private_conversation_settings (user_a_id, user_b_id, burn_after, updated_at)
          VALUES ($1, $2, $3, $4)
          ON CONFLICT (user_a_id, user_b_id) DO UPDATE
          SET burn_after = EXCLUDED.burn_after,
              updated_at = EXCLUDED.updated_at
          RETURNING user_a_id, user_b_id, burn_after, updated_at
        `,
        [leftId, rightId, burnAfter, updatedAt]
      );
      return mapPrivateBurnSetting(rows[0]);
    },

    async getPrivateBurnSetting(userAId, userBId) {
      const [leftId, rightId] = sortedPrivatePeerIds(userAId, userBId);
      const { rows } = await query(
        `
          SELECT user_a_id, user_b_id, burn_after, updated_at
          FROM private_conversation_settings
          WHERE user_a_id = $1
            AND user_b_id = $2
          LIMIT 1
        `,
        [leftId, rightId]
      );
      return mapPrivateBurnSetting(rows[0]);
    }
  };
}

function sortedPrivatePeerIds(userAId, userBId) {
  return [Number(userAId), Number(userBId)].sort((left, right) => left - right);
}

function privateSettingKey(userAId, userBId) {
  return sortedPrivatePeerIds(userAId, userBId).join(':');
}

function mapPrivateBurnSetting(row) {
  if (!row) {
    return null;
  }
  const peerIds = sortedPrivatePeerIds(row.userAId ?? row.user_a_id, row.userBId ?? row.user_b_id);
  const burnAfter = Number(row.burnAfter ?? row.burn_after ?? 0);
  return {
    toType: 'user',
    peerIds,
    burnAfter,
    enabled: burnAfter > 0
  };
}

function normalizeMessageInput(fromId, input, now) {
  const id = typeof input?.id === 'string' && input.id.trim() ? input.id.trim() : undefined;
  const toId = Number(input?.toId);
  const toType = input?.toType || 'user';
  const type = input?.type || 'text';
  const burnAfter = Number(input?.burnAfter ?? input?.burn_after ?? 0);

  if (id && !UUID_PATTERN.test(id)) {
    throw new MessageServiceError('Invalid message id', 400);
  }
  if (!Number.isInteger(Number(fromId)) || !Number.isInteger(toId)) {
    throw new MessageServiceError('Invalid message participants', 400);
  }
  if (!VALID_TO_TYPES.has(toType)) {
    throw new MessageServiceError('Invalid message target type', 400);
  }
  if (!VALID_TYPES.has(type)) {
    throw new MessageServiceError('Invalid message type', 400);
  }
  if (!VALID_BURN_AFTER.has(burnAfter)) {
    throw new MessageServiceError('Invalid burnAfter', 400);
  }

  return {
    id,
    fromId: Number(fromId),
    toId,
    toType,
    type,
    content: input?.content ?? null,
    burnAfter,
    createdAt: now()
  };
}

function createMessageService(options = {}) {
  const repository = options.messageRepository ||
    (!process.env.TEST_DATABASE_URL && options.useMemoryRepository
      ? createMemoryMessageRepository()
      : createPostgresMessageRepository(options.query));
  const now = options.now || (() => new Date());

  async function targetsFor(message) {
    if (message.toType === 'group') {
      return uniqueNumbers(await repository.groupTargetIds(message.toId));
    }
    return uniqueNumbers([message.fromId, message.toId]);
  }

  async function requireActiveMessage(messageId) {
    const message = await repository.findMessageById(messageId);
    if (!message) {
      throw new MessageServiceError('Message not found', 404);
    }
    if (message.deletedAt || ['revoked', 'burned'].includes(message.status)) {
      throw new MessageServiceError('Message is no longer active', 409);
    }
    return message;
  }

  async function isParticipant(message, userId) {
    const actorId = Number(userId);
    if (message.toType === 'user') {
      return message.fromId === actorId || message.toId === actorId;
    }
    return repository.isActiveGroupMember(message.toId, actorId);
  }

  async function requireParticipant(message, userId) {
    if (!(await isParticipant(message, userId))) {
      throw new MessageServiceError('Message access denied', 403);
    }
  }

  async function requireRecipientOrGroupMember(message, userId) {
    const actorId = Number(userId);
    if (message.toType === 'user') {
      if (message.toId !== actorId) {
        throw new MessageServiceError('Message access denied', 403);
      }
      return;
    }

    if (!(await repository.isActiveGroupMember(message.toId, actorId))) {
      throw new MessageServiceError('Message access denied', 403);
    }
  }

async function createMessage(fromId, input) {
    const data = normalizeMessageInput(fromId, input, now);
    if (data.toType === 'group') {
      if (!(await repository.isActiveGroupMember(data.toId, data.fromId))) {
        throw new MessageServiceError('Only active group members can send messages', 403);
      }
    } else if (repository.userExists && !(await repository.userExists(data.toId))) {
      throw new MessageServiceError('Message target not found', 404);
    }

    if (data.toType === 'user' && data.burnAfter === 0) {
      const setting = await repository.getPrivateBurnSetting?.(data.fromId, data.toId);
      if (setting?.enabled) {
        data.burnAfter = setting.burnAfter;
        data.type = 'burn';
      }
    } else if (data.burnAfter > 0) {
      data.type = 'burn';
    }

    const message = await repository.createMessage(data);
    return { message, targets: await targetsFor(message) };
  }

  async function setPrivateBurnSetting(userId, peerId, burnAfter) {
    const actorId = Number(userId);
    const targetId = Number(peerId);
    const seconds = Number(burnAfter ?? 0);
    if (!Number.isInteger(actorId) || !Number.isInteger(targetId) || actorId === targetId) {
      throw new MessageServiceError('Invalid conversation participants', 400);
    }
    if (!VALID_BURN_AFTER.has(seconds)) {
      throw new MessageServiceError('Invalid burnAfter', 400);
    }
    if (repository.userExists && !(await repository.userExists(targetId))) {
      throw new MessageServiceError('Message target not found', 404);
    }
    const setting = await repository.upsertPrivateBurnSetting(actorId, targetId, seconds, now());
    return { setting, targets: setting.peerIds };
  }

  async function getPrivateBurnSetting(userId, peerId) {
    return (await repository.getPrivateBurnSetting(Number(userId), Number(peerId))) || {
      toType: 'user',
      peerIds: sortedPrivatePeerIds(userId, peerId),
      burnAfter: 0,
      enabled: false
    };
  }

  async function markDelivered(messageId, userId) {
    const existing = await requireActiveMessage(messageId);
    await requireRecipientOrGroupMember(existing, userId);
    const message = await repository.markDelivered(messageId);
    if (!message) {
      throw new MessageServiceError('Message not found', 404);
    }
    return { message, targets: await targetsFor(message) };
  }

  async function markRead(messageId, userId) {
    const existing = await requireActiveMessage(messageId);
    await requireRecipientOrGroupMember(existing, userId);
    const message = await repository.markRead(messageId, Number(userId), now());
    if (!message) {
      throw new MessageServiceError('Message not found', 404);
    }
    return { message, targets: await targetsFor(message) };
  }

  async function revokeMessage(messageId, userId) {
    const existing = await requireActiveMessage(messageId);
    if (existing.fromId !== Number(userId)) {
      throw new MessageServiceError('Only sender can revoke message', 403);
    }
    if (now().getTime() - new Date(existing.timestamp).getTime() > REVOKE_WINDOW_MS) {
      throw new MessageServiceError('Message revoke window expired', 409);
    }

    const message = await repository.revokeMessage(messageId);
    return { message, targets: await targetsFor(message) };
  }

  async function startBurn(messageId, userId) {
    const existing = await requireActiveMessage(messageId);
    if (existing.burnAfter <= 0) {
      throw new MessageServiceError('Message does not burn', 400);
    }
    if (existing.toType === 'user' && existing.fromId === Number(userId)) {
      throw new MessageServiceError('Sender cannot start private message burn', 403);
    }
    await requireParticipant(existing, userId);

    await repository.markRead(messageId, Number(userId), now());
    const message = await repository.startBurn(messageId, now());
    return { message, targets: await targetsFor(message) };
  }

  async function expireBurnedMessages() {
    const expired = await repository.findExpiredBurnMessages(now());
    const results = [];
    for (const message of expired) {
      const burned = await repository.markBurned(message.id, now());
      results.push({ message: burned, targets: await targetsFor(burned) });
    }
    return results;
  }

  async function syncMessages(userId) {
    return repository.syncMessagesForUser(Number(userId), new Date(now().getTime() - SYNC_WINDOW_MS));
  }

  return {
    createMessage,
    expireBurnedMessages,
    getPrivateBurnSetting,
    markDelivered,
    markRead,
    revokeMessage,
    setPrivateBurnSetting,
    startBurn,
    syncMessages
  };
}

module.exports = {
  MessageServiceError,
  createMemoryMessageRepository,
  createMessageService,
  createPostgresMessageRepository,
  mapMessage
};
