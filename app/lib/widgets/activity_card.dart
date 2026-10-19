import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../watch_store.dart';
import 'banner_image.dart';
import 'watch_bell.dart';

/// One activity's card: its banner and name, then its bonus focus weapons.
/// The category isn't repeated here; the section header above shows it.
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.activity});

  final ActivityGroup activity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BannerImage(
            url: activity.image,
            height: 72,
            child: Text(activity.name.toUpperCase(), style: AppText.cardTitle),
          ),
          for (final weapon in activity.weapons)
            WeaponRow(weapon: weapon, trailing: WeaponBell(weapon: weapon, category: activity.category)),
        ],
      ),
    );
  }
}

/// Weapon icon tile plus its name and a subtitle (its type by default),
/// with an optional widget on the right, usually a [WeaponBell].
class WeaponRow extends StatelessWidget {
  const WeaponRow({super.key, required this.weapon, this.subtitle, this.trailing});

  final Weapon weapon;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Row(
        children: [
          ItemTile(url: weapon.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(weapon.name, style: AppText.itemName),
                const SizedBox(height: 2),
                Text(subtitle ?? weapon.type, style: AppText.itemType),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The watch bell for a weapon, wired to the shared watch list.
class WeaponBell extends StatelessWidget {
  const WeaponBell({super.key, required this.weapon, required this.category});

  final Weapon weapon;
  final String category;

  @override
  Widget build(BuildContext context) {
    final watches = WatchScope.of(context);
    return WatchBell(
      watching: watches.isWatchingWeapon(weapon.id),
      label: weapon.name,
      onToggle: () => watches.toggleWeapon(weapon, category),
    );
  }
}

/// Square item icon with a thin light border, like Destiny's inventory tiles.
class ItemTile extends StatelessWidget {
  const ItemTile({super.key, required this.url, this.size = 48});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: AppColors.tileBorder),
      ),
      child: url == null
          ? null
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
    );
  }
}
