const WebSocket = require('ws');
const { verifyToken } = require('../auth/token');

function parseMessage(raw) {
  try {
    return JSON.parse(raw);
  } catch (error) {
    return null;
  }
}

function send(socket, type, payload) {
  if (socket.readyState === WebSocket.OPEN || socket.readyState === 1) {
    socket.send(JSON.stringify({ type, payload }));
  }
}

function createSocketServer({ server, messageService, userService, authenticateToken } = {}) {
  const socketsByUserId = new Map();
  const authenticate = authenticateToken || (async (token) => {
    const payload = verifyToken(token);
    return userService.validateTokenPayload(payload);
  });

  function addSocket(userId, socket) {
    const key = Number(userId);
    if (!socketsByUserId.has(key)) {
      socketsByUserId.set(key, new Set());
    }
    socketsByUserId.get(key).add(socket);
  }

  function removeSocket(socket) {
    for (const sockets of socketsByUserId.values()) {
      sockets.delete(socket);
    }
  }

  function broadcast(targets, type, payload) {
    for (const userId of targets) {
      const sockets = socketsByUserId.get(Number(userId)) || new Set();
      for (const socket of sockets) {
        send(socket, type, payload);
      }
    }
  }

  async function handleAuthedEvent(socket, userId, event) {
    if (event.type === 'message:create') {
      const result = await messageService.createMessage(userId, event.payload || {});
      broadcast(result.targets, 'message:created', result);
      return;
    }
    if (event.type === 'message:delivered') {
      const result = await messageService.markDelivered(event.messageId || event.payload?.messageId);
      broadcast(result.targets, 'message:delivered', result);
      return;
    }
    if (event.type === 'message:read') {
      const result = await messageService.markRead(event.messageId || event.payload?.messageId, userId);
      broadcast(result.targets, 'message:read', result);
      return;
    }
    if (event.type === 'message:revoke') {
      const result = await messageService.revokeMessage(event.messageId || event.payload?.messageId, userId);
      broadcast(result.targets, 'message:revoked', result);
      return;
    }
    if (event.type === 'message:burn') {
      const result = await messageService.startBurn(event.messageId || event.payload?.messageId, userId);
      broadcast(result.targets, 'message:burn_started', result);
    }
  }

  function handleConnection(socket) {
    let userId = null;

    socket.on('message', async (raw) => {
      const event = parseMessage(raw);
      if (!event) {
        return socket.close(1003);
      }

      try {
        if (!userId) {
          if (event.type !== 'auth') {
            return socket.close(4401);
          }
          const user = await authenticate(event.token || event.payload?.token);
          if (!user) {
            return socket.close(4401);
          }
          userId = Number(user.id);
          addSocket(userId, socket);
          return send(socket, 'auth:ok', { userId });
        }

        return await handleAuthedEvent(socket, userId, event);
      } catch (error) {
        return send(socket, 'error', { message: error.message });
      }
    });

    socket.on('close', () => {
      removeSocket(socket);
    });
  }

  const webSocketServer = server ? new WebSocket.Server({ server }) : null;
  if (webSocketServer) {
    webSocketServer.on('connection', handleConnection);
  }

  return {
    broadcast,
    handleConnection,
    socketsByUserId,
    webSocketServer
  };
}

module.exports = {
  createSocketServer
};
