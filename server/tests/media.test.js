const fs = require('fs');
const os = require('os');
const path = require('path');
const request = require('supertest');
const { createApp } = require('../app');
const { createUserService } = require('../src/services/userService');
const { createMediaService } = require('../src/services/mediaService');
const { createAccountPurgeJob } = require('../src/jobs/accountPurgeJob');

function createMemoryUserRepository() {
  let nextId = 1;
  const users = [];
  const accountDeletions = [];

  return {
    accountDeletions,
    users,
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
      const user = { id: nextId, account, displayName, avatarIndex, tokenVersion: 0, deletedAt: null };
      nextId += 1;
      users.push(user);
      return user;
    },
    async updateAvatar(id, avatarIndex) {
      const user = users.find((candidate) => candidate.id === Number(id) && !candidate.deletedAt);
      if (!user) return null;
      user.avatarIndex = avatarIndex;
      return user;
    },
    async softDelete(id) {
      const user = users.find((candidate) => candidate.id === Number(id) && !candidate.deletedAt);
      if (!user) return null;
      user.deletedAt = new Date('2026-05-10T00:00:00.000Z');
      user.tokenVersion += 1;
      accountDeletions.push({
        userId: user.id,
        requestedAt: new Date('2026-05-10T00:00:00.000Z'),
        purgeAfter: new Date('2026-06-09T00:00:00.000Z'),
        completedAt: null
      });
      return user;
    }
  };
}

function createMemoryMediaRepository() {
  const files = [];
  return {
    files,
    async create(file) {
      files.push(file);
      return file;
    },
    async findById(id) {
      return files.find((file) => file.id === id) || null;
    }
  };
}

async function register(app, account = '@MEDIA') {
  const res = await request(app)
    .post('/api/auth/register')
    .send({ account, displayName: account.slice(1) });
  expect(res.status).toBe(201);
  return res.body;
}

test('media service rejects files larger than 50 MB', async () => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'media-large-'));
  const tempFile = path.join(tempDir, 'large.bin');
  fs.closeSync(fs.openSync(tempFile, 'w'));
  fs.truncateSync(tempFile, 50 * 1024 * 1024 + 1);
  const service = createMediaService({
    mediaRepository: createMemoryMediaRepository(),
    storagePath: tempDir
  });

  await expect(service.storeUpload(1, {
    path: tempFile,
    originalname: 'large.bin',
    mimetype: 'application/octet-stream',
    size: 50 * 1024 * 1024 + 1
  })).rejects.toMatchObject({ statusCode: 413 });
});

test('POST /api/media/upload stores allowed upload metadata in media_files', async () => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'media-upload-'));
  const mediaRepository = createMemoryMediaRepository();
  const app = createApp({
    userRepository: createMemoryUserRepository(),
    mediaRepository,
    storagePath: tempDir
  });
  const { token, user } = await register(app);

  const res = await request(app)
    .post('/api/media/upload')
    .set('Authorization', `Bearer ${token}`)
    .attach('file', Buffer.from('hello media'), { filename: 'hello.txt', contentType: 'text/plain' });

  expect(res.status).toBe(201);
  expect(res.body.file).toMatchObject({
    id: expect.any(String),
    ownerId: user.id,
    originalName: 'hello.txt',
    mimeType: 'text/plain',
    sizeBytes: 11,
    sha256: 'd28d2954ff97ac68052c4beff8c84ad0960d1408540fc486256cdd7cd68dd1fe'
  });
  expect(mediaRepository.files).toHaveLength(1);
  expect(mediaRepository.files[0]).toMatchObject(res.body.file);
  expect(path.resolve(mediaRepository.files[0].storagePath)).toContain(path.resolve(tempDir, 'media'));
  expect(fs.existsSync(mediaRepository.files[0].storagePath)).toBe(true);
});

test('GET /api/stickers/packs returns default official sticker pack metadata', async () => {
  const app = createApp({ userRepository: createMemoryUserRepository() });

  const res = await request(app).get('/api/stickers/packs');

  expect(res.status).toBe(200);
  expect(res.body.packs).toHaveLength(3);
  expect(res.body.packs).toEqual([
    expect.objectContaining({ slug: 'pack1', downloadUrl: '/stickers/pack1.zip', name: expect.any(String), version: 1 }),
    expect.objectContaining({ slug: 'pack2', downloadUrl: '/stickers/pack2.zip', name: expect.any(String), version: 1 }),
    expect.objectContaining({ slug: 'pack3', downloadUrl: '/stickers/pack3.zip', name: expect.any(String), version: 1 })
  ]);
});

test('account deletion marks deletion, increments token version, records purge, and releases account checks', async () => {
  const repository = createMemoryUserRepository();
  const userService = createUserService({ userRepository: repository });
  const app = createApp({ userService, userRepository: repository });
  const { token, user } = await register(app, '@DELETE');

  const deleteRes = await request(app)
    .delete('/api/users/me')
    .set('Authorization', `Bearer ${token}`)
    .send({ account: '@DELETE' });
  expect(deleteRes.status).toBe(204);

  const deleted = repository.users.find((candidate) => candidate.id === user.id);
  expect(deleted.deletedAt).toEqual(new Date('2026-05-10T00:00:00.000Z'));
  expect(deleted.tokenVersion).toBe(1);
  expect(repository.accountDeletions).toEqual([
    expect.objectContaining({ userId: user.id, completedAt: null })
  ]);
  await expect(userService.validateTokenPayload({
    userId: user.id,
    account: '@DELETE',
    tokenVersion: 0
  })).resolves.toBeNull();

  const checkRes = await request(app).get('/api/users/check-account').query({ account: '@DELETE' });
  expect(checkRes.status).toBe(200);
  expect(checkRes.body).toEqual({ available: true });
});

test('account purge job marks due account deletions complete after successful purge', async () => {
  const completed = [];
  const job = createAccountPurgeJob({
    repository: {
      async listDueDeletions(now) {
        expect(now).toEqual(new Date('2026-05-10T00:00:00.000Z'));
        return [{ userId: 7, purgeAfter: new Date('2026-05-09T00:00:00.000Z') }];
      },
      async purgeUser(userId) {
        expect(userId).toBe(7);
        return true;
      },
      async markCompleted(userId, completedAt) {
        completed.push({ userId, completedAt });
      }
    },
    now: () => new Date('2026-05-10T00:00:00.000Z')
  });

  await expect(job.runOnce()).resolves.toEqual({ processed: 1, purged: 1, completed: 1 });
  expect(completed).toEqual([{ userId: 7, completedAt: new Date('2026-05-10T00:00:00.000Z') }]);
});

test('account purge job leaves deletion pending when purge fails', async () => {
  const completed = [];
  const job = createAccountPurgeJob({
    repository: {
      async listDueDeletions() {
        return [{ userId: 9, purgeAfter: new Date('2026-05-09T00:00:00.000Z') }];
      },
      async purgeUser() {
        return false;
      },
      async markCompleted(userId, completedAt) {
        completed.push({ userId, completedAt });
      }
    },
    now: () => new Date('2026-05-10T00:00:00.000Z')
  });

  await expect(job.runOnce()).resolves.toEqual({ processed: 1, purged: 0, completed: 0 });
  expect(completed).toEqual([]);
});

test('GET /api/stickers/packs returns repository-backed sticker pack metadata', async () => {
  const app = createApp({
    userRepository: createMemoryUserRepository(),
    stickerRepository: {
      async listActivePacks() {
        return [{
          id: 'pack-1',
          slug: 'custom',
          name: 'Custom Pack',
          version: 3,
          zipPath: 'custom/custom.zip',
          manifest: { stickers: ['wave'] },
          official: false
        }];
      }
    }
  });

  const res = await request(app).get('/api/stickers/packs');

  expect(res.status).toBe(200);
  expect(res.body.packs).toEqual([{
    id: 'pack-1',
    slug: 'custom',
    name: 'Custom Pack',
    version: 3,
    manifest: { stickers: ['wave'] },
    downloadUrl: '/stickers/custom.zip',
    official: false
  }]);
});

test('GET /stickers/:pack.zip downloads repository-backed sticker pack relative to sticker storage', async () => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'stickers-'));
  const zipPath = path.join(tempDir, 'stickers', 'custom', 'custom.zip');
  fs.mkdirSync(path.dirname(zipPath), { recursive: true });
  fs.writeFileSync(zipPath, 'zip bytes');
  const app = createApp({
    userRepository: createMemoryUserRepository(),
    storagePath: tempDir,
    stickerRepository: {
      async findActivePackBySlug(slug) {
        expect(slug).toBe('custom');
        return { slug: 'custom', name: 'Custom Pack', zipPath: 'custom/custom.zip' };
      }
    }
  });

  const res = await request(app).get('/stickers/custom.zip');

  expect(res.status).toBe(200);
  expect(res.text).toBe('zip bytes');
});

test('GET /stickers/:pack.zip rejects repository zip paths outside sticker storage', async () => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'stickers-unsafe-'));
  const app = createApp({
    userRepository: createMemoryUserRepository(),
    storagePath: tempDir,
    stickerRepository: {
      async findActivePackBySlug() {
        return { slug: 'unsafe', name: 'Unsafe Pack', zipPath: '../unsafe.zip' };
      }
    }
  });

  const res = await request(app).get('/stickers/unsafe.zip');

  expect(res.status).toBe(403);
  expect(res.body).toEqual({ message: 'Unsafe sticker path' });
});
