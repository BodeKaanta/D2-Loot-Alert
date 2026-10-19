import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../watch_store.dart';
import 'activity_card.dart';
import 'watch_bell.dart';

/// One exotic armor piece in a bordered box, with its watch bell (#13).
class ArmorRow extends StatelessWidget {
  const ArmorRow({super.key, required this.armor, this.subtitle});

  final ExoticArmor armor;
  final String? subtitle; // "Hunter chest armor" by default

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border)),
        child: ItemRow(
          icon: armor.icon,
          name: armor.name,
          subtitle: subtitle ?? armor.description,
          trailing: ArmorBell(armor: armor),
        ),
      ),
    );
  }
}

/// The watch bell for exotic armor, wired to the shared watch list: a push when Xûr sells it.
class ArmorBell extends StatelessWidget {
  const ArmorBell({super.key, required this.armor});

  final ExoticArmor armor;

  @override
  Widget build(BuildContext context) {
    final watches = WatchScope.of(context);
    return WatchBell(
      watching: watches.isWatchingArmor(armor.id),
      label: armor.name,
      onToggle: () => watches.toggleArmor(armor),
    );
  }
}
