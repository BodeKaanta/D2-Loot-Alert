import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/banner_image.dart';
import '../widgets/featured_card.dart';
import '../widgets/page_header.dart';
import '../widgets/section_header.dart';

/// RAIDS & DUNGEONS tab: this week's featured (farmable) ones first, then every
/// raid and dungeon that can rotate in, each with a watch bell.
class RaidsScreen extends StatelessWidget {
  const RaidsScreen({super.key});

  static final _rotationDoc = FirebaseFirestore.instance.doc('rotation/current');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _rotationDoc.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text("Couldn't load raids and dungeons.", style: AppText.body));
            }
            final data = snapshot.data?.data();
            if (data == null) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }
            final rotation = Rotation.fromMap(data);
            final featuredIds = {for (final f in rotation.featured) f.id};
            final raids = rotation.raidsAndDungeons.where((r) => r.kind == 'raid').toList();
            final dungeons = rotation.raidsAndDungeons.where((r) => r.kind == 'dungeon').toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                const PageHeader(
                  title: 'Raids & Dungeons',
                  help: 'Tap a bell to get a push the week it\'s featured and farmable.',
                ),
                const SectionHeader('Featured this week'),
                FeaturedGrid(featured: rotation.featured, showBells: true),
                const SizedBox(height: 28),
                const SectionHeader('All raids'),
                for (final raid in raids) _RaidRow(raid: raid, featured: featuredIds.contains(raid.id)),
                const SizedBox(height: 20),
                const SectionHeader('All dungeons'),
                for (final dungeon in dungeons)
                  _RaidRow(raid: dungeon, featured: featuredIds.contains(dungeon.id)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A slim banner row: name (plus "Featured this week" when it is) and a bell.
class _RaidRow extends StatelessWidget {
  const _RaidRow({required this.raid, required this.featured});

  final Featured raid;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
        child: BannerImage(
          url: raid.image,
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(raid.name.toUpperCase(), style: AppText.cardTitle),
                    if (featured)
                      Text('FEATURED THIS WEEK', style: AppText.label.copyWith(color: AppColors.exotic)),
                  ],
                ),
              ),
              RaidBell(raid: raid),
            ],
          ),
        ),
      ),
    );
  }
}
