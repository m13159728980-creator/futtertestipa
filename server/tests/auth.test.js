const request = require('supertest');
const { createApp } = require('../app');

function createMemoryUserRepository() {
  let nextId = 1;
  const users = [];

  return {
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

test('GET /api/users/check-account?account=@ZCMX returns available when not taken', async () => {
  const app = createTestApp();

  const res = await request(app).get('/api/users/check-account').query({ account: '@ZCMX' });

  expect(res.status).toBe(200);
  expect(res.body).toEqual({ available: true });
});

test('POST /api/auth/register rejects account without @ prefix', async () => {
  const app = createTestApp();

  const res = await request(app)
    .post('/api/auth/register')
    .send({ account: 'ZCMX', displayName: 'ZCMX' });

  expect(res.status).toBe(400);
  expect(res.body).toEqual({ message: '账号必须是英文，且以@开头' });
});

test('POST /api/auth/register rejects account with numbers', async () => {
  const app = createTestApp();

  const res = await request(app)
    .post('/api/auth/register')
    .send({ account: '@ZCMX1', displayName: 'ZCMX' });

  expect(res.status).toBe(400);
  expect(res.body).toEqual({ message: '账号必须是英文，且以@开头' });
});

test('POST /api/auth/register rejects blank displayName/name', async () => {
  const app = createTestApp();

  const res = await request(app)
    .post('/api/auth/register')
    .send({ account: '@ZCMX', displayName: '   ', name: '' });

  expect(res.status).toBe(400);
  expect(res.body).toEqual({ message: '请输入名字' });
});

test('POST /api/auth/register accepts valid account and returns user with token', async () => {
  const app = createTestApp();

  const res = await request(app)
    .post('/api/auth/register')
    .send({ account: '@ZCMX', displayName: 'ZCMX' });

  expect(res.status).toBe(201);
  expect(res.body).toEqual({
    user: {
      id: expect.any(Number),
      account: '@ZCMX',
      displayName: 'ZCMX',
      avatarIndex: expect.any(Number)
    },
    token: expect.any(String)
  });
  expect(res.body.user.avatarIndex).toBeGreaterThanOrEqual(0);
  expect(res.body.user.avatarIndex).toBeLessThanOrEqual(8);
});

test('POST /api/auth/register returns 409 for duplicate account', async () => {
  const app = createTestApp();

  await request(app)
    .post('/api/auth/register')
    .send({ account: '@ZCMX', displayName: 'ZCMX' });

  const res = await request(app)
    .post('/api/auth/register')
    .send({ account: '@ZCMX', displayName: 'Other' });

  expect(res.status).toBe(409);
  expect(res.body).toEqual({ message: '账号已被注册' });
});

test('POST /api/auth/validate accepts a valid token', async () => {
  const app = createTestApp();
  const registerRes = await request(app)
    .post('/api/auth/register')
    .send({ account: '@ZCMX', displayName: 'ZCMX' });

  const res = await request(app)
    .post('/api/auth/validate')
    .set('Authorization', `Bearer ${registerRes.body.token}`)
    .send();

  expect(res.status).toBe(200);
  expect(res.body).toEqual({
    user: {
      id: registerRes.body.user.id,
      account: '@ZCMX',
      displayName: 'ZCMX',
      avatarIndex: registerRes.body.user.avatarIndex
    }
  });
});
