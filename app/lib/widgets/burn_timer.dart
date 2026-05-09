import 'dart:async';

import 'package:flutter/material.dart';

class BurnTimer extends StatefulWidget {
  const BurnTimer({
    required this.duration,
    required this.onExpired,
    this.startedAt,
    super.key,
  });

  final Duration duration;
  final DateTime? startedAt;
  final VoidCallback onExpired;

  @override
  State<BurnTimer> createState() => _BurnTimerState();
}

class _BurnTimerState extends State<BurnTimer> {
  late DateTime _startedAt;
  late int _remainingSeconds;
  Timer? _timer;
  bool _didExpire = false;

  @override
  void initState() {
    super.initState();
    _startedAt = widget.startedAt ?? DateTime.now();
    _remainingSeconds = _initialRemainingSeconds();
    _maybeExpire();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant BurnTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration ||
        oldWidget.startedAt != widget.startedAt) {
      _startedAt = widget.startedAt ?? DateTime.now();
      _didExpire = false;
      _remainingSeconds = _initialRemainingSeconds();
      _maybeExpire();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) {
      return;
    }
    setState(() {
      if (_remainingSeconds > 0) {
        _remainingSeconds -= 1;
      }
    });
    _maybeExpire();
  }

  int _initialRemainingSeconds() {
    final elapsed = DateTime.now().difference(_startedAt).inSeconds;
    final remaining = widget.duration.inSeconds - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  void _maybeExpire() {
    if (_remainingSeconds > 0 || _didExpire) {
      return;
    }
    _didExpire = true;
    widget.onExpired();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${_remainingSeconds}s',
      style: Theme.of(context).textTheme.labelSmall,
    );
  }
}
