async function createNoopPushService() {
  return {
    async notifyMessage() {}
  };
}

function createPushService(options = {}) {
  const fetchImpl = options.fetch || global.fetch;
  const projectId = process.env.FCM_PROJECT_ID;
  const accessToken = process.env.FCM_ACCESS_TOKEN;

  if (!projectId || !accessToken || !fetchImpl) {
    return createNoopPushService();
  }

  return {
    async notifyMessage({ tokens, title, body, data = {} }) {
      const uniqueTokens = Array.from(new Set(tokens.filter(Boolean)));
      for (const token of uniqueTokens) {
        await fetchImpl(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
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
          }
        );
      }
    }
  };
}

module.exports = {
  createPushService
};
