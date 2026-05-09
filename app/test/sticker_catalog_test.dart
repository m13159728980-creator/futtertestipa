import 'package:app/core/constants/sticker_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'official sticker catalog exposes backend compatible pack zip paths',
    () {
      expect(officialStickerPacks.first.id, 'pack1');
      expect(officialStickerPacks.first.downloadPath, '/stickers/pack1.zip');
      expect(
        officialStickerPacks.map((pack) => pack.downloadPath),
        containsAll([
          '/stickers/pack1.zip',
          '/stickers/pack2.zip',
          '/stickers/pack3.zip',
        ]),
      );
    },
  );
}
