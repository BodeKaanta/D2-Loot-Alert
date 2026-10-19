import 'package:flutter/material.dart';

import '../theme.dart';
import 'banner_image.dart';

/// A banner card that opens another screen: a Portal category's weapons on LOOT,
/// Xûr's armor, or one class's exotics (#13).
class LinkCard extends StatelessWidget {
  const LinkCard({
    super.key,
    required this.title,
    required this.label,
    required this.destination,
    this.image,
    this.imageAlignment = Alignment.center,
    this.imageZoom = 1,
  });

  final String title;
  final String label;
  final String? image; // none: a plain dark banner
  final Alignment imageAlignment; // see BannerImage.alignment
  final double imageZoom; // see BannerImage.zoom
  final WidgetBuilder destination;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: destination)),
          child: BannerImage(
            url: image,
            alignment: imageAlignment,
            zoom: imageZoom,
            height: 88,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title.toUpperCase(), style: AppText.cardTitle),
                      const SizedBox(height: 2),
                      Text(label.toUpperCase(), style: AppText.label),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
