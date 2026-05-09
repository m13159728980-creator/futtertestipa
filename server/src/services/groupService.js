const crypto = require('crypto');
const db = require('../../database/db');

const CONTACT_NOT_FOUND_MESSAGE = 'Contact account not found';
const CONTACT_SELF_MESSAGE = 'Cannot add yourself as a contact';
const GROUP_MIN_MEMBERS_MESSAGE = 'Group requires at least 2 selected members';
const GROUP_NOT_FOUND_MESSAGE = 'Group not found';
const GROUP_MEMBER_NOT_FOUND_MESSAGE = 'Group member not found';
const GROUP_RENAME_FORBIDDEN_MESSAGE = 'Only owners and admins can rename groups';
const GROUP_MANAGE_FORBIDDEN_MESSAGE = 'Only owners and admins can manage group members';
const GROUP_OWNER_ONLY_MESSAGE = 'Only owners can change member roles';
const GROUP_ADMIN_REMOVE_FORBIDDEN_MESSAGE = 'Admins can only remove members';
const GROUP_ROLE_MESSAGE = 'Role must be owner, admin, or member';

class GroupServiceError extends Error {
  constructor(message, statusCode) {
    super(message);
    this.name = 'GroupServiceError';
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
    avatarIndex: Number(row.avatarIndex ?? row.avatar_index)
  };
}

function serializeContact(user) {
  return mapUser(user);
}

function mapMember(row) {
  return {
    userId: Number(row.userId ?? row.user_id),
    role: row.role,
    account: row.account,
    displayName: row.displayName || row.display_name,
    avatarIndex: Number(row.avatarIndex ?? row.avatar_index)
  };
}

function mapGroup(group) {
  if (!group) {
    return null;
  }

  return {
    id: Number(group.id),
    groupCode: group.groupCode || group.group_code,
    name: group.name,
    ownerId: Number(group.ownerId ?? group.owner_id),
    burnEnabled: Boolean(group.burnEnabled ?? group.burn_enabled ?? false),
    members: (group.members || []).map(mapMember)
  };
}

function uniqueMemberIds(ownerId, memberIds) {
  const owner = Number(ownerId);
  return Array.from(new Set((memberIds || []).map(Number).filter((id) => Number.isInteger(id) && id !== owner)));
}

function normalizeName(name) {
  const normalized = String(name || '').trim();
  if (!normalized || normalized.length > 50) {
    throw new GroupServiceError('Group name is required', 400);
  }
  return normalized;
}

function generateGroupCode() {
  return String(crypto.randomInt(0, 100000000)).padStart(8, '0');
}

function isUniqueViolation(error) {
  return error && error.code === '23505';
}

function createMemoryGroupRepository(userRepository) {
  let nextGroupId = 1;
  const contacts = [];
  const groups = [];
  const members = [];

  async function activeMembers(groupId) {
    const rows = members.filter((member) => member.groupId === Number(groupId) && !member.removedAt);
    return Promise.all(rows.map(async (member) => {
      const user = await userRepository.findActiveById(member.userId);
      return {
        userId: member.userId,
        role: member.role,
        account: user?.account,
        displayName: user?.displayName,
        avatarIndex: user?.avatarIndex
      };
    }));
  }

  async function groupWithMembers(group) {
    if (!group || group.deletedAt) {
      return null;
    }
    return {
      ...group,
      members: await activeMembers(group.id)
    };
  }

  return {
    async findActiveUserByAccount(account) {
      return userRepository.findActiveByAccount(account);
    },
    async findActiveUserById(id) {
      return userRepository.findActiveById(id);
    },
    async addContact(userId, contactId) {
      const existing = contacts.find((contact) => contact.userId === Number(userId) && contact.contactId === Number(contactId));
      if (!existing) {
        contacts.push({ userId: Number(userId), contactId: Number(contactId) });
      }
      return userRepository.findActiveById(contactId);
    },
    async listContacts(userId) {
      const rows = contacts.filter((contact) => contact.userId === Number(userId));
      const users = await Promise.all(rows.map((contact) => userRepository.findActiveById(contact.contactId)));
      return users.filter(Boolean);
    },
    async groupCodeExists(groupCode) {
      return groups.some((group) => group.groupCode === groupCode);
    },
    async createGroup({ groupCode, name, ownerId, memberIds }) {
      const group = {
        id: nextGroupId,
        groupCode,
        name,
        ownerId: Number(ownerId),
        burnEnabled: false,
        deletedAt: null
      };
      nextGroupId += 1;
      groups.push(group);
      members.push({ groupId: group.id, userId: Number(ownerId), role: 'owner', removedAt: null });
      memberIds.forEach((memberId) => {
        members.push({ groupId: group.id, userId: Number(memberId), role: 'member', removedAt: null });
      });
      return groupWithMembers(group);
    },
    async findGroupById(groupId) {
      const group = groups.find((candidate) => candidate.id === Number(groupId) && !candidate.deletedAt);
      return groupWithMembers(group);
    },
    async findActiveMember(groupId, userId) {
      const member = members.find((candidate) =>
        candidate.groupId === Number(groupId) &&
        candidate.userId === Number(userId) &&
        !candidate.removedAt
      );
      return member ? { userId: member.userId, role: member.role } : null;
    },
    async renameGroup(groupId, name) {
      const group = groups.find((candidate) => candidate.id === Number(groupId) && !candidate.deletedAt);
      if (!group) {
        return null;
      }
      group.name = name;
      return groupWithMembers(group);
    },
    async addMembers(groupId, memberIds) {
      memberIds.forEach((memberId) => {
        const existing = members.find((member) => member.groupId === Number(groupId) && member.userId === Number(memberId));
        if (existing) {
          if (existing.removedAt) {
            existing.role = 'member';
          }
          existing.removedAt = null;
        } else {
          members.push({ groupId: Number(groupId), userId: Number(memberId), role: 'member', removedAt: null });
        }
      });
      return this.findGroupById(groupId);
    },
    async removeMember(groupId, userId) {
      const member = members.find((candidate) =>
        candidate.groupId === Number(groupId) &&
        candidate.userId === Number(userId) &&
        !candidate.removedAt
      );
      if (!member) {
        return false;
      }
      member.removedAt = new Date();
      return true;
    },
    async setMemberRole(groupId, userId, role) {
      const member = members.find((candidate) =>
        candidate.groupId === Number(groupId) &&
        candidate.userId === Number(userId) &&
        !candidate.removedAt
      );
      if (!member) {
        return null;
      }
      member.role = role;
      return this.findGroupById(groupId);
    }
  };
}

function createPostgresGroupRepository(query = db.query, transaction = db.transaction) {
  async function hydrateGroup(group) {
    if (!group) {
      return null;
    }

    const { rows } = await query(
      `
        SELECT gm.user_id, gm.role, u.account, u.display_name, u.avatar_index
        FROM group_members gm
        JOIN users u ON u.id = gm.user_id AND u.deleted_at IS NULL
        WHERE gm.group_id = $1
          AND gm.removed_at IS NULL
        ORDER BY gm.joined_at ASC, gm.user_id ASC
      `,
      [group.id]
    );

    return {
      id: Number(group.id),
      groupCode: group.group_code,
      name: group.name,
      ownerId: Number(group.owner_id),
      burnEnabled: Boolean(group.burn_enabled),
      members: rows.map(mapMember)
    };
  }

  return {
    async findActiveUserByAccount(account) {
      const { rows } = await query(
        `
          SELECT id, account, display_name, avatar_index
          FROM users
          WHERE account = $1
            AND deleted_at IS NULL
          LIMIT 1
        `,
        [account]
      );
      return mapUser(rows[0]);
    },
    async findActiveUserById(id) {
      const { rows } = await query(
        `
          SELECT id, account, display_name, avatar_index
          FROM users
          WHERE id = $1
            AND deleted_at IS NULL
          LIMIT 1
        `,
        [id]
      );
      return mapUser(rows[0]);
    },
    async addContact(userId, contactId) {
      await query(
        `
          INSERT INTO contacts (user_id, contact_id)
          VALUES ($1, $2)
          ON CONFLICT (user_id, contact_id) DO NOTHING
        `,
        [userId, contactId]
      );
      return this.findActiveUserById(contactId);
    },
    async listContacts(userId) {
      const { rows } = await query(
        `
          SELECT u.id, u.account, u.display_name, u.avatar_index
          FROM contacts c
          JOIN users u ON u.id = c.contact_id AND u.deleted_at IS NULL
          WHERE c.user_id = $1
          ORDER BY c.created_at ASC, u.id ASC
        `,
        [userId]
      );
      return rows.map(mapUser);
    },
    async groupCodeExists(groupCode) {
      const { rows } = await query('SELECT 1 FROM groups WHERE group_code = $1 LIMIT 1', [groupCode]);
      return rows.length > 0;
    },
    async createGroup({ groupCode, name, ownerId, memberIds }) {
      const group = await transaction(async (client) => {
        const groupResult = await client.query(
          `
            INSERT INTO groups (group_code, name, owner_id)
            VALUES ($1, $2, $3)
            RETURNING id, group_code, name, owner_id, burn_enabled
          `,
          [groupCode, name, ownerId]
        );
        const created = groupResult.rows[0];
        const entries = [
          { userId: ownerId, role: 'owner' },
          ...memberIds.map((memberId) => ({ userId: memberId, role: 'member' }))
        ];
        await Promise.all(entries.map((entry) =>
          client.query(
            `
              INSERT INTO group_members (group_id, user_id, role)
              VALUES ($1, $2, $3)
            `,
            [created.id, entry.userId, entry.role]
          )
        ));
        return created;
      });

      return hydrateGroup(group);
    },
    async findGroupById(groupId) {
      const { rows } = await query(
        `
          SELECT id, group_code, name, owner_id, burn_enabled
          FROM groups
          WHERE id = $1
            AND deleted_at IS NULL
          LIMIT 1
        `,
        [groupId]
      );
      return hydrateGroup(rows[0]);
    },
    async findActiveMember(groupId, userId) {
      const { rows } = await query(
        `
          SELECT user_id, role
          FROM group_members
          WHERE group_id = $1
            AND user_id = $2
            AND removed_at IS NULL
          LIMIT 1
        `,
        [groupId, userId]
      );
      return rows[0] ? { userId: Number(rows[0].user_id), role: rows[0].role } : null;
    },
    async renameGroup(groupId, name) {
      const { rows } = await query(
        `
          UPDATE groups
          SET name = $2
          WHERE id = $1
            AND deleted_at IS NULL
          RETURNING id, group_code, name, owner_id, burn_enabled
        `,
        [groupId, name]
      );
      return hydrateGroup(rows[0]);
    },
    async addMembers(groupId, memberIds) {
      await transaction(async (client) => {
        await Promise.all(memberIds.map((memberId) =>
          client.query(
            `
              INSERT INTO group_members (group_id, user_id, role, removed_at)
              VALUES ($1, $2, 'member', NULL)
              ON CONFLICT (group_id, user_id) DO UPDATE
              SET role = CASE
                    WHEN group_members.removed_at IS NOT NULL THEN 'member'
                    ELSE group_members.role
                  END,
                  removed_at = NULL
            `,
            [groupId, memberId]
          )
        ));
      });
      return this.findGroupById(groupId);
    },
    async removeMember(groupId, userId) {
      const { rowCount } = await query(
        `
          UPDATE group_members
          SET removed_at = NOW()
          WHERE group_id = $1
            AND user_id = $2
            AND removed_at IS NULL
        `,
        [groupId, userId]
      );
      return rowCount > 0;
    },
    async setMemberRole(groupId, userId, role) {
      const { rowCount } = await query(
        `
          UPDATE group_members
          SET role = $3
          WHERE group_id = $1
            AND user_id = $2
            AND removed_at IS NULL
        `,
        [groupId, userId, role]
      );
      if (rowCount === 0) {
        return null;
      }
      return this.findGroupById(groupId);
    }
  };
}

function createGroupService(options = {}) {
  const repository = options.groupRepository ||
    (options.repository) ||
    (options.userRepository && !process.env.TEST_DATABASE_URL
      ? createMemoryGroupRepository(options.userRepository)
      : createPostgresGroupRepository(options.query, options.transaction));
  const groupCodeGenerator = options.groupCodeGenerator || generateGroupCode;

  async function addContact(userId, account) {
    const contact = await repository.findActiveUserByAccount(account);
    if (!contact) {
      throw new GroupServiceError(CONTACT_NOT_FOUND_MESSAGE, 404);
    }
    if (Number(contact.id) === Number(userId)) {
      throw new GroupServiceError(CONTACT_SELF_MESSAGE, 400);
    }
    return serializeContact(await repository.addContact(userId, contact.id));
  }

  async function listContacts(userId) {
    const contacts = await repository.listContacts(userId);
    return contacts.map(serializeContact);
  }

  async function createGroup(userId, { name, memberIds }) {
    const selectedIds = uniqueMemberIds(userId, memberIds);
    if (selectedIds.length < 2) {
      throw new GroupServiceError(GROUP_MIN_MEMBERS_MESSAGE, 400);
    }

    const activeUsers = await Promise.all(selectedIds.map((id) => repository.findActiveUserById(id)));
    if (activeUsers.some((user) => !user)) {
      throw new GroupServiceError(GROUP_MEMBER_NOT_FOUND_MESSAGE, 404);
    }

    for (let attempt = 0; attempt < 10; attempt += 1) {
      const groupCode = groupCodeGenerator();
      if (await repository.groupCodeExists(groupCode)) {
        continue;
      }

      try {
        return mapGroup(await repository.createGroup({
          groupCode,
          name: normalizeName(name),
          ownerId: Number(userId),
          memberIds: selectedIds
        }));
      } catch (error) {
        if (isUniqueViolation(error)) {
          continue;
        }
        throw error;
      }
    }

    throw new GroupServiceError('Could not generate group code', 500);
  }

  async function getGroup(userId, groupId) {
    const group = mapGroup(await repository.findGroupById(groupId));
    if (!group) {
      throw new GroupServiceError(GROUP_NOT_FOUND_MESSAGE, 404);
    }
    const actor = await repository.findActiveMember(groupId, userId);
    if (!actor) {
      throw new GroupServiceError(GROUP_NOT_FOUND_MESSAGE, 404);
    }
    return group;
  }

  async function renameGroup(userId, groupId, name) {
    const actor = await requireMember(groupId, userId);
    if (!['owner', 'admin'].includes(actor.role)) {
      throw new GroupServiceError(GROUP_RENAME_FORBIDDEN_MESSAGE, 403);
    }
    return mapGroup(await repository.renameGroup(groupId, normalizeName(name)));
  }

  async function addMembers(userId, groupId, memberIds) {
    const actor = await requireMember(groupId, userId);
    if (!['owner', 'admin'].includes(actor.role)) {
      throw new GroupServiceError(GROUP_MANAGE_FORBIDDEN_MESSAGE, 403);
    }
    const selectedIds = uniqueMemberIds(userId, memberIds);
    const activeUsers = await Promise.all(selectedIds.map((id) => repository.findActiveUserById(id)));
    if (activeUsers.some((user) => !user)) {
      throw new GroupServiceError(GROUP_MEMBER_NOT_FOUND_MESSAGE, 404);
    }
    return mapGroup(await repository.addMembers(groupId, selectedIds));
  }

  async function removeMember(userId, groupId, targetUserId) {
    const actor = await requireMember(groupId, userId);
    const target = await requireMember(groupId, targetUserId);
    if (!['owner', 'admin'].includes(actor.role)) {
      throw new GroupServiceError(GROUP_MANAGE_FORBIDDEN_MESSAGE, 403);
    }
    if (actor.role === 'admin' && target.role !== 'member') {
      throw new GroupServiceError(GROUP_ADMIN_REMOVE_FORBIDDEN_MESSAGE, 403);
    }
    if (actor.role === 'owner' && target.role === 'owner') {
      throw new GroupServiceError(GROUP_ADMIN_REMOVE_FORBIDDEN_MESSAGE, 403);
    }
    await repository.removeMember(groupId, targetUserId);
  }

  async function setMemberRole(userId, groupId, targetUserId, role) {
    if (!['owner', 'admin', 'member'].includes(role)) {
      throw new GroupServiceError(GROUP_ROLE_MESSAGE, 400);
    }
    const actor = await requireMember(groupId, userId);
    if (actor.role !== 'owner') {
      throw new GroupServiceError(GROUP_OWNER_ONLY_MESSAGE, 403);
    }
    const target = await requireMember(groupId, targetUserId);
    if (target.role === 'owner') {
      throw new GroupServiceError(GROUP_OWNER_ONLY_MESSAGE, 403);
    }
    return mapGroup(await repository.setMemberRole(groupId, targetUserId, role));
  }

  async function requireMember(groupId, userId) {
    const group = await repository.findGroupById(groupId);
    if (!group) {
      throw new GroupServiceError(GROUP_NOT_FOUND_MESSAGE, 404);
    }
    const member = await repository.findActiveMember(groupId, userId);
    if (!member) {
      throw new GroupServiceError(GROUP_MEMBER_NOT_FOUND_MESSAGE, 404);
    }
    return member;
  }

  return {
    addContact,
    addMembers,
    createGroup,
    getGroup,
    listContacts,
    removeMember,
    renameGroup,
    setMemberRole
  };
}

module.exports = {
  CONTACT_NOT_FOUND_MESSAGE,
  CONTACT_SELF_MESSAGE,
  GROUP_ADMIN_REMOVE_FORBIDDEN_MESSAGE,
  GROUP_MANAGE_FORBIDDEN_MESSAGE,
  GROUP_MEMBER_NOT_FOUND_MESSAGE,
  GROUP_MIN_MEMBERS_MESSAGE,
  GROUP_NOT_FOUND_MESSAGE,
  GROUP_OWNER_ONLY_MESSAGE,
  GROUP_RENAME_FORBIDDEN_MESSAGE,
  GROUP_ROLE_MESSAGE,
  GroupServiceError,
  createGroupService,
  createMemoryGroupRepository,
  createPostgresGroupRepository,
  generateGroupCode
};
