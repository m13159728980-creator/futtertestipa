import 'package:flutter/material.dart';

enum BurnModeMenuValue {
  seconds5(Duration(seconds: 5)),
  seconds10(Duration(seconds: 10)),
  seconds30(Duration(seconds: 30)),
  seconds60(Duration(seconds: 60)),
  off(null);

  const BurnModeMenuValue(this.duration);

  final Duration? duration;

  static BurnModeMenuValue fromDuration(Duration? duration) {
    for (final value in BurnModeMenuValue.values) {
      if (value.duration == duration) {
        return value;
      }
    }
    return BurnModeMenuValue.off;
  }
}

class BurnModeMenu extends StatelessWidget {
  const BurnModeMenu({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final Duration? selected;
  final ValueChanged<Duration?> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<BurnModeMenuValue>(
      tooltip: 'Burn timer',
      icon: Icon(
        Icons.local_fire_department,
        color: selected == null ? null : Theme.of(context).colorScheme.error,
      ),
      initialValue: BurnModeMenuValue.fromDuration(selected),
      onSelected: (value) => onSelected(value.duration),
      itemBuilder: (context) => const [
        PopupMenuItem(value: BurnModeMenuValue.seconds5, child: Text('5绉?')),
        PopupMenuItem(value: BurnModeMenuValue.seconds10, child: Text('10绉?')),
        PopupMenuItem(value: BurnModeMenuValue.seconds30, child: Text('30绉?')),
        PopupMenuItem(value: BurnModeMenuValue.seconds60, child: Text('1鍒嗛挓')),
        PopupMenuDivider(),
        PopupMenuItem(value: BurnModeMenuValue.off, child: Text('鍏抽棴')),
      ],
    );
  }
}
