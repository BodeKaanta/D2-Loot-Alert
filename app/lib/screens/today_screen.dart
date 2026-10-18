import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/activity_card.dart';
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const _Header(),
        const SizedBox(height: 24),
        const SectionHeader('Bonus focus'),
        if (rotation.activities.isEmpty)
          const Text('No bonus focus weapons right now.', style: AppText.body),
        for (final activity in rotation.activities)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ActivityCard(activity: activity),
          ),
        const SizedBox(height: 12),
        const SectionHeader('Featured this week'),
        FeaturedGrid(featured: rotation.featured),
      ],
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
