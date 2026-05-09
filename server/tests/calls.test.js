const { createSocketServer } = require('../src/websocket/socketServer');

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

async function authedServer() {
  const socketServer = createSocketServer({
    messageService: {},
    authenticateToken: async (token) => {
      const match = token?.match(/^user-(\d+)$/);
      return match ? { id: Number(match[1]) } : null;
    }
  });
  const sockets = {};
  for (const id of [1, 2, 3, 4, 9]) {
    sockets[id] = createFakeSocket();
    socketServer.handleConnection(sockets[id]);
    await sockets[id].emitMessage({ type: 'auth', token: `user-${id}` });
    sockets[id].sent.length = 0;
  }
  return { socketServer, sockets };
}

test('call.invite is sent only to intended online participants', async () => {
  const { sockets } = await authedServer();

  await sockets[1].emitMessage({
    type: 'call.invite',
    payload: { callId: 'call-1', participantIds: [2, 3], isGroup: true }
  });

  expect(sockets[2].sent).toEqual([
    expect.objectContaining({ type: 'call.invite', payload: expect.objectContaining({ callId: 'call-1', fromId: 1 }) })
  ]);
  expect(sockets[3].sent).toEqual([
    expect.objectContaining({ type: 'call.invite', payload: expect.objectContaining({ callId: 'call-1', fromId: 1 }) })
  ]);
  expect(sockets[4].sent).toEqual([]);
  expect(sockets[9].sent).toEqual([]);
});

test('group calls reject more than 8 total participants', async () => {
  const { sockets } = await authedServer();

  await sockets[1].emitMessage({
    type: 'call.invite',
    payload: { callId: 'too-large', participantIds: [2, 3, 4, 5, 6, 7, 8, 9], isGroup: true }
  });

  expect(sockets[1].sent).toEqual([
    expect.objectContaining({ type: 'error', payload: expect.objectContaining({ message: 'Group calls support up to 8 participants' }) })
  ]);
  expect(sockets[2].sent).toEqual([]);
});

test('call.accept, reject and hangup update participant state and stay in the call', async () => {
  const { sockets } = await authedServer();
  await sockets[1].emitMessage({
    type: 'call.invite',
    payload: { callId: 'call-2', participantIds: [2, 3], isGroup: true }
  });
  sockets[1].sent.length = 0;
  sockets[2].sent.length = 0;
  sockets[3].sent.length = 0;

  await sockets[2].emitMessage({ type: 'call.accept', payload: { callId: 'call-2' } });
  await sockets[3].emitMessage({ type: 'call.reject', payload: { callId: 'call-2' } });
  await sockets[2].emitMessage({ type: 'call.hangup', payload: { callId: 'call-2' } });

  expect(sockets[1].sent.map((event) => event.type)).toEqual(['call.accept', 'call.reject', 'call.hangup']);
  expect(sockets[1].sent[0].payload.participants).toEqual(expect.objectContaining({ 1: 'invited', 2: 'active', 3: 'invited' }));
  expect(sockets[1].sent[1].payload.participants).toEqual(expect.objectContaining({ 3: 'rejected' }));
  expect(sockets[1].sent[2].payload.participants).toEqual(expect.objectContaining({ 2: 'left' }));
  expect(sockets[9].sent).toEqual([]);
});

test('call.sdp and call.ice relay only to targeted online call participants', async () => {
  const { sockets } = await authedServer();
  await sockets[1].emitMessage({
    type: 'call.invite',
    payload: { callId: 'call-3', participantIds: [2, 3], isGroup: true }
  });
  for (const socket of Object.values(sockets)) {
    socket.sent.length = 0;
  }

  await sockets[1].emitMessage({
    type: 'call.sdp',
    payload: { callId: 'call-3', targetId: 2, description: { type: 'offer', sdp: 'v=0' } }
  });
  await sockets[2].emitMessage({
    type: 'call.ice',
    payload: { callId: 'call-3', targetId: 1, candidate: { candidate: 'candidate:1' } }
  });

  expect(sockets[2].sent).toEqual([
    expect.objectContaining({ type: 'call.sdp', payload: expect.objectContaining({ fromId: 1, targetId: 2 }) })
  ]);
  expect(sockets[1].sent).toEqual([
    expect.objectContaining({ type: 'call.ice', payload: expect.objectContaining({ fromId: 2, targetId: 1 }) })
  ]);
  expect(sockets[3].sent).toEqual([]);
  expect(sockets[9].sent).toEqual([]);
});
