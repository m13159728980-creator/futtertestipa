const request = require('supertest');
const { createApp } = require('../app');
const {
  MessageServiceError,
  createMemoryMessageRepository,
  createMessageService
} = require('../src/services/messageService');

function createMemoryUserRepository() {
  let nextId = 1;
  const users = [];

  return {
    async findByAccount(account) {
      return users.find((user) => user.account === account) || null;
    },
    async findActiveByAccount(account) {
      return users.find((user) => user.account === account && !user.deletedAt) || null;
    },
    async findActiveById(id) {
      return users.find((user) => user.id === Number(id) && !user.deletedAt) || null;
    },
    async create({ account, displayName, avatarIndex }) {
      const user = {
        id: nextId,
        account,
        displayName,
        avatarIndex,
        tokenVersion: 0,
        deletedAt: null
      };
      nextId += 1;
      users.push(user);
      return user;
    },
    async updateAvatar(id, avatarIndex) {
      const user = users.find((candidate) => candidate.id === Number(id) && !candidate.deletedAt);
      if (!user) {
        return null;
      }
      user.avatarIndex = avatarIndex;
      return user;
    },
    async softDelete(id) {
      const user = users.find((candidate) => candidate.id === Number(id) && !candidate.deletedAt);
      if (!user) {
        return null;
      }
      user.deletedAt = new Date();
      user.tokenVersion += 1;
      return user;
    }
  };
}

async function register(app, account, displayName = account.slice(1)) {
  const res = await request(app)
    .post('/api/auth/register')
    .send({ account, displayName });

  expect(res.status).toBe(201);
  return res.body;
}

function createService(now = () => new Date('2026-05-10T00:00:00.000Z')) {
  const repository = createMemoryMessageRepository();
  return {
    repository,
    service: createMessageService({ messageRepository: repository, now })
  };
}

test('persists a private text message', async () => {
  const { repository, service } = createService();

  const result = await service.createMessage(1, {
    toId: 2,
    toType: 'user',
    type: 'text',
    content: 'hello',
    burnAfter: 0
  });

  expect(result.message).toMatchObject({
    id: expect.any(String),
    fromId: 1,
    toId: 2,
    toType: 'user',
    type: 'text',
    content: 'hello',
    burnAfter: 0,
    status: 'sent',
    timestamp: '2026-05-10T00:00:00.000Z'
  });
  await expect(repository.findMessageById(result.message.id)).resolves.toEqual(result.message);
  expect(result.targets).toEqual([1, 2]);
});

test('persists client supplied message id so websocket echo replaces local draft', async () => {
  const { repository, service } = createService();

  const result = await service.createMessage(1, {
    id: '11111111-1111-4111-8111-111111111111',
    toId: 2,
    toType: 'user',
    type: 'text',
    content: 'hello',
    burnAfter: 0
  });

  expect(result.message.id).toBe('11111111-1111-4111-8111-111111111111');
  await expect(repository.findMessageById('11111111-1111-4111-8111-111111111111')).resolves.toEqual(result.message);
});

test('group message fan-out target list includes active members', async () => {
  const { repository, service } = createService();
  repository.setGroupMembers(10, [
    { userId: 1 },
    { userId: 2 },
    { userId: 3 },
    { userId: 4, removedAt: new Date('2026-05-09T00:00:00.000Z') }
  ]);

  const result = await service.createMessage(1, {
    toId: 10,
    toType: 'group',
    type: 'text',
    content: 'team'
  });

  expect(result.targets).toEqual([1, 2, 3]);
});

test('group send requires sender to be an active group member', async () => {
  const { repository, service } = createService();
  repository.setGroupMembers(10, [
    { userId: 2 },
    { userId: 3 }
  ]);

  await expect(service.createMessage(1, {
    toId: 10,
    toType: 'group',
    type: 'text',
    content: 'outsider'
  })).rejects.toMatchObject({
    name: 'MessageServiceError',
    statusCode: 403
  });
});

test('read receipt creates message_reads', async () => {
  const { repository, service } = createService();
  const { message } = await service.createMessage(1, {
    toId: 2,
    toType: 'user',
    type: 'text',
    content: 'read me'
  });

  const result = await service.markRead(message.id, 2);

  expect(result.message.status).toBe('read');
  await expect(repository.listReads(message.id)).resolves.toEqual([
    { messageId: message.id, userId: 2, readAt: '2026-05-10T00:00:00.000Z' }
  ]);
});

test('unrelated users cannot mark private messages delivered or read', async () => {
  const { service } = createService();
  const { message } = await service.createMessage(1, {
    toId: 2,
    toType: 'user',
    type: 'text',
    content: 'private'
  });

  await expect(service.markDelivered(message.id, 3)).rejects.toMatchObject({ statusCode: 403 });
  await expect(service.markRead(message.id, 3)).rejects.toMatchObject({ statusCode: 403 });
});

test('sender cannot mark their own private message delivered', async () => {
  const { service } = createService();
  const { message } = await service.createMessage(1, {
    toId: 2,
    toType: 'user',
    type: 'text',
    content: 'receipt'
  });

  await expect(service.markDelivered(message.id, 1)).rejects.toMatchObject({
    name: 'MessageServiceError',
    statusCode: 403
  });
});

test('sender cannot mark their own private message read', async () => {
  const { service } = createService();
  const { message } = await service.createMessage(1, {
    toId: 2,
    toType: 'user',
    type: 'text',
    content: 'receipt'
  });

  await expect(service.markRead(message.id, 1)).rejects.toMatchObject({
    name: 'MessageServiceError',
    statusCode: 403
  });
});

test('private recipient can mark delivered and read', async () => {
  const { service } = createService();
  const delivered = await service.createMessage(1, {
    toId: 2,
    toType: 'user',
    type: 'text',
    content: 'delivered'
  });
  const read = await service.createMessage(1, {
    toId: 2,
    toType: 'user',
    type: 'text',
    content: 'read'
  });

  await expect(service.markDelivered(delivered.message.id, 2)).resolves.toMatchObject({
    message: expect.objectContaining({ status: 'delivered' })
  });
  await expect(service.markRead(read.message.id, 2)).resolves.toMatchObject({
    message: expect.objectContaining({ status: 'read' })
  });
});

test('unrelated users cannot read group messages', async () => {
  const { repository, service } = createService();
  repository.setGroupMembers(10, [
    { userId: 1 },
    { userId: 2 }
  ]);
  const { message } = await service.createMessage(1, {
    toId: 10,
    toType: 'group',
    type: 'text',
    content: 'group'
  });

  await expect(service.markRead(message.id, 3)).rejects.toMatchObject({ statusCode: 403 });
});

test('revoke succeeds within 5 minutes and fails after 5 minutes', async () => {
  let current = new Date('2026-05-10T00:00:00.000Z');
  const { service } = createService(() => current);
  const within = await service.createMessage(1, {
    toId: 2,
    toType: 'user',
    type: 'text',
    content: 'undo'
  });

  current = new Date('2026-05-10T00:04:59.000Z');
  const revoked = await service.revokeMessage(within.message.id, 1);
  expect(revoked.message).toMatchObject({ status: 'revoked', content: null });

  current = new Date('2026-05-10T00:00:00.000Z');
  const late = await service.createMessage(1, {
    toId: 2,
    toType: 'user',
    type: 'text',
    content: 'too late'
  });

  current = new Date('2026-05-10T00:05:01.000Z');
  await expect(service.revokeMessage(late.message.id, 1)).rejects.toMatchObject({
    name: 'MessageServiceError',
    statusCode: 409
  });
});

test('revoke rejects terminal messages', async () => {
  const { service } = createService();
  const { message } = await service.createMessage(1, {
    toId: 2,
    toType: 'user',
    type: 'text',
    content: 'terminal'
  });

  await service.revokeMessage(message.id, 1);

  await expect(service.revokeMessage(message.id, 1)).rejects.toMatchObject({
    name: 'MessageServiceError',
    statusCode: 409
  });
});

test('burn start records burn_started_at once', async () => {
  let current = new Date('2026-05-10T00:00:00.000Z');
  const { service } = createService(() => current);
  const { message } = await service.createMessage(1, {
    toId: 2,
    toType: 'user',
    type: 'text',
    content: 'burn',
    burnAfter: 10
  });

  const first = await service.startBurn(message.id, 2);
  current = new Date('2026-05-10T00:00:03.000Z');
  const second = await service.startBurn(message.id, 2);

  expect(first.message.burnStartedAt).toBe('2026-05-10T00:00:00.000Z');
  expect(second.message.burnStartedAt).toBe('2026-05-10T00:00:00.000Z');
});

test('burn start requires an authorized reader and rejects terminal messages', async () => {
  const { service } = createService();
  const { message } = await service.createMessage(1, {
    toId: 2,
    toType: 'user',
    type: 'text',
    content: 'burn',
    burnAfter: 10
  });

  await expect(service.startBurn(message.id, 1)).rejects.toMatchObject({ statusCode: 403 });
  await expect(service.startBurn(message.id, 3)).rejects.toMatchObject({ statusCode: 403 });

  await service.revokeMessage(message.id, 1);
  await expect(service.startBurn(message.id, 2)).rejects.toMatchObject({ statusCode: 409 });
});

test('sync returns messages from the last 7 days only', async () => {
  let current = new Date('2026-05-10T12:00:00.000Z');
  const { service } = createService(() => current);

  current = new Date('2026-05-02T11:59:59.000Z');
  await service.createMessage(1, { toId: 2, toType: 'user', type: 'text', content: 'old' });
  current = new Date('2026-05-03T12:00:00.000Z');
  const boundary = await service.createMessage(2, { toId: 1, toType: 'user', type: 'text', content: 'boundary' });
  current = new Date('2026-05-10T00:00:00.000Z');
  const recent = await service.createMessage(1, { toId: 2, toType: 'user', type: 'text', content: 'recent' });
  current = new Date('2026-05-10T12:00:00.000Z');

  const messages = await service.syncMessages(1);

  expect(messages.map((message) => message.id)).toEqual([recent.message.id, boundary.message.id]);
});

test('POST /api/messages/sync is authenticated and returns relevant messages', async () => {
  const userRepository = createMemoryUserRepository();
  const messageRepository = createMemoryMessageRepository();
  let current = new Date('2026-05-10T12:00:00.000Z');
  const app = createApp({
    userRepository,
    messageRepository,
    now: () => current
  });
  const alice = await register(app, '@ALICE', 'Alice');
  const bob = await register(app, '@BOB', 'Bob');

  current = new Date('2026-05-10T00:00:00.000Z');
  const messageService = createMessageService({ messageRepository, now: () => current });
  await messageService.createMessage(alice.user.id, {
    toId: bob.user.id,
    toType: 'user',
    type: 'text',
    content: 'offline'
  });

  const unauthorized = await request(app).post('/api/messages/sync').send({});
  expect(unauthorized.status).toBe(401);

  const res = await request(app)
    .post('/api/messages/sync')
    .set('Authorization', `Bearer ${bob.token}`)
    .send({});

  expect(res.status).toBe(200);
  expect(res.body.messages).toEqual([
    expect.objectContaining({
      fromId: alice.user.id,
      toId: bob.user.id,
      content: 'offline'
    })
  ]);
});

test('burn expire marks expired burn messages', async () => {
  let current = new Date('2026-05-10T00:00:00.000Z');
  const { service } = createService(() => current);
  const { message } = await service.createMessage(1, {
    toId: 2,
    toType: 'user',
    type: 'text',
    content: 'gone soon',
    burnAfter: 5
  });
  await service.startBurn(message.id, 2);

  current = new Date('2026-05-10T00:00:06.000Z');
  const expired = await service.expireBurnedMessages();

  expect(expired).toHaveLength(1);
  expect(expired[0].message).toMatchObject({
    id: message.id,
    status: 'burned',
    deletedAt: '2026-05-10T00:00:06.000Z'
  });
});

test('burn expire ignores revoked messages', async () => {
  let current = new Date('2026-05-10T00:00:00.000Z');
  const { service } = createService(() => current);
  const { message } = await service.createMessage(1, {
    toId: 2,
    toType: 'user',
    type: 'text',
    content: 'revoked burn',
    burnAfter: 5
  });
  await service.startBurn(message.id, 2);
  await service.revokeMessage(message.id, 1);

  current = new Date('2026-05-10T00:00:06.000Z');
  await expect(service.expireBurnedMessages()).resolves.toEqual([]);
});

test('startBurn rejects messages without burnAfter', async () => {
  const { service } = createService();
  const { message } = await service.createMessage(1, {
    toId: 2,
    toType: 'user',
    type: 'text',
    content: 'plain'
  });

  await expect(service.startBurn(message.id, 2)).rejects.toBeInstanceOf(MessageServiceError);
});
