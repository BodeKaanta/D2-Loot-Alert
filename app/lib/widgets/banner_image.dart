import 'package:flutter/material.dart';

/// Bungie's activity art with a dark gradient on top so the text over it stays
/// readable on any image. With no [url] (or if it fails to load) it's just dark.
class BannerImage extends StatelessWidget {
  const BannerImage({super.key, required this.url, required this.child, this.height});

  final String? url;
  final Widget child;

  /// Fixed height, or null to fill the parent (e.g. a grid cell).
  final double? height;

  @override
  Widget build(BuildContext context) {
    final url = this.url; // local copy so Dart can promote it to non-null below
    final banner = Stack(
      fit: StackFit.expand,
      children: [
        if (url != null)
          Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x59000000), Color(0xE6000000)], // 35% -> 90% black
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(alignment: Alignment.bottomLeft, child: child),
        ),
      ],
    );
    return height == null ? SizedBox.expand(child: banner) : SizedBox(height: height, child: banner);
  }
}
