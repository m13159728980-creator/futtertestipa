import 'package:app/core/constants/avatar_catalog.dart';
import 'package:flutter/material.dart';

class DefaultAvatar extends StatelessWidget {
  const DefaultAvatar({required this.index, this.radius = 24, super.key});

  final int index;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatar = avatarByIndex(index);

    return CircleAvatar(
      radius: radius,
      backgroundColor: avatar.color,
      child: Icon(
        avatar.icon,
        color: Colors.white,
        semanticLabel: avatar.label,
        size: radius,
      ),
    );
  }
}
