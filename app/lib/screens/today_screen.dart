import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../watch_store.dart';
import '../widgets/activity_card.dart';
import '../widgets/armor_row.dart';
import '../widgets/featured_card.dart';
import '../widgets/reset_countdown.dart';
import '../widgets/section_header.dart';
import 'about_screen.dart';

/// Home screen: today's bonus focus weapons and this week's featured raids and dungeons.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  static final _rotationDoc = FirebaseFirestore.instance.doc('rotation/current');

  /// Pull-to-refresh: ask the server directly. The stream below picks up any change.
  Future<void> _refresh() async {
    await _rotationDoc.get(const GetOptions(source: Source.server));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // A live listener: when the backend writes a new rotation, the screen updates itself.
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _rotationDoc.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _CenteredMessage("Couldn't load today's rotation. Check your connection.");
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }
            final data = snapshot.data!.data();
            if (data == null) {
              return const _CenteredMessage('No rotation yet. Check back after reset.');
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.textPrimary,
              backgroundColor: AppColors.surface,
              child: _RotationList(rotation: Rotation.fromMap(data)),
            );
          },
        ),
      ),
    );
  }
}

class _RotationList extends StatelessWidget {
  const _RotationList({required this.rotation});

  final Rotation rotation;

  @override
  Widget build(BuildContext context) {
    final raids = rotation.featured.where((f) => f.kind == 'raid').toList();
    final dungeons = rotation.featured.where((f) => f.kind == 'dungeon').toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const _Header(),
        // A gold line between the countdown and the content (Bode, #34). The gold
        // sets it apart from the section headers' grey rules. 1.5 pt was Bode's
        // pick after trying 1, 2 and 4.
        const SizedBox(height: 20),
        const Divider(color: AppColors.exotic, thickness: 1.5, height: 1.5),
        const SizedBox(height: 24),
        // Always one child, even when empty: if it changes while you're scrolled
        // further down, the list only lays out what's on screen, so nothing jumps.
        _ReadyToFarm(rotation: rotation),
        const _GroupTitle('Bonus focus'),
        if (rotation.activities.isEmpty)
          const Text('No bonus focus weapons right now.', style: AppText.body),
        // One section per in-game Portal category, like the game's own screens.
        for (final MapEntry(key: category, value: activities)
            in groupByCategory(rotation.activities).entries) ...[
          SectionHeader(category),
          for (final activity in activities)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ActivityCard(activity: activity),
            ),
          const SizedBox(height: 16), // breathing room so each category starts clearly
        ],
        const SizedBox(height: 16),
        const _GroupTitle('Featured this week'),
        if (raids.isNotEmpty) ...[
          const SectionHeader('Raids'),
          FeaturedGrid(featured: raids, showBells: true),
          const SizedBox(height: 20),
        ],
        if (dungeons.isNotEmpty) ...[
          const SectionHeader('Dungeons'),
          FeaturedGrid(featured: dungeons, showBells: true),
        ],
        // Only while he's in the game, Friday to the Tuesday reset (#13).
        if (rotation.xur.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionHeader('Xûr'),
          for (final armor in rotation.xur) ArmorRow(armor: armor),
        ],
      ],
    );
  }
}

/// READY TO FARM (#34): copies of everything you watch that can be farmed right
/// now, so it's at the top instead of spread down the page. Hidden when there's
/// nothing. Reading WatchScope means it updates as soon as a bell is tapped.
class _ReadyToFarm extends StatelessWidget {
  const _ReadyToFarm({required this.rotation});

  final Rotation rotation;

  @override
  Widget build(BuildContext context) {
    final watches = WatchScope.of(context);
    final ready = ReadyToFarm.from(
      rotation,
      watchingWeapon: watches.isWatchingWeapon,
      watchingRaid: watches.isWatchingRaid,
      watchingArmor: watches.isWatchingArmor,
    );
    if (ready.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _GroupTitle('Ready to farm'),
        for (final activity in ready.activities)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ActivityCard(activity: activity, showCategory: true),
          ),
        if (ready.featured.isNotEmpty) ...[
          FeaturedGrid(featured: ready.featured, showBells: true, showKind: true),
          const SizedBox(height: 12),
        ],
        for (final armor in ready.armor) ArmorRow(armor: armor, subtitle: '${armor.description} · Xûr'),
        const SizedBox(height: 28),
      ],
    );
  }
}

/// "READY TO FARM" / "BONUS FOCUS" / "FEATURED THIS WEEK": the big parts of the screen.
class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title.toUpperCase(), style: AppText.groupTitle),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('D2 LOOT ALERT', style: AppText.appTitle),
              SizedBox(height: 4),
              ResetCountdown(),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.info_outline),
          color: AppColors.textSecondary,
          tooltip: 'About',
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const AboutScreen())),
        ),
      ],
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text, style: AppText.body, textAlign: TextAlign.center),
      ),
    );
  }
}
