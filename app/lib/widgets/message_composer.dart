import 'dart:async';

import 'package:app/core/constants/sticker_catalog.dart';
import 'package:app/widgets/emoji_picker.dart';
import 'package:app/widgets/sticker_pack_viewer.dart';
import 'package:flutter/material.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({
    required this.onSend,
    this.onVoiceStart,
    this.onVoiceSend,
    this.onAttach,
    this.onStickerSelected,
    this.recentEmojiStore,
    super.key,
  });

  final ValueChanged<String> onSend;
  final Future<void> Function()? onVoiceStart;
  final ValueChanged<Duration>? onVoiceSend;
  final VoidCallback? onAttach;
  final ValueChanged<StickerItem>? onStickerSelected;
  final RecentEmojiStore? recentEmojiStore;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final TextEditingController _controller = TextEditingController();
  _ComposerPanel _panel = _ComposerPanel.none;
  bool _voiceMode = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('composer-mode-toggle'),
                    tooltip: _voiceMode ? '文字消息' : '语音消息',
                    onPressed: () => setState(() => _voiceMode = !_voiceMode),
                    icon: Icon(
                      _voiceMode ? Icons.keyboard_alt_outlined : Icons.mic_none,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Emoji',
                    onPressed: () => _togglePanel(_ComposerPanel.emoji),
                    icon: const Icon(Icons.emoji_emotions_outlined),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: _voiceMode
                          ? _VoiceRecordBar(
                              onStart: widget.onVoiceStart,
                              onSend: (duration) =>
                                  widget.onVoiceSend?.call(duration),
                            )
                          : TextField(
                              key: const Key('message-input'),
                              controller: _controller,
                              minLines: 1,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(8),
                                  ),
                                ),
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Stickers',
                    onPressed: () => _togglePanel(_ComposerPanel.stickers),
                    icon: const Icon(Icons.sticky_note_2_outlined),
                  ),
                  IconButton(
                    tooltip: 'Attach',
                    onPressed: widget.onAttach,
                    icon: const Icon(Icons.attach_file),
                  ),
                  IconButton(
                    tooltip: 'Send',
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: switch (_panel) {
                _ComposerPanel.none => const SizedBox.shrink(),
                _ComposerPanel.emoji => EmojiPicker(
                  store: widget.recentEmojiStore,
                  onEmojiSelected: _insertEmoji,
                ),
                _ComposerPanel.stickers => StickerPackViewer(
                  onStickerSelected: (sticker) {
                    widget.onStickerSelected?.call(sticker);
                    setState(() => _panel = _ComposerPanel.none);
                  },
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  void _togglePanel(_ComposerPanel panel) {
    setState(() {
      _panel = _panel == panel ? _ComposerPanel.none : panel;
    });
  }

  void _insertEmoji(String emoji) {
    final selection = _controller.selection;
    final text = _controller.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final updated = text.replaceRange(start, end, emoji);
    _controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    widget.onSend(text);
    _controller.clear();
    setState(() => _panel = _ComposerPanel.none);
  }
}

enum _ComposerPanel { none, emoji, stickers }

class _VoiceRecordBar extends StatefulWidget {
  const _VoiceRecordBar({required this.onSend, this.onStart});

  final ValueChanged<Duration> onSend;
  final Future<void> Function()? onStart;

  @override
  State<_VoiceRecordBar> createState() => _VoiceRecordBarState();
}

class _VoiceRecordBarState extends State<_VoiceRecordBar> {
  static const Duration _maxDuration = Duration(seconds: 60);

  DateTime? _startedAt;
  Timer? _ticker;
  OverlayEntry? _overlayEntry;
  Duration _elapsed = Duration.zero;
  bool _sending = false;

  bool get _recording => _startedAt != null;

  @override
  void dispose() {
    _ticker?.cancel();
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('voice-record-bar'),
      onLongPressStart: (_) async {
        if (_recording) {
          return;
        }
        final startedAt = DateTime.now();
        setState(() {
          _startedAt = startedAt;
          _elapsed = Duration.zero;
          _sending = false;
        });
        _showOverlay();
        _ticker?.cancel();
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
        try {
          await widget.onStart?.call();
        } catch (_) {
          _resetRecording();
          rethrow;
        }
      },
      onLongPressEnd: (_) => _finishRecording(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _recording
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_recording ? Icons.graphic_eq : Icons.mic),
            const SizedBox(width: 8),
            Text(_recording ? '松开发送' : '按住说话'),
          ],
        ),
      ),
    );
  }

  void _tick() {
    if (_startedAt == null || !mounted) {
      return;
    }
    final elapsed = _elapsed + const Duration(seconds: 1);
    if (elapsed >= _maxDuration) {
      _finishRecording(forcedDuration: _maxDuration);
      return;
    }
    setState(() => _elapsed = elapsed);
    _overlayEntry?.markNeedsBuild();
  }

  void _finishRecording({Duration? forcedDuration}) {
    if (_sending) {
      return;
    }
    final startedAt = _startedAt;
    if (startedAt == null) {
      return;
    }
    _sending = true;
    final duration = forcedDuration ?? _elapsed;
    final normalized = duration < const Duration(seconds: 1)
        ? const Duration(seconds: 1)
        : duration;
    _resetRecording();
    widget.onSend(normalized > _maxDuration ? _maxDuration : normalized);
  }

  void _resetRecording() {
    _ticker?.cancel();
    _ticker = null;
    _removeOverlay();
    if (!mounted) {
      _startedAt = null;
      _elapsed = Duration.zero;
      _sending = false;
      return;
    }
    setState(() {
      _startedAt = null;
      _elapsed = Duration.zero;
      _sending = false;
    });
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      return;
    }
    _overlayEntry = OverlayEntry(
      builder: (context) => _VoiceRecordOverlay(duration: _elapsed),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

String _formatRecordingDuration(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 60);
  return '00:${seconds.toString().padLeft(2, '0')}';
}

class _VoiceRecordOverlay extends StatelessWidget {
  const _VoiceRecordOverlay({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Material(
          key: const Key('voice-record-overlay'),
          color: Colors.transparent,
          child: Container(
            width: 136,
            height: 136,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.graphic_eq, color: Colors.white, size: 44),
                const SizedBox(height: 12),
                Text(
                  _formatRecordingDuration(duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '松开发送',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
