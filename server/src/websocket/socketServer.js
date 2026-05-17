const WebSocket = require('ws');
const { verifyToken } = require('../auth/token');
const { createCallSignaling } = require('../webrtc/signaling');

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

function clientPayload(result) {
  return { message: result.message };
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
    const offlineUserIds = [];
    for (const [userId, sockets] of socketsByUserId.entries()) {
      if (!sockets.delete(socket)) {
        continue;
      }
      if (sockets.size === 0) {
        socketsByUserId.delete(userId);
        offlineUserIds.push(userId);
      }
    }
    return offlineUserIds;
  }

  function broadcast(targets, type, payload) {
    for (const userId of targets) {
      const sockets = socketsByUserId.get(Number(userId)) || new Set();
      for (const socket of sockets) {
        send(socket, type, payload);
      }
    }
  }

  function isUserOnline(userId) {
    const sockets = socketsByUserId.get(Number(userId));
    return Boolean(sockets && sockets.size > 0);
  }

  function onlineUserIds({ except } = {}) {
    const excluded = Number(except);
    return Array.from(socketsByUserId.keys())
      .filter((userId) => userId !== excluded)
      .sort((left, right) => left - right);
  }

  function broadcastPresence(userId, isOnline) {
    broadcast(
      onlineUserIds({ except: userId }),
      'presence.updated',
      { userId: Number(userId), isOnline: Boolean(isOnline) }
    );
  }

  const callSignaling = createCallSignaling({ broadcast, isUserOnline });

  async function handleAuthedEvent(socket, userId, event) {
    if (callSignaling.handle(userId, event)) {
      return;
    }
    if (event.type === 'message.send') {
      const result = await messageService.createMessage(userId, event.payload || {});
      broadcast(result.targets, 'message.send', clientPayload(result));
      return;
    }
    if (event.type === 'message.delivered') {
      const result = await messageService.markDelivered(event.messageId || event.payload?.messageId, userId);
      broadcast(result.targets, 'message.delivered', clientPayload(result));
      return;
    }
    if (event.type === 'message.read') {
      const result = await messageService.markRead(event.messageId || event.payload?.messageId, userId);
      broadcast(result.targets, 'message.read', clientPayload(result));
      return;
    }
    if (event.type === 'message.revoke') {
      const result = await messageService.revokeMessage(event.messageId || event.payload?.messageId, userId);
      broadcast(result.targets, 'message.revoke', clientPayload(result));
      return;
    }
    if (event.type === 'message.burn.start') {
      const result = await messageService.startBurn(event.messageId || event.payload?.messageId, userId);
      broadcast(result.targets, 'message.burn.start', clientPayload(result));
      return;
    }
    if (event.type === 'message.burned') {
      const result = await messageService.markBurned(event.messageId || event.payload?.messageId, userId);
      broadcast(result.targets, 'message.burned', clientPayload(result));
      return;
    }
    if (event.type === 'conversation.burn.set') {
      const result = await messageService.setPrivateBurnSetting(
        userId,
        event.payload?.peerId,
        event.payload?.burnAfter
      );
      broadcast(result.targets, 'conversation.burn.updated', { setting: result.setting });
      return;
    }
    if (event.type === 'user.avatar.set') {
      const user = await userService.updateAvatar(userId, Number(event.payload?.avatarIndex));
      const payload = { user: userService.serializeUser(user) };
      const targets = Array.isArray(event.payload?.targetIds)
        ? Array.from(new Set([userId, ...event.payload.targetIds.map(Number)]))
        : [userId];
      broadcast(targets, 'user.updated', payload);
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
          const wasOnline = isUserOnline(userId);
          const snapshot = onlineUserIds({ except: userId });
          addSocket(userId, socket);
          send(socket, 'auth:ok', { userId });
          send(socket, 'presence.snapshot', { onlineUserIds: snapshot });
          if (!wasOnline) {
            broadcastPresence(userId, true);
          }
          return;
        }

        return await handleAuthedEvent(socket, userId, event);
      } catch (error) {
        return send(socket, 'error', { message: error.message });
      }
    });

    socket.on('close', () => {
      for (const offlineUserId of removeSocket(socket)) {
        broadcastPresence(offlineUserId, false);
      }
    });
  }

  const webSocketServer = server ? new WebSocket.Server({ server }) : null;
  if (webSocketServer) {
    webSocketServer.on('connection', handleConnection);
  }

  return {
    broadcast,
    clientPayload,
    handleConnection,
    callSignaling,
    socketsByUserId,
    webSocketServer
  };
}

module.exports = {
  createSocketServer
};
