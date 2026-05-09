const request = require('supertest');
const { createApp } = require('../app');

test('GET /api/health returns ok', async () => {
  const app = createApp();
  const res = await request(app).get('/api/health');
  expect(res.status).toBe(200);
  expect(res.body).toEqual({ ok: true });
});
