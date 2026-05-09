import 'package:flutter/material.dart';

class AvatarCatalogEntry {
  const AvatarCatalogEntry({
    required this.index,
    required this.label,
    required this.icon,
    required this.color,
  });

  final int index;
  final String label;
  final IconData icon;
  final Color color;
}

const List<AvatarCatalogEntry> avatarCatalog = [
  AvatarCatalogEntry(
    index: 0,
    label: 'Person',
    icon: Icons.person,
    color: Colors.blue,
  ),
  AvatarCatalogEntry(
    index: 1,
    label: 'Chat',
    icon: Icons.chat_bubble,
    color: Colors.green,
  ),
  AvatarCatalogEntry(
    index: 2,
    label: 'Star',
    icon: Icons.star,
    color: Colors.orange,
  ),
  AvatarCatalogEntry(
    index: 3,
    label: 'Lock',
    icon: Icons.lock,
    color: Colors.purple,
  ),
  AvatarCatalogEntry(
    index: 4,
    label: 'Heart',
    icon: Icons.favorite,
    color: Colors.red,
  ),
  AvatarCatalogEntry(
    index: 5,
    label: 'Smile',
    icon: Icons.sentiment_satisfied,
    color: Colors.yellow,
  ),
  AvatarCatalogEntry(
    index: 6,
    label: 'Coffee',
    icon: Icons.local_cafe,
    color: Colors.brown,
  ),
  AvatarCatalogEntry(
    index: 7,
    label: 'Camera',
    icon: Icons.camera_alt,
    color: Colors.grey,
  ),
  AvatarCatalogEntry(
    index: 8,
    label: 'Group',
    icon: Icons.group,
    color: Colors.cyan,
  ),
];

AvatarCatalogEntry avatarByIndex(int index) {
  if (index < 0 || index >= avatarCatalog.length) {
    return avatarCatalog.first;
  }

  return avatarCatalog[index];
}
