import 'package:app/core/constants/sticker_catalog.dart';
import 'package:app/widgets/emoji_picker.dart';
import 'package:app/widgets/sticker_pack_viewer.dart';
import 'package:flutter/material.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({
    required this.onSend,
    this.onAttach,
    this.onStickerSelected,
    this.recentEmojiStore,
    super.key,
  });

  final ValueChanged<String> onSend;
  final VoidCallback? onAttach;
  final ValueChanged<StickerItem>? onStickerSelected;
  final RecentEmojiStore? recentEmojiStore;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final TextEditingController _controller = TextEditingController();
  _ComposerPanel _panel = _ComposerPanel.none;

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
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Emoji',
                    onPressed: () => _togglePanel(_ComposerPanel.emoji),
                    icon: const Icon(Icons.emoji_emotions_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      key: const Key('message-input'),
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
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
