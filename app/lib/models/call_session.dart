enum CallState { incoming, outgoing, active, ended }

enum CallParticipantState { invited, active, rejected, left }

class CallSession {
  const CallSession({
    required this.id,
    required this.state,
    required this.participantIds,
    required this.participants,
    required this.isGroup,
    required this.title,
    this.peerId,
    this.startedAt,
  });

  final String id;
  final CallState state;
  final List<String> participantIds;
  final Map<String, CallParticipantState> participants;
  final bool isGroup;
  final String title;
  final String? peerId;
  final DateTime? startedAt;

  Duration duration(DateTime now) {
    final started = startedAt;
    if (started == null || state != CallState.active) {
      return Duration.zero;
    }
    return now.difference(started);
  }

  CallSession copyWith({
    CallState? state,
    List<String>? participantIds,
    Map<String, CallParticipantState>? participants,
    bool? isGroup,
    String? title,
    String? peerId,
    DateTime? startedAt,
  }) {
    return CallSession(
      id: id,
      state: state ?? this.state,
      participantIds: participantIds ?? this.participantIds,
      participants: participants ?? this.participants,
      isGroup: isGroup ?? this.isGroup,
      title: title ?? this.title,
      peerId: peerId ?? this.peerId,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

CallParticipantState callParticipantStateFromJson(Object? value) {
  return CallParticipantState.values.firstWhere(
    (state) => state.name == value.toString(),
    orElse: () => CallParticipantState.invited,
  );
}
