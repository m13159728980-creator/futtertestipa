import 'package:flutter/material.dart';

class CallControls extends StatelessWidget {
  const CallControls({
    required this.isMicMuted,
    required this.isSpeakerOn,
    required this.isCameraOff,
    this.showCameraToggle = true,
    required this.onToggleMic,
    required this.onToggleSpeaker,
    required this.onToggleCamera,
    required this.onHangup,
    super.key,
  });

  final bool isMicMuted;
  final bool isSpeakerOn;
  final bool isCameraOff;
  final bool showCameraToggle;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onToggleCamera;
  final VoidCallback onHangup;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundControl(
              icon: isMicMuted ? Icons.mic_off : Icons.mic,
              tooltip: isMicMuted ? 'Unmute microphone' : 'Mute microphone',
              onPressed: onToggleMic,
            ),
            _RoundControl(
              icon: isSpeakerOn ? Icons.volume_up : Icons.volume_off,
              tooltip: isSpeakerOn ? 'Disable speaker' : 'Enable speaker',
              onPressed: onToggleSpeaker,
            ),
            if (showCameraToggle)
              _RoundControl(
                icon: isCameraOff ? Icons.videocam_off : Icons.videocam,
                tooltip: isCameraOff ? 'Enable camera' : 'Disable camera',
                onPressed: onToggleCamera,
              ),
            _RoundControl(
              icon: Icons.call_end,
              tooltip: 'Hang up',
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              onPressed: onHangup,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton.filled(
        style: IconButton.styleFrom(
          fixedSize: const Size.square(56),
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
        ),
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}
