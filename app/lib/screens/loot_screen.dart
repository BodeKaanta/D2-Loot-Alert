import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../watch_store.dart';
import '../widgets/activity_card.dart';
import '../widgets/banner_image.dart';
import '../widgets/page_header.dart';
import '../widgets/section_header.dart';
import 'category_screen.dart';

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
                  help: 'Tap the bell on a weapon to get a push when it\'s a bonus focus drop.',
                ),
                const _WatchingSection(),
                const SizedBox(height: 16),
                const SectionHeader('Categories'),
                for (final loot in categories)
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: _CategoryCard(loot: loot)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Every watched weapon in one place, each with its bell to stop watching.
class _WatchingSection extends StatelessWidget {
  const _WatchingSection();

  @override
  Widget build(BuildContext context) {
    final watched = WatchScope.of(context).weapons;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Watching'),
        if (watched.isEmpty)
          const Text('Nothing yet. Open a category below and tap a bell.', style: AppText.itemType),
        for (final w in watched)
          WeaponRow(
            weapon: w.weapon,
            subtitle: '${w.weapon.type} · ${w.category}',
            trailing: WeaponBell(weapon: w.weapon, category: w.category),
          ),
      ],
    );
  }
}

/// A category banner card; tapping it opens the category's weapons.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.loot});

  final CategoryLoot loot;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
      child: InkWell(
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => CategoryScreen(loot: loot))),
        child: BannerImage(
          url: loot.image,
          height: 88,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loot.category.toUpperCase(), style: AppText.cardTitle),
                    const SizedBox(height: 2),
                    Text('${loot.weapons.length} WEAPONS', style: AppText.label),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
