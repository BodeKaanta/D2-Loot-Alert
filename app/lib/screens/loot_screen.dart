import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../watch_store.dart';
import '../widgets/activity_card.dart';
import '../widgets/armor_row.dart';
import '../widgets/link_card.dart';
import '../widgets/page_header.dart';
import '../widgets/section_header.dart';
import 'category_screen.dart';
import 'xur_screen.dart';

/// LOOT tab: what you're watching, then each Portal category's loot pool.
class LootScreen extends StatelessWidget {
  const LootScreen({super.key});

  static final _pools = FirebaseFirestore.instance.collection('lootPools');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // The pools only change after a game update, but a live listener costs nothing extra.
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _pools.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text("Couldn't load the loot pools.", style: AppText.body));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }
            final categories =
                buildCategoryLoot([for (final doc in snapshot.data!.docs) LootPool.fromMap(doc.data())]);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                const PageHeader(
                  title: 'Loot',
                  help: 'Tap the bell on a weapon to get a push when it\'s a bonus focus drop, '
                      'or on exotic armor for a push when Xûr sells it.',
                ),
                const _WatchingSection(),
                const SizedBox(height: 16),
                const SectionHeader('Categories'),
                for (final loot in categories)
                  LinkCard(
                    title: loot.category,
                    label: '${loot.weapons.length} weapons',
                    image: loot.image,
                    destination: (_) => CategoryScreen(loot: loot),
                  ),
                // Not a Portal category, but browsed the same way (#13).
                const _XurCard(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The XÛR card, with Xûr's own image from the exotic armor catalog (#13).
class _XurCard extends StatelessWidget {
  const _XurCard();

  static final _catalog = FirebaseFirestore.instance.doc('catalog/exoticArmor');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _catalog.snapshots(),
      // Until the catalog loads (or if it fails), the card still works, just without art.
      builder: (context, snapshot) => LinkCard(
        title: 'Xûr',
        label: 'Exotic armor',
        image: ExoticArmorCatalog.fromMap(snapshot.data?.data()).xurImage,
        // His face sits in the upper part of the image, so the strip shows that part
        // instead of the middle (Bode: the top of his head was cut off).
        imageAlignment: const Alignment(0, -0.6),
        destination: (_) => const XurScreen(),
      ),
    );
  }
}

/// Everything watched in one place, each with its bell to stop watching.
class _WatchingSection extends StatelessWidget {
  const _WatchingSection();

  @override
  Widget build(BuildContext context) {
    final watches = WatchScope.of(context);
    final weapons = watches.weapons;
    final armor = watches.armor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Watching'),
        if (weapons.isEmpty && armor.isEmpty)
          const Text('Nothing yet. Open a category below and tap a bell.', style: AppText.itemType),
        for (final w in weapons)
          WeaponRow(
            weapon: w.weapon,
            subtitle: '${w.weapon.type} · ${w.category}',
            trailing: WeaponBell(weapon: w.weapon, category: w.category),
          ),
        for (final a in armor)
          ItemRow(icon: a.icon, name: a.name, subtitle: '${a.description} · Xûr', trailing: ArmorBell(armor: a)),
      ],
    );
  }
}
