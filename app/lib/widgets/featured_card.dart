import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'banner_image.dart';

/// Two-column grid of this week's featured raids and dungeons.
class FeaturedGrid extends StatelessWidget {
  const FeaturedGrid({super.key, required this.featured});

  final List<Featured> featured;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      // The whole Today screen scrolls as one list, so the grid itself doesn't.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [for (final f in featured) FeaturedCard(featured: f)],
    );
  }
}

class FeaturedCard extends StatelessWidget {
  const FeaturedCard({super.key, required this.featured});

  final Featured featured;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground, // border drawn over the image
      decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
      child: BannerImage(
        url: featured.image,
        // Just the name: the RAIDS / DUNGEONS header above already says what it is.
        child: Text(featured.name.toUpperCase(),
            style: AppText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
