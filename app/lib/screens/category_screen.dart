import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/activity_card.dart';

/// One Portal category's loot pool, each weapon with a watch bell.
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key, required this.loot});

  final CategoryLoot loot;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(loot.category.toUpperCase())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Any of these can be a ${loot.category} bonus focus. Tap a bell to get a push when it is.',
              style: AppText.itemType,
            ),
          ),
          for (final w in loot.weapons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                ),
                child: WeaponRow(
                  weapon: w.weapon,
                  // Weapons outside the category's main pool say where they drop.
                  subtitle: w.onlyIn.isEmpty
                      ? w.weapon.type
                      : '${w.weapon.type} · ${w.onlyIn.join(', ')} only',
                  trailing: WeaponBell(weapon: w.weapon, category: loot.category),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
