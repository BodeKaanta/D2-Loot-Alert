import 'package:flutter/material.dart';

import '../theme.dart';
import '../watch_store.dart';

/// Bell toggle: gold when watching, quiet gray when not. Shows a short message
/// right after each tap. The watch list updates instantly; a background network
/// failure shows its own message later (see main.dart).
class WatchBell extends StatelessWidget {
  const WatchBell({super.key, required this.watching, required this.label, required this.onToggle});

  final bool watching;
  final String label; // what's being watched, e.g. "Spare Rations"
  final Future<WatchResult> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(watching ? Icons.notifications_active : Icons.notifications_none),
      color: watching ? AppColors.exotic : AppColors.textSecondary,
      tooltip: watching ? 'Stop alerts for $label' : 'Alert me about $label',
      onPressed: () async {
        final result = await onToggle();
        if (!context.mounted) return; // the screen may be gone after the await
        final message = switch (result) {
          WatchResult.watching => 'Watching $label. You\'ll get a push when it comes up.',
          WatchResult.stopped => 'Stopped watching $label.',
          WatchResult.noPermission =>
            'Notifications are off for D2 Loot Alert. Turn them on in your phone\'s settings.',
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }
}
