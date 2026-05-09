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

function createTestApp() {
  return createApp({ userRepository: createMemoryUserRepository() });
}

async function register(app, account, displayName = account.slice(1)) {
  const res = await request(app)
    .post('/api/auth/register')
    .send({ account, displayName });

  expect(res.status).toBe(201);
  return res.body;
}

async function createGroup(app, ownerToken, memberIds, name = 'Friends') {
  const res = await request(app)
    .post('/api/groups')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ name, memberIds });

  expect(res.status).toBe(201);
  return res.body.group;
}

test('POST /api/contacts adds a contact by account', async () => {
  const app = createTestApp();
  const owner = await register(app, '@OWNER', 'Owner');
  const friend = await register(app, '@FRIEND', 'Friend');

  const addRes = await request(app)
    .post('/api/contacts')
    .set('Authorization', `Bearer ${owner.token}`)
    .send({ account: '@FRIEND' });

  expect(addRes.status).toBe(201);
  expect(addRes.body).toEqual({
    contact: {
      id: friend.user.id,
      account: '@FRIEND',
      displayName: 'Friend',
      avatarIndex: friend.user.avatarIndex
    }
  });

  const duplicateRes = await request(app)
    .post('/api/contacts')
    .set('Authorization', `Bearer ${owner.token}`)
    .send({ account: '@FRIEND' });

  expect(duplicateRes.status).toBe(200);

  const listRes = await request(app)
    .get('/api/contacts')
    .set('Authorization', `Bearer ${owner.token}`);

  expect(listRes.status).toBe(200);
  expect(listRes.body.contacts).toEqual([addRes.body.contact]);
});

test('POST /api/groups requires at least 2 selected member user IDs in addition to the owner', async () => {
  const app = createTestApp();
  const owner = await register(app, '@OWNER', 'Owner');
  const member = await register(app, '@MEMBER', 'Member');

  const res = await request(app)
    .post('/api/groups')
    .set('Authorization', `Bearer ${owner.token}`)
    .send({ name: 'Too Small', memberIds: [member.user.id] });

  expect(res.status).toBe(400);
  expect(res.body).toEqual({ message: 'Group requires at least 2 selected members' });
});

test('POST /api/groups returns a generated groupCode with exactly 8 digits', async () => {
  const app = createTestApp();
  const owner = await register(app, '@OWNER', 'Owner');
  const first = await register(app, '@FIRST', 'First');
  const second = await register(app, '@SECOND', 'Second');

  const group = await createGroup(app, owner.token, [first.user.id, second.user.id]);

  expect(group.groupCode).toEqual(expect.stringMatching(/^\d{8}$/));
  expect(group.members).toEqual(expect.arrayContaining([
    expect.objectContaining({ userId: owner.user.id, role: 'owner' }),
    expect.objectContaining({ userId: first.user.id, role: 'member' }),
    expect.objectContaining({ userId: second.user.id, role: 'member' })
  ]));
});

test('PATCH /api/groups/:id allows the owner to rename a group', async () => {
  const app = createTestApp();
  const owner = await register(app, '@OWNER', 'Owner');
  const first = await register(app, '@FIRST', 'First');
  const second = await register(app, '@SECOND', 'Second');
  const group = await createGroup(app, owner.token, [first.user.id, second.user.id]);

  const res = await request(app)
    .patch(`/api/groups/${group.id}`)
    .set('Authorization', `Bearer ${owner.token}`)
    .send({ name: 'Renamed' });

  expect(res.status).toBe(200);
  expect(res.body.group.name).toBe('Renamed');
});

test('admins can rename groups and remove members', async () => {
  const app = createTestApp();
  const owner = await register(app, '@OWNER', 'Owner');
  const admin = await register(app, '@ADMIN', 'Admin');
  const member = await register(app, '@MEMBER', 'Member');
  const group = await createGroup(app, owner.token, [admin.user.id, member.user.id]);

  const adminRes = await request(app)
    .patch(`/api/groups/${group.id}/members/${admin.user.id}/role`)
    .set('Authorization', `Bearer ${owner.token}`)
    .send({ role: 'admin' });
  expect(adminRes.status).toBe(200);

  const renameRes = await request(app)
    .patch(`/api/groups/${group.id}`)
    .set('Authorization', `Bearer ${admin.token}`)
    .send({ name: 'Admin Renamed' });

  expect(renameRes.status).toBe(200);
  expect(renameRes.body.group.name).toBe('Admin Renamed');

  const removeRes = await request(app)
    .delete(`/api/groups/${group.id}/members/${member.user.id}`)
    .set('Authorization', `Bearer ${admin.token}`);

  expect(removeRes.status).toBe(204);

  const getRes = await request(app)
    .get(`/api/groups/${group.id}`)
    .set('Authorization', `Bearer ${owner.token}`);

  expect(getRes.status).toBe(200);
  expect(getRes.body.group.members).not.toEqual(expect.arrayContaining([
    expect.objectContaining({ userId: member.user.id })
  ]));
});

test('members cannot remove another member', async () => {
  const app = createTestApp();
  const owner = await register(app, '@OWNER', 'Owner');
  const first = await register(app, '@FIRST', 'First');
  const second = await register(app, '@SECOND', 'Second');
  const group = await createGroup(app, owner.token, [first.user.id, second.user.id]);

  const res = await request(app)
    .delete(`/api/groups/${group.id}/members/${second.user.id}`)
    .set('Authorization', `Bearer ${first.token}`);

  expect(res.status).toBe(403);
  expect(res.body).toEqual({ message: 'Only owners and admins can manage group members' });
});

test('owners can set a member as admin', async () => {
  const app = createTestApp();
  const owner = await register(app, '@OWNER', 'Owner');
  const first = await register(app, '@FIRST', 'First');
  const second = await register(app, '@SECOND', 'Second');
  const group = await createGroup(app, owner.token, [first.user.id, second.user.id]);

  const res = await request(app)
    .patch(`/api/groups/${group.id}/members/${first.user.id}/role`)
    .set('Authorization', `Bearer ${owner.token}`)
    .send({ role: 'admin' });

  expect(res.status).toBe(200);
  expect(res.body.group.members).toEqual(expect.arrayContaining([
    expect.objectContaining({ userId: first.user.id, role: 'admin' })
  ]));
});
