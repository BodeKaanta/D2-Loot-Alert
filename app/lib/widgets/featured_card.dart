import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../watch_store.dart';
import 'banner_image.dart';
import 'watch_bell.dart';

/// Two-column grid of raids or dungeons, optionally with a watch bell on each.
class FeaturedGrid extends StatelessWidget {
  const FeaturedGrid({super.key, required this.featured, this.showBells = false});

  final List<Featured> featured;
  final bool showBells;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      // The whole screen scrolls as one list, so the grid itself doesn't.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [for (final f in featured) FeaturedCard(featured: f, showBell: showBells)],
    );
  }
}

class FeaturedCard extends StatelessWidget {
  const FeaturedCard({super.key, required this.featured, this.showBell = false});

  final Featured featured;
  final bool showBell;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground, // border drawn over the image
      decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
      child: Stack(
        children: [
          BannerImage(
            url: featured.image,
            // Just the name: the RAIDS / DUNGEONS header above already says what it is.
            child: Text(featured.name.toUpperCase(),
                style: AppText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          if (showBell) Positioned(top: 0, right: 0, child: RaidBell(raid: featured)),
        ],
      ),
    );
  }
}

/// The watch bell for a raid or dungeon, wired to the shared watch list.
class RaidBell extends StatelessWidget {
  const RaidBell({super.key, required this.raid});

  final Featured raid;

  @override
  Widget build(BuildContext context) {
    final watches = WatchScope.of(context);
    return WatchBell(
      watching: watches.isWatchingRaid(raid.id),
      label: raid.name,
      onToggle: () => watches.toggleRaid(raid),
    );
  }
}
