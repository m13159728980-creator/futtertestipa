const { createPushService } = require('../src/services/pushService');

const originalEnv = process.env;

beforeEach(() => {
  process.env = {
    ...originalEnv,
    GETUI_APP_ID: 'app-id',
    GETUI_APP_KEY: 'app-key',
    GETUI_MASTER_SECRET: 'master-secret'
  };
});

afterEach(() => {
  process.env = originalEnv;
});

test('sends Getui notification to registered client ids', async () => {
  const calls = [];
  const fetch = jest.fn(async (url, options) => {
    calls.push({ url, options });
    if (url.endsWith('/auth')) {
      return {
        ok: true,
        async json() {
          return { data: { token: 'auth-token', expire_time: Date.now() + 3600000 } };
        }
      };
    }
    return {
      ok: true,
      async json() {
        return { code: 0 };
      }
    };
  });
  const service = createPushService({ fetch });

  await service.notifyMessage({
    tokens: [{ token: 'cid-1', platform: 'getui' }],
    title: '新消息',
    body: 'hello',
    data: { messageId: 'm1' }
  });

  expect(fetch).toHaveBeenCalledTimes(2);
  expect(calls[0].url).toBe('https://restapi.getui.com/v2/app-id/auth');
  expect(JSON.parse(calls[0].options.body)).toEqual(
    expect.objectContaining({ appkey: 'app-key' })
  );
  expect(calls[1].url).toBe('https://restapi.getui.com/v2/app-id/push/single/cid');
  expect(calls[1].options.headers.token).toBe('auth-token');
  expect(JSON.parse(calls[1].options.body)).toEqual(
    expect.objectContaining({
      audience: { cid: ['cid-1'] },
      push_message: expect.objectContaining({
        notification: expect.objectContaining({ title: '新消息', body: 'hello' })
      })
    })
  );
});
