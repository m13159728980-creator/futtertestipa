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
    type: 'message:create',
    payload: { toId: 2, toType: 'user', content: 'before auth' }
  });
  expect(unauthenticated.closeCode).toBe(4401);
  expect(await repository.syncMessagesForUser(2, new Date(0))).toEqual([]);
});

test('websocket routes private message events to authenticated users', async () => {
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
    type: 'message:create',
    payload: { toId: 2, toType: 'user', type: 'text', content: 'after auth' }
  });

  expect(bob.sent).toEqual(expect.arrayContaining([
    expect.objectContaining({
      type: 'message:created',
      payload: expect.objectContaining({
        message: expect.objectContaining({ fromId: 1, toId: 2, content: 'after auth' })
      })
    })
  ]));
});
