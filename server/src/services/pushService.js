const crypto = require('crypto');

function createNoopPushService() {
  return {
    async notifyMessage() {}
  };
}

function normalizeTokens(tokens) {
  return Array.from(
    new Map(
      tokens
        .map((item) => (typeof item === 'string' ? { token: item, platform: 'android' } : item))
        .filter((item) => item?.token)
        .map((item) => [item.token, { token: item.token, platform: item.platform || 'android' }])
    ).values()
  );
}

function createGetuiClient({ fetchImpl, appId, appKey, masterSecret }) {
  let cachedToken = null;
  let expiresAt = 0;

  async function authToken() {
    if (cachedToken && Date.now() < expiresAt - 60000) {
      return cachedToken;
    }
    const timestamp = Date.now();
    const sign = crypto
      .createHash('sha256')
      .update(`${appKey}${timestamp}${masterSecret}`)
      .digest('hex');
    const response = await fetchImpl(`https://restapi.getui.com/v2/${appId}/auth`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ sign, timestamp, appkey: appKey })
    });
    if (!response.ok) {
      throw new Error(`Getui auth failed: ${response.status} ${await response.text()}`);
    }
    const payload = await response.json();
    cachedToken = payload.data?.token || payload.token;
    expiresAt = payload.data?.expire_time || Date.now() + 12 * 60 * 60 * 1000;
    if (!cachedToken) {
      throw new Error('Getui auth response did not include token');
    }
    return cachedToken;
  }

  return {
    async pushToCid({ cid, title, body, data }) {
      const token = await authToken();
      const response = await fetchImpl(`https://restapi.getui.com/v2/${appId}/push/single/cid`, {
        method: 'POST',
        headers: {
          token,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          request_id: `${Date.now()}-${Math.random().toString(16).slice(2)}`,
          audience: { cid: [cid] },
          push_message: {
            notification: {
              title,
              body,
              click_type: 'startapp'
            }
          },
          push_channel: {
            android: {
              ups: {
                notification: {
                  title,
                  body,
                  click_type: 'startapp'
                }
              }
            }
          },
          data: JSON.stringify(data || {})
        })
      });
      if (!response.ok) {
        throw new Error(`Getui push failed: ${response.status} ${await response.text()}`);
      }
    }
  };
}

function createFcmClient({ fetchImpl, projectId, accessToken }) {
  return {
    async pushToToken({ token, title, body, data }) {
      await fetchImpl(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data
          }
        })
      });
    }
  };
}

function createPushService(options = {}) {
  const fetchImpl = options.fetch || global.fetch;
  if (!fetchImpl) {
    return createNoopPushService();
  }

  const fcmProjectId = process.env.FCM_PROJECT_ID;
  const fcmAccessToken = process.env.FCM_ACCESS_TOKEN;
  const getuiAppId = process.env.GETUI_APP_ID;
  const getuiAppKey = process.env.GETUI_APP_KEY;
  const getuiMasterSecret = process.env.GETUI_MASTER_SECRET;
  const fcm = fcmProjectId && fcmAccessToken
    ? createFcmClient({ fetchImpl, projectId: fcmProjectId, accessToken: fcmAccessToken })
    : null;
  const getui = getuiAppId && getuiAppKey && getuiMasterSecret
    ? createGetuiClient({
        fetchImpl,
        appId: getuiAppId,
        appKey: getuiAppKey,
        masterSecret: getuiMasterSecret
      })
    : null;

  if (!fcm && !getui) {
    return createNoopPushService();
  }

  return {
    async notifyMessage({ tokens, title, body, data = {} }) {
      for (const item of normalizeTokens(tokens || [])) {
        if (item.platform === 'getui' && getui) {
          await getui.pushToCid({ cid: item.token, title, body, data });
        } else if (fcm) {
          await fcm.pushToToken({ token: item.token, title, body, data });
        }
      }
    }
  };
}

module.exports = {
  createPushService
};
