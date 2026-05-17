const request = require('supertest');
const { createApp } = require('../app');

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
    async updateProfile(id, { displayName }) {
      const user = users.find((candidate) => candidate.id === Number(id) && !candidate.deletedAt);
      if (!user) {
        return null;
      }
      user.displayName = displayName;
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
    },
    async upsertPushToken() {}
  };
}

async function register(app, displayName) {
  const res = await request(app).post('/api/auth/register').send({ displayName });
  expect(res.status).toBe(201);
  return res.body;
}

test('group changes notify all current group members', async () => {
  const notifications = [];
  const app = createApp({
    userRepository: createMemoryUserRepository(),
    notifier: (targets, type, payload) => notifications.push({ targets, type, payload })
  });
  const owner = await register(app, 'Owner');
  const first = await register(app, 'First');
  const second = await register(app, 'Second');

  const res = await request(app)
    .post('/api/groups')
    .set('Authorization', `Bearer ${owner.token}`)
    .send({ name: 'Team', memberIds: [first.user.id, second.user.id] });

  expect(res.status).toBe(201);
  expect(notifications).toEqual([
    expect.objectContaining({
      targets: [owner.user.id, first.user.id, second.user.id],
      type: 'group.updated',
      payload: { group: res.body.group }
    })
  ]);
});

test('new contact creation notifies both sides to refresh contact lists', async () => {
  const notifications = [];
  const app = createApp({
    userRepository: createMemoryUserRepository(),
    notifier: (targets, type, payload) => notifications.push({ targets, type, payload })
  });
  const alice = await register(app, 'Alice');
  const bob = await register(app, 'Bob');

  const res = await request(app)
    .post('/api/contacts')
    .set('Authorization', `Bearer ${alice.token}`)
    .send({ id: bob.user.account });

  expect(res.status).toBe(201);
  expect(notifications).toEqual([
    {
      targets: [alice.user.id, bob.user.id],
      type: 'contact.updated',
      payload: { userId: alice.user.id, contactId: bob.user.id }
    }
  ]);
});
