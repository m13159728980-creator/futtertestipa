import 'package:app/core/constants/avatar_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('avatar catalog contains exactly nine fixed avatars', () {
    expect(avatarCatalog, hasLength(9));
    expect(
      avatarCatalog.map((avatar) => avatar.index),
      orderedEquals([0, 1, 2, 3, 4, 5, 6, 7, 8]),
    );
  });

  test('avatar catalog entries have labels, icons, and colors', () {
    for (final avatar in avatarCatalog) {
      expect(avatar.label, isNotEmpty);
      expect(avatar.icon.codePoint, isPositive);
      expect(avatar.color, isNot(equals(Colors.transparent)));
    }
  });

  test('avatar catalog matches the fixed icon intent', () {
    expect(avatarByIndex(0).icon, Icons.person);
    expect(avatarByIndex(1).icon, Icons.chat_bubble);
    expect(avatarByIndex(2).icon, Icons.star);
    expect(avatarByIndex(3).icon, Icons.lock);
    expect(avatarByIndex(4).icon, Icons.favorite);
    expect(avatarByIndex(5).icon, Icons.sentiment_satisfied);
    expect(avatarByIndex(6).icon, Icons.local_cafe);
    expect(avatarByIndex(7).icon, Icons.camera_alt);
    expect(avatarByIndex(8).icon, Icons.group);
  });

  test('invalid avatar index falls back to the first avatar', () {
    for (final invalidIndex in [-1, avatarCatalog.length]) {
      final fallback = avatarByIndex(invalidIndex);

      expect(fallback.index, 0);
      expect(fallback.icon, Icons.person);
      expect(fallback.color, Colors.blue);
    }
  });
}
