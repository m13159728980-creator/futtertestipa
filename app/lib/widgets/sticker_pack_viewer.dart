import 'package:app/core/constants/sticker_catalog.dart';
import 'package:flutter/material.dart';

class StickerPackViewer extends StatelessWidget {
  const StickerPackViewer({
    required this.onStickerSelected,
    this.packs = officialStickerPacks,
    super.key,
  });

  final List<StickerPack> packs;
  final ValueChanged<StickerItem> onStickerSelected;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      key: const Key('sticker-pack-viewer'),
      length: packs.length,
      child: SizedBox(
        height: 280,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabs: [
                for (final pack in packs)
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified, size: 16),
                        const SizedBox(width: 6),
                        Text(pack.name),
                      ],
                    ),
                  ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final pack in packs)
                    GridView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: pack.stickers.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemBuilder: (context, index) {
                        final sticker = pack.stickers[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => onStickerSelected(sticker),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.sticky_note_2, size: 32),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    sticker.label,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
