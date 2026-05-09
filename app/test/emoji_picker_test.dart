import 'dart:io';

import 'package:app/widgets/emoji_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('emoji_picker_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('default emoji are real unicode emoji', () {
    expect(
      EmojiPicker.defaultEmoji,
      containsAll(['🙂', '😂', '😍', '👍', '❤️', '🔥', '✅', '🎉']),
    );
    expect(EmojiPicker.defaultEmoji, isNot(contains('馃榾')));
  });

  test('file recent emoji store persists the most recent 24 emoji', () async {
    final first = FileRecentEmojiStore(directory: tempDir);
    final emoji = List<String>.generate(30, (index) => 'emoji-$index');

    await first.saveRecent(emoji);
    final second = FileRecentEmojiStore(directory: tempDir);

    expect(await second.loadRecent(), emoji.take(24));
    expect(
      await File(p.join(tempDir.path, 'recent_emoji.json')).exists(),
      isTrue,
    );
  });

  testWidgets(
    'emoji picker loads recent emoji after store and widget recreation',
    (tester) async {
      final firstStore = FileRecentEmojiStore(directory: tempDir);
      final selected = <String>[];
      await firstStore.saveRecent(['🙂']);
      expect(await firstStore.loadRecent(), ['🙂']);

      final recreatedStore = FileRecentEmojiStore(directory: tempDir);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmojiPicker(
              store: recreatedStore,
              emoji: const ['😂'],
              onEmojiSelected: selected.add,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('🙂'), findsOneWidget);
    },
  );
}
