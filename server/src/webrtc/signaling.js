const CALL_EVENTS = new Set([
  'call.invite',
  'call.accept',
  'call.reject',
  'call.hangup',
  'call.sdp',
  'call.ice'
]);

const MAX_GROUP_PARTICIPANTS = 8;

function createCallSignaling({ broadcast, isUserOnline } = {}) {
  const rooms = new Map();

  function handle(userId, event) {
    if (!CALL_EVENTS.has(event.type)) {
      return false;
    }

    const payload = event.payload || {};
    switch (event.type) {
      case 'call.invite':
        invite(userId, payload);
        return true;
      case 'call.accept':
        updateParticipant(userId, payload, 'active', 'call.accept');
        return true;
      case 'call.reject':
        updateParticipant(userId, payload, 'rejected', 'call.reject');
        return true;
      case 'call.hangup':
        updateParticipant(userId, payload, 'left', 'call.hangup');
        return true;
      case 'call.sdp':
      case 'call.ice':
        relayTargeted(userId, event.type, payload);
        return true;
      default:
        return false;
    }
  }

  function invite(userId, payload) {
    const callId = requireCallId(payload);
    const invitedIds = normalizedIds(payload.participantIds || payload.participants);
    const participantIds = uniqueIds([userId, ...invitedIds]);
    if (participantIds.length > MAX_GROUP_PARTICIPANTS) {
      throw new Error('Group calls support up to 8 participants');
    }

    const participants = {};
    for (const participantId of participantIds) {
      participants[participantId] = participantId === Number(userId) ? 'invited' : 'invited';
    }
    const room = {
      callId,
      hostId: Number(userId),
      participantIds,
      participants,
      isGroup: Boolean(payload.isGroup || participantIds.length > 2),
      createdAt: new Date().toISOString()
    };
    rooms.set(callId, room);

    relayTo(
      participantIds.filter((participantId) => participantId !== Number(userId)),
      'call.invite',
      publicPayload(room, payload, { fromId: Number(userId) })
    );
  }

  function updateParticipant(userId, payload, state, eventType) {
    const room = requireRoom(payload.callId);
    const id = Number(userId);
    ensureParticipant(room, id);
    room.participants[id] = state;
    relayTo(
      room.participantIds.filter((participantId) => participantId !== id),
      eventType,
      publicPayload(room, payload, { fromId: id })
    );
  }

  function relayTargeted(userId, eventType, payload) {
    const room = requireRoom(payload.callId);
    const fromId = Number(userId);
    const targetId = Number(payload.targetId);
    ensureParticipant(room, fromId);
    ensureParticipant(room, targetId);
    relayTo([targetId], eventType, publicPayload(room, payload, { fromId, targetId }));
  }

  function relayTo(targets, type, payload) {
    const onlineTargets = targets
      .map(Number)
      .filter((targetId) => Number.isFinite(targetId))
      .filter((targetId) => (isUserOnline ? isUserOnline(targetId) : true));
    broadcast(onlineTargets, type, payload);
  }

  function requireRoom(callId) {
    const room = rooms.get(String(callId || ''));
    if (!room) {
      throw new Error('Call not found');
    }
    return room;
  }

  return { handle, rooms };
}

function requireCallId(payload) {
  const callId = String(payload.callId || '');
  if (!callId) {
    throw new Error('callId is required');
  }
  return callId;
}

function ensureParticipant(room, userId) {
  if (!room.participantIds.includes(Number(userId))) {
    throw new Error('User is not a call participant');
  }
}

function normalizedIds(values) {
  if (!Array.isArray(values)) {
    return [];
  }
  return values.map(Number).filter((id) => Number.isFinite(id));
}

function uniqueIds(values) {
  return [...new Set(values.map(Number).filter((id) => Number.isFinite(id)))];
}

function publicPayload(room, originalPayload, extra = {}) {
  return {
    ...originalPayload,
    ...extra,
    callId: room.callId,
    participantIds: room.participantIds,
    participants: { ...room.participants },
    isGroup: room.isGroup
  };
}

module.exports = {
  createCallSignaling,
  MAX_GROUP_PARTICIPANTS
};
