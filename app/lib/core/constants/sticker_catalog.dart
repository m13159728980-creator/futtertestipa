class StickerPack {
  const StickerPack({
    required this.id,
    required this.name,
    required this.downloadPath,
    required this.stickers,
    this.official = true,
  });

  final String id;
  final String name;
  final String downloadPath;
  final bool official;
  final List<StickerItem> stickers;
}

class StickerItem {
  const StickerItem({
    required this.id,
    required this.label,
    required this.assetPath,
    required this.remotePath,
  });

  final String id;
  final String label;
  final String assetPath;
  final String remotePath;
}

const officialStickerPacks = <StickerPack>[
  StickerPack(
    id: 'pack1',
    name: 'Gram Basics',
    downloadPath: '/stickers/pack1.zip',
    stickers: [
      StickerItem(
        id: 'pack1_01',
        label: 'Smile',
        assetPath: 'assets/stickers/pack1/01.png',
        remotePath: '/stickers/pack1/01.png',
      ),
      StickerItem(
        id: 'pack1_02',
        label: 'Wave',
        assetPath: 'assets/stickers/pack1/02.png',
        remotePath: '/stickers/pack1/02.png',
      ),
      StickerItem(
        id: 'pack1_03',
        label: 'Thanks',
        assetPath: 'assets/stickers/pack1/03.png',
        remotePath: '/stickers/pack1/03.png',
      ),
      StickerItem(
        id: 'pack1_04',
        label: 'OK',
        assetPath: 'assets/stickers/pack1/04.png',
        remotePath: '/stickers/pack1/04.png',
      ),
      StickerItem(
        id: 'pack1_05',
        label: 'Laugh',
        assetPath: 'assets/stickers/pack1/05.png',
        remotePath: '/stickers/pack1/05.png',
      ),
      StickerItem(
        id: 'pack1_06',
        label: 'Wow',
        assetPath: 'assets/stickers/pack1/06.png',
        remotePath: '/stickers/pack1/06.png',
      ),
      StickerItem(
        id: 'pack1_07',
        label: 'Sad',
        assetPath: 'assets/stickers/pack1/07.png',
        remotePath: '/stickers/pack1/07.png',
      ),
      StickerItem(
        id: 'pack1_08',
        label: 'Angry',
        assetPath: 'assets/stickers/pack1/08.png',
        remotePath: '/stickers/pack1/08.png',
      ),
      StickerItem(
        id: 'pack1_09',
        label: 'Heart',
        assetPath: 'assets/stickers/pack1/09.png',
        remotePath: '/stickers/pack1/09.png',
      ),
      StickerItem(
        id: 'pack1_10',
        label: 'Fire',
        assetPath: 'assets/stickers/pack1/10.png',
        remotePath: '/stickers/pack1/10.png',
      ),
      StickerItem(
        id: 'pack1_11',
        label: 'Lock',
        assetPath: 'assets/stickers/pack1/11.png',
        remotePath: '/stickers/pack1/11.png',
      ),
      StickerItem(
        id: 'pack1_12',
        label: 'Key',
        assetPath: 'assets/stickers/pack1/12.png',
        remotePath: '/stickers/pack1/12.png',
      ),
      StickerItem(
        id: 'pack1_13',
        label: 'Coffee',
        assetPath: 'assets/stickers/pack1/13.png',
        remotePath: '/stickers/pack1/13.png',
      ),
      StickerItem(
        id: 'pack1_14',
        label: 'Cake',
        assetPath: 'assets/stickers/pack1/14.png',
        remotePath: '/stickers/pack1/14.png',
      ),
      StickerItem(
        id: 'pack1_15',
        label: 'Star',
        assetPath: 'assets/stickers/pack1/15.png',
        remotePath: '/stickers/pack1/15.png',
      ),
      StickerItem(
        id: 'pack1_16',
        label: 'Party',
        assetPath: 'assets/stickers/pack1/16.png',
        remotePath: '/stickers/pack1/16.png',
      ),
    ],
  ),
  StickerPack(
    id: 'pack2',
    name: 'Secure Mood',
    downloadPath: '/stickers/pack2.zip',
    stickers: [
      StickerItem(
        id: 'pack2_01',
        label: 'Shield',
        assetPath: 'assets/stickers/pack2/01.png',
        remotePath: '/stickers/pack2/01.png',
      ),
      StickerItem(
        id: 'pack2_02',
        label: 'Private',
        assetPath: 'assets/stickers/pack2/02.png',
        remotePath: '/stickers/pack2/02.png',
      ),
      StickerItem(
        id: 'pack2_03',
        label: 'Verified',
        assetPath: 'assets/stickers/pack2/03.png',
        remotePath: '/stickers/pack2/03.png',
      ),
      StickerItem(
        id: 'pack2_04',
        label: 'Hidden',
        assetPath: 'assets/stickers/pack2/04.png',
        remotePath: '/stickers/pack2/04.png',
      ),
      StickerItem(
        id: 'pack2_05',
        label: 'Clock',
        assetPath: 'assets/stickers/pack2/05.png',
        remotePath: '/stickers/pack2/05.png',
      ),
      StickerItem(
        id: 'pack2_06',
        label: 'Burn',
        assetPath: 'assets/stickers/pack2/06.png',
        remotePath: '/stickers/pack2/06.png',
      ),
      StickerItem(
        id: 'pack2_07',
        label: 'Cloud',
        assetPath: 'assets/stickers/pack2/07.png',
        remotePath: '/stickers/pack2/07.png',
      ),
      StickerItem(
        id: 'pack2_08',
        label: 'Offline',
        assetPath: 'assets/stickers/pack2/08.png',
        remotePath: '/stickers/pack2/08.png',
      ),
      StickerItem(
        id: 'pack2_09',
        label: 'Ping',
        assetPath: 'assets/stickers/pack2/09.png',
        remotePath: '/stickers/pack2/09.png',
      ),
      StickerItem(
        id: 'pack2_10',
        label: 'Sent',
        assetPath: 'assets/stickers/pack2/10.png',
        remotePath: '/stickers/pack2/10.png',
      ),
      StickerItem(
        id: 'pack2_11',
        label: 'Read',
        assetPath: 'assets/stickers/pack2/11.png',
        remotePath: '/stickers/pack2/11.png',
      ),
      StickerItem(
        id: 'pack2_12',
        label: 'Muted',
        assetPath: 'assets/stickers/pack2/12.png',
        remotePath: '/stickers/pack2/12.png',
      ),
      StickerItem(
        id: 'pack2_13',
        label: 'Search',
        assetPath: 'assets/stickers/pack2/13.png',
        remotePath: '/stickers/pack2/13.png',
      ),
      StickerItem(
        id: 'pack2_14',
        label: 'Backup',
        assetPath: 'assets/stickers/pack2/14.png',
        remotePath: '/stickers/pack2/14.png',
      ),
      StickerItem(
        id: 'pack2_15',
        label: 'Device',
        assetPath: 'assets/stickers/pack2/15.png',
        remotePath: '/stickers/pack2/15.png',
      ),
      StickerItem(
        id: 'pack2_16',
        label: 'Done',
        assetPath: 'assets/stickers/pack2/16.png',
        remotePath: '/stickers/pack2/16.png',
      ),
    ],
  ),
  StickerPack(
    id: 'pack3',
    name: 'Daily Signals',
    downloadPath: '/stickers/pack3.zip',
    stickers: [
      StickerItem(
        id: 'pack3_01',
        label: 'Morning',
        assetPath: 'assets/stickers/pack3/01.png',
        remotePath: '/stickers/pack3/01.png',
      ),
      StickerItem(
        id: 'pack3_02',
        label: 'Night',
        assetPath: 'assets/stickers/pack3/02.png',
        remotePath: '/stickers/pack3/02.png',
      ),
      StickerItem(
        id: 'pack3_03',
        label: 'Work',
        assetPath: 'assets/stickers/pack3/03.png',
        remotePath: '/stickers/pack3/03.png',
      ),
      StickerItem(
        id: 'pack3_04',
        label: 'Home',
        assetPath: 'assets/stickers/pack3/04.png',
        remotePath: '/stickers/pack3/04.png',
      ),
      StickerItem(
        id: 'pack3_05',
        label: 'Busy',
        assetPath: 'assets/stickers/pack3/05.png',
        remotePath: '/stickers/pack3/05.png',
      ),
      StickerItem(
        id: 'pack3_06',
        label: 'Free',
        assetPath: 'assets/stickers/pack3/06.png',
        remotePath: '/stickers/pack3/06.png',
      ),
      StickerItem(
        id: 'pack3_07',
        label: 'Call',
        assetPath: 'assets/stickers/pack3/07.png',
        remotePath: '/stickers/pack3/07.png',
      ),
      StickerItem(
        id: 'pack3_08',
        label: 'Photo',
        assetPath: 'assets/stickers/pack3/08.png',
        remotePath: '/stickers/pack3/08.png',
      ),
      StickerItem(
        id: 'pack3_09',
        label: 'File',
        assetPath: 'assets/stickers/pack3/09.png',
        remotePath: '/stickers/pack3/09.png',
      ),
      StickerItem(
        id: 'pack3_10',
        label: 'Map',
        assetPath: 'assets/stickers/pack3/10.png',
        remotePath: '/stickers/pack3/10.png',
      ),
      StickerItem(
        id: 'pack3_11',
        label: 'Money',
        assetPath: 'assets/stickers/pack3/11.png',
        remotePath: '/stickers/pack3/11.png',
      ),
      StickerItem(
        id: 'pack3_12',
        label: 'Gift',
        assetPath: 'assets/stickers/pack3/12.png',
        remotePath: '/stickers/pack3/12.png',
      ),
      StickerItem(
        id: 'pack3_13',
        label: 'Idea',
        assetPath: 'assets/stickers/pack3/13.png',
        remotePath: '/stickers/pack3/13.png',
      ),
      StickerItem(
        id: 'pack3_14',
        label: 'Bug',
        assetPath: 'assets/stickers/pack3/14.png',
        remotePath: '/stickers/pack3/14.png',
      ),
      StickerItem(
        id: 'pack3_15',
        label: 'Rocket',
        assetPath: 'assets/stickers/pack3/15.png',
        remotePath: '/stickers/pack3/15.png',
      ),
      StickerItem(
        id: 'pack3_16',
        label: 'Flag',
        assetPath: 'assets/stickers/pack3/16.png',
        remotePath: '/stickers/pack3/16.png',
      ),
    ],
  ),
];
