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
      const existing = users.find((user) => user.account === account);
      if (existing) {
        const error = new Error('duplicate');
        error.code = '23505';
        throw error;
      }
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
      user.deletion = {
        requestedAt: new Date(),
        purgeAfter: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
      };
      return user;
    }
  };
}

function createTestApp(options = {}) {
  return createApp({
    userRepository: createMemoryUserRepository(),
    ...options
  });
}

async function register(app, displayName = 'ZCMX') {
  const res = await request(app)
    .post('/api/auth/register')
    .send({ displayName });
  expect(res.status).toBe(201);
  return res.body;
}

test('GET /api/users/check-account returns available for unused 10 digit ID', async () => {
  const app = createTestApp();

  const res = await request(app).get('/api/users/check-account').query({ account: '1000000001' });

  expect(res.status).toBe(200);
  expect(res.body).toEqual({ available: true });
});

test('GET /api/users/check-account rejects non 10 digit ID', async () => {
  const app = createTestApp();

  const res = await request(app).get('/api/users/check-account').query({ account: '@ZCMX' });

  expect(res.status).toBe(400);
  expect(res.body).toEqual({ message: '请输入10位数字ID' });
});

test('POST /api/auth/register rejects blank displayName/name', async () => {
  const app = createTestApp();

  const res = await request(app)
    .post('/api/auth/register')
    .send({ displayName: '   ', name: '' });

  expect(res.status).toBe(400);
  expect(res.body).toEqual({ message: '请输入名字' });
});

test('POST /api/auth/register creates user with generated 10 digit ID and token', async () => {
  const app = createTestApp();

  const res = await request(app)
    .post('/api/auth/register')
    .send({ displayName: 'ZCMX' });

  expect(res.status).toBe(201);
  expect(res.body).toEqual({
    user: {
      id: expect.any(Number),
      account: expect.stringMatching(/^\d{10}$/),
      displayName: 'ZCMX',
      avatarIndex: expect.any(Number)
    },
    token: expect.any(String)
  });
  expect(res.body.user.avatarIndex).toBeGreaterThanOrEqual(0);
  expect(res.body.user.avatarIndex).toBeLessThanOrEqual(8);
});

test('POST /api/auth/register ignores submitted username and generates a 10 digit ID', async () => {
  const app = createTestApp();

  const res = await request(app)
    .post('/api/auth/register')
    .send({ account: '@SHOULDIGNORE', displayName: 'No Username' });

  expect(res.status).toBe(201);
  expect(res.body.user.account).toMatch(/^\d{10}$/);
  expect(res.body.user.account).not.toBe('@SHOULDIGNORE');
});

test('POST /api/auth/register retries generated ID collisions', async () => {
  const ids = ['1000000001', '1000000001', '1000000002'];
  const app = createTestApp({ publicIdGenerator: () => ids.shift() });

  const first = await register(app, 'First');
  const second = await register(app, 'Second');

  expect(first.user.account).toBe('1000000001');
  expect(second.user.account).toBe('1000000002');
});

test('POST /api/auth/validate accepts a valid token', async () => {
  const app = createTestApp();
  const registerRes = await register(app);

  const res = await request(app)
    .post('/api/auth/validate')
    .set('Authorization', `Bearer ${registerRes.token}`)
    .send();

  expect(res.status).toBe(200);
  expect(res.body).toEqual({
    user: {
      id: registerRes.user.id,
      account: registerRes.user.account,
      displayName: 'ZCMX',
      avatarIndex: registerRes.user.avatarIndex
    }
  });
});

test('GET /api/users/check-account returns available after ID is soft-deleted', async () => {
  const app = createTestApp();
  const registerRes = await register(app);

  await request(app)
    .delete('/api/users/me')
    .set('Authorization', `Bearer ${registerRes.token}`)
    .send({ account: registerRes.user.account });

  const res = await request(app).get('/api/users/check-account').query({ account: registerRes.user.account });

  expect(res.status).toBe(200);
  expect(res.body).toEqual({ available: true });
});

test('POST /api/auth/validate rejects token after user is deleted', async () => {
  const app = createTestApp();
  const registerRes = await register(app);

  await request(app)
    .delete('/api/users/me')
    .set('Authorization', `Bearer ${registerRes.token}`)
    .send({ account: registerRes.user.account });

  const res = await request(app)
    .post('/api/auth/validate')
    .set('Authorization', `Bearer ${registerRes.token}`)
    .send();

  expect(res.status).toBe(401);
  expect(res.body).toEqual({ message: '登录已失效' });
});

test('PATCH /api/users/me/avatar rejects old token after tokenVersion changes', async () => {
  const repository = createMemoryUserRepository();
  const app = createApp({ userRepository: repository });
  const registerRes = await register(app);
  const user = await repository.findActiveById(registerRes.user.id);
  user.tokenVersion += 1;

  const res = await request(app)
    .patch('/api/users/me/avatar')
    .set('Authorization', `Bearer ${registerRes.token}`)
    .send({ avatarIndex: 3 });

  expect(res.status).toBe(401);
  expect(res.body).toEqual({ message: '登录已失效' });
});

test('PATCH /api/users/me/profile updates the current user displayName', async () => {
  const app = createTestApp();
  const registered = await register(app, 'Old Name');

  const res = await request(app)
    .patch('/api/users/me/profile')
    .set('Authorization', `Bearer ${registered.token}`)
    .send({ displayName: 'New Name' });

  expect(res.status).toBe(200);
  expect(res.body.user).toEqual(expect.objectContaining({
    id: registered.user.id,
    account: registered.user.account,
    displayName: 'New Name'
  }));
});

test('PATCH /api/users/me/profile rejects blank displayName', async () => {
  const app = createTestApp();
  const registered = await register(app, 'Old Name');

  const res = await request(app)
    .patch('/api/users/me/profile')
    .set('Authorization', `Bearer ${registered.token}`)
    .send({ displayName: '   ' });

  expect(res.status).toBe(400);
  expect(res.body).toEqual({ message: '请输入名字' });
});

test('DELETE /api/users/me rejects missing confirmation', async () => {
  const app = createTestApp();
  const registerRes = await register(app);

  const res = await request(app)
    .delete('/api/users/me')
    .set('Authorization', `Bearer ${registerRes.token}`)
    .send();

  expect(res.status).toBe(400);
  expect(res.body).toEqual({ message: '请输入正确ID确认注销' });
});

test('DELETE /api/users/me rejects request with no body', async () => {
  const app = createTestApp();
  const registerRes = await register(app);

  const res = await request(app)
    .delete('/api/users/me')
    .set('Authorization', `Bearer ${registerRes.token}`);

  expect(res.status).toBe(400);
  expect(res.body).toEqual({ message: '请输入正确ID确认注销' });
});

test('DELETE /api/users/me rejects wrong confirmation', async () => {
  const app = createTestApp();
  const registerRes = await register(app);

  const res = await request(app)
    .delete('/api/users/me')
    .set('Authorization', `Bearer ${registerRes.token}`)
    .send({ account: '1000009999' });

  expect(res.status).toBe(400);
  expect(res.body).toEqual({ message: '请输入正确ID确认注销' });
});

test('DELETE /api/users/me succeeds with exact ID confirmation and invalidates old token', async () => {
  const app = createTestApp();
  const registerRes = await register(app);

  const deleteRes = await request(app)
    .delete('/api/users/me')
    .set('Authorization', `Bearer ${registerRes.token}`)
    .send({ account: registerRes.user.account });

  expect(deleteRes.status).toBe(204);

  const validateRes = await request(app)
    .post('/api/auth/validate')
    .set('Authorization', `Bearer ${registerRes.token}`)
    .send();

  expect(validateRes.status).toBe(401);
  expect(validateRes.body).toEqual({ message: '登录已失效' });
});
