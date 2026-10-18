import 'dart:math';

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
    final banner = LayoutBuilder(
      builder: (context, size) => Stack(
        fit: StackFit.expand,
        children: [
          if (url != null)
            Image.network(
              url,
              fit: BoxFit.cover,
              // Bungie's banners are ~1920 px wide but shown in a strip or grid cell.
              // Decoding at the shown size saves decode time and memory (#20).
              cacheWidth: _decodeWidth(context, size),
              errorBuilder: (_, _, _) => const SizedBox(),
            ),
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
      ),
    );
    return height == null ? SizedBox.expand(child: banner) : SizedBox(height: height, child: banner);
  }

  /// Pixels wide to decode at. `BoxFit.cover` on a box taller than the image's
  /// 16:9 shape (the grid cells) scales by height, so allow for that too.
  static int? _decodeWidth(BuildContext context, BoxConstraints size) {
    final coverWidth = size.maxHeight.isFinite ? max(size.maxWidth, size.maxHeight * 16 / 9) : size.maxWidth;
    if (!coverWidth.isFinite) return null; // unknown size: decode as is
    return (coverWidth * MediaQuery.devicePixelRatioOf(context)).round();
  }
}
