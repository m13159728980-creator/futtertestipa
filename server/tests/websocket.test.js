const { createSocketServer } = require('../src/websocket/socketServer');
const {
  createMemoryMessageRepository,
  createMessageService
} = require('../src/services/messageService');

function createFakeSocket() {
  const handlers = {};
  const sent = [];

  return {
    readyState: 1,
    sent,
    on(event, handler) {
      handlers[event] = handler;
    },
    emitMessage(payload) {
      return handlers.message(JSON.stringify(payload));
    },
    emitClose() {
      handlers.close?.();
    },
    send(payload) {
      sent.push(JSON.parse(payload));
    },
    closeCode: null,
    close(code) {
      this.closeCode = code;
    }
  };
}

test('websocket requires auth before routing messages', async () => {
  const repository = createMemoryMessageRepository();
  const messageService = createMessageService({ messageRepository: repository });
  const socketServer = createSocketServer({
    messageService,
    authenticateToken: async (token) => (token === 'alice-token' ? { id: 1 } : null)
  });
  const unauthenticated = createFakeSocket();

  socketServer.handleConnection(unauthenticated);
  await unauthenticated.emitMessage({
    type: 'message.send',
    payload: { toId: 2, toType: 'user', content: 'before auth' }
  });
  expect(unauthenticated.closeCode).toBe(4401);
  expect(await repository.syncMessagesForUser(2, new Date(0))).toEqual([]);
});

test('websocket broadcasts real presence updates and login snapshots', async () => {
  const socketServer = createSocketServer({
    messageService: {},
    authenticateToken: async (token) => {
      if (token === 'alice-token') {
        return { id: 1 };
      }
      if (token === 'bob-token') {
        return { id: 2 };
      }
      return null;
    }
  });
  const alice = createFakeSocket();
  const bob = createFakeSocket();

  socketServer.handleConnection(alice);
  await alice.emitMessage({ type: 'auth', token: 'alice-token' });

  expect(alice.sent).toEqual([
    { type: 'auth:ok', payload: { userId: 1 } },
    { type: 'presence.snapshot', payload: { onlineUserIds: [] } }
  ]);
  alice.sent.length = 0;

  socketServer.handleConnection(bob);
  await bob.emitMessage({ type: 'auth', token: 'bob-token' });

  expect(bob.sent).toEqual([
    { type: 'auth:ok', payload: { userId: 2 } },
    { type: 'presence.snapshot', payload: { onlineUserIds: [1] } }
  ]);
  expect(alice.sent).toEqual([
    { type: 'presence.updated', payload: { userId: 2, isOnline: true } }
  ]);

  alice.sent.length = 0;
  bob.emitClose();

  expect(alice.sent).toEqual([
    expect.objectContaining({
      type: 'presence.updated',
      payload: expect.objectContaining({ userId: 2, isOnline: false })
    })
  ]);
});

test('websocket uses approved event names and does not leak fan-out targets', async () => {
  const repository = createMemoryMessageRepository();
  const messageService = createMessageService({ messageRepository: repository });
  const socketServer = createSocketServer({
    messageService,
    authenticateToken: async (token) => {
      if (token === 'alice-token') {
        return { id: 1 };
      }
      if (token === 'bob-token') {
        return { id: 2 };
      }
      return null;
    }
  });
  const alice = createFakeSocket();
  const bob = createFakeSocket();

  socketServer.handleConnection(alice);
  socketServer.handleConnection(bob);
  await alice.emitMessage({ type: 'auth', token: 'alice-token' });
  await bob.emitMessage({ type: 'auth', token: 'bob-token' });
  await alice.emitMessage({
    type: 'message.send',
    payload: { toId: 2, toType: 'user', type: 'text', content: 'after auth' }
  });

  expect(bob.sent).toEqual(expect.arrayContaining([
    expect.objectContaining({
      type: 'message.send',
      payload: expect.objectContaining({
        message: expect.objectContaining({ fromId: 1, toId: 2, content: 'after auth' })
      })
    })
  ]));
  expect(bob.sent.find((event) => event.type === 'message.send').payload.targets).toBeUndefined();
});

test('websocket routes read events through approved contract', async () => {
  const repository = createMemoryMessageRepository();
  const messageService = createMessageService({ messageRepository: repository });
  const socketServer = createSocketServer({
    messageService,
    authenticateToken: async (token) => {
      if (token === 'alice-token') {
        return { id: 1 };
      }
      if (token === 'bob-token') {
        return { id: 2 };
      }
      return null;
    }
  });
  const alice = createFakeSocket();
  const bob = createFakeSocket();

  socketServer.handleConnection(alice);
  socketServer.handleConnection(bob);
  await alice.emitMessage({ type: 'auth', token: 'alice-token' });
  await bob.emitMessage({ type: 'auth', token: 'bob-token' });
  const { message } = await messageService.createMessage(1, {
    toId: 2,
    toType: 'user',
    type: 'text',
    content: 'read contract'
  });

  await bob.emitMessage({ type: 'message.read', payload: { messageId: message.id } });

  expect(alice.sent).toEqual(expect.arrayContaining([
    expect.objectContaining({
      type: 'message.read',
      payload: expect.objectContaining({
        message: expect.objectContaining({ id: message.id, status: 'read' })
      })
    })
  ]));
  expect(alice.sent.find((event) => event.type === 'message.read').payload.targets).toBeUndefined();
});

test('websocket broadcasts private burn setting changes to both participants', async () => {
  const repository = createMemoryMessageRepository();
  const messageService = createMessageService({ messageRepository: repository });
  const socketServer = createSocketServer({
    messageService,
    authenticateToken: async (token) => {
      if (token === 'alice-token') {
        return { id: 1 };
      }
      if (token === 'bob-token') {
        return { id: 2 };
      }
      return null;
    }
  });
  const alice = createFakeSocket();
  const bob = createFakeSocket();

  socketServer.handleConnection(alice);
  socketServer.handleConnection(bob);
  await alice.emitMessage({ type: 'auth', token: 'alice-token' });
  await bob.emitMessage({ type: 'auth', token: 'bob-token' });
  await bob.emitMessage({
    type: 'conversation.burn.set',
    payload: { peerId: 1, burnAfter: 10 }
  });

  expect(alice.sent).toEqual(expect.arrayContaining([
    expect.objectContaining({
      type: 'conversation.burn.updated',
      payload: {
        setting: {
          toType: 'user',
          peerIds: [1, 2],
          burnAfter: 10,
          enabled: true
        }
      }
    })
  ]));
  expect(bob.sent).toEqual(expect.arrayContaining([
    expect.objectContaining({
      type: 'conversation.burn.updated',
      payload: expect.objectContaining({
        setting: expect.objectContaining({ peerIds: [1, 2], burnAfter: 10 })
      })
    })
  ]));
});

test('websocket broadcasts current user avatar changes to supplied targets', async () => {
  const repository = createMemoryMessageRepository();
  const messageService = createMessageService({ messageRepository: repository });
  const userService = {
    async updateAvatar(userId, avatarIndex) {
      return { id: Number(userId), account: '1000000001', displayName: 'Alice', avatarIndex };
    },
    serializeUser(user) {
      return {
        id: user.id,
        account: user.account,
        displayName: user.displayName,
        avatarIndex: user.avatarIndex
      };
    }
  };
  const socketServer = createSocketServer({
    messageService,
    userService,
    authenticateToken: async (token) => {
      if (token === 'alice-token') {
        return { id: 1 };
      }
      if (token === 'bob-token') {
        return { id: 2 };
      }
      return null;
    }
  });
  const alice = createFakeSocket();
  const bob = createFakeSocket();

  socketServer.handleConnection(alice);
  socketServer.handleConnection(bob);
  await alice.emitMessage({ type: 'auth', token: 'alice-token' });
  await bob.emitMessage({ type: 'auth', token: 'bob-token' });
  await alice.emitMessage({
    type: 'user.avatar.set',
    payload: { avatarIndex: 4, targetIds: [2] }
  });

  expect(bob.sent).toEqual(expect.arrayContaining([
    expect.objectContaining({
      type: 'user.updated',
      payload: {
        user: {
          id: 1,
          account: '1000000001',
          displayName: 'Alice',
          avatarIndex: 4
        }
      }
    })
  ]));
});
