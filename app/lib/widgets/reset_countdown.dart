import 'dart:async';

import 'package:flutter/material.dart';

import '../reset.dart';
import '../theme.dart';

/// "RESETS IN 14H 03M", refreshed every minute.
class ResetCountdown extends StatefulWidget {
  const ResetCountdown({super.key});

  @override
  State<ResetCountdown> createState() => _ResetCountdownState();
}

class _ResetCountdownState extends State<ResetCountdown> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel(); // stop ticking once the widget is gone
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remaining = nextDailyReset(now).difference(now.toUtc());
    return Text('RESETS IN ${formatCountdown(remaining)}', style: AppText.label);
  }
}
