import 'dart:async';

import 'package:app/models/call_session.dart';
import 'package:app/providers/call_provider.dart';
import 'package:app/widgets/call_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calls = ref.watch(callProvider);
    final session = calls.session;
    if (session == null) {
      return const Scaffold(body: Center(child: Text('没有正在进行的通话')));
    }

    return Scaffold(
      appBar: AppBar(title: Text(session.title)),
      body: Column(
        children: [
          Expanded(child: _CallBody(session: session)),
          if (session.state == CallState.incoming)
            _IncomingActions(
              onAccept: () => ref.read(callProvider).accept(),
              onReject: () async {
                await ref.read(callProvider).reject();
                if (context.mounted) {
                  Navigator.of(context).maybePop();
                }
              },
            )
          else
            CallControls(
              isMicMuted: calls.isMicMuted,
              isSpeakerOn: calls.isSpeakerOn,
              isCameraOff: calls.isCameraOff,
              showCameraToggle: calls.isVideoCall,
              onToggleMic: () => ref.read(callProvider).toggleMic(),
              onToggleSpeaker: () => ref.read(callProvider).toggleSpeaker(),
              onToggleCamera: () => ref.read(callProvider).toggleCamera(),
              onHangup: () async {
                await ref.read(callProvider).hangup();
                if (context.mounted) {
                  Navigator.of(context).maybePop();
                }
              },
            ),
        ],
      ),
    );
  }
}

class _CallBody extends StatelessWidget {
  const _CallBody({required this.session});

  final CallSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 44,
            child: Icon(
              session.isGroup ? Icons.groups : Icons.person,
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            session.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(_statusText(session), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          if (session.isGroup)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in session.participants.entries)
                  Chip(
                    avatar: const Icon(Icons.person, size: 18),
                    label: Text('${entry.key} ${entry.value.name}'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _statusText(CallSession session) {
    switch (session.state) {
      case CallState.incoming:
        return '来电';
      case CallState.outgoing:
        return '正在呼叫...';
      case CallState.active:
        return _formatDuration(session.duration(DateTime.now()));
      case CallState.ended:
        return '通话已结束';
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class _IncomingActions extends StatelessWidget {
  const _IncomingActions({required this.onAccept, required this.onReject});

  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onAccept,
                icon: const Icon(Icons.call),
                label: const Text('接听'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onReject,
                icon: const Icon(Icons.call_end),
                label: const Text('拒绝'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
