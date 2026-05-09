import 'package:flutter/material.dart';

abstract interface class RecentEmojiStore {
  Future<List<String>> loadRecent();

  Future<void> saveRecent(List<String> emoji);
}

class InMemoryRecentEmojiStore implements RecentEmojiStore {
  InMemoryRecentEmojiStore([List<String> initial = const []])
    : _recent = List<String>.from(initial.take(24));

  List<String> _recent;

  @override
  Future<List<String>> loadRecent() async => List.unmodifiable(_recent);

  @override
  Future<void> saveRecent(List<String> emoji) async {
    _recent = List<String>.from(emoji.take(24));
  }
}

class EmojiPicker extends StatefulWidget {
  const EmojiPicker({
    required this.onEmojiSelected,
    this.store,
    this.emoji = defaultEmoji,
    super.key,
  });

  static const defaultEmoji = <String>[
    '😀',
    '😄',
    '😂',
    '😊',
    '😍',
    '😘',
    '😎',
    '🥳',
    '😢',
    '😡',
    '👍',
    '👎',
    '👏',
    '🙏',
    '💪',
    '👀',
    '❤️',
    '🔥',
    '✨',
    '🎉',
    '✅',
    '❌',
    '⭐',
    '🔒',
    '☕',
    '🍰',
    '🚀',
    '📎',
    '📷',
    '🎤',
    '📁',
    '💬',
  ];

  final ValueChanged<String> onEmojiSelected;
  final RecentEmojiStore? store;
  final List<String> emoji;

  @override
  State<EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<EmojiPicker> {
  late final RecentEmojiStore _store =
      widget.store ?? InMemoryRecentEmojiStore();
  var _recent = <String>[];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final recent = await _store.loadRecent();
    if (mounted) {
      setState(() => _recent = recent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('emoji-picker'),
      height: 260,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            if (_recent.isNotEmpty) ...[
              _SectionLabel('Recent'),
              _EmojiGrid(emoji: _recent, onTap: _select),
              const SizedBox(height: 8),
            ],
            _SectionLabel('Emoji'),
            _EmojiGrid(emoji: widget.emoji, onTap: _select),
          ],
        ),
      ),
    );
  }

  Future<void> _select(String emoji) async {
    widget.onEmojiSelected(emoji);
    final updated = [emoji, ..._recent.where((item) => item != emoji)].take(24);
    await _store.saveRecent(updated.toList());
    if (mounted) {
      setState(() => _recent = updated.toList());
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _EmojiGrid extends StatelessWidget {
  const _EmojiGrid({required this.emoji, required this.onTap});

  final List<String> emoji;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: emoji.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final value = emoji[index];
        return IconButton(
          tooltip: value,
          onPressed: () => onTap(value),
          icon: Text(value, style: const TextStyle(fontSize: 24)),
        );
      },
    );
  }
}
