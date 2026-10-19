import 'dart:math';

import 'package:flutter/material.dart';

/// Bungie's activity art with a dark gradient on top so the text over it stays
/// readable on any image. With no [url] (or if it fails to load) it's just dark.
class BannerImage extends StatelessWidget {
  const BannerImage({
    super.key,
    required this.url,
    required this.child,
    this.height,
    this.alignment = Alignment.center,
    this.zoom = 1,
  });

  final String? url;
  final Widget child;

  /// Which part of the image stays in view when the strip crops it. Centered by
  /// default; e.g. Xûr's card sits higher so his head isn't cut off (#13).
  final Alignment alignment;

  /// Extra zoom on top of filling the strip, around [alignment]. For a picture
  /// whose subject is smaller than its neighbours', e.g. a full-body render
  /// next to close-ups (the Warlock card, #13).
  final double zoom;

  /// Fixed height, or null to fill the parent (e.g. a grid cell).
  final double? height;

  @override
  Widget build(BuildContext context) {
    final url = this.url; // local copy so Dart can promote it to non-null below
    final banner = LayoutBuilder(
      builder: (context, size) => Stack(
        fit: StackFit.expand,
        children: [
          if (url != null) _picture(context, size, url),
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

  Widget _picture(BuildContext context, BoxConstraints size, String url) {
    final decodeWidth = _decodeWidth(context, size);
    final picture = Image.network(
      url,
      fit: BoxFit.cover,
      alignment: alignment,
      // Bungie's banners are ~1920 px wide but shown in a strip or grid cell.
      // Decoding at the shown size saves decode time and memory (#20); a zoomed
      // picture needs that many times more pixels to stay sharp.
      cacheWidth: decodeWidth == null ? null : (decodeWidth * zoom).round(),
      errorBuilder: (_, _, _) => const SizedBox(),
    );
    if (zoom == 1) return picture;
    // Scaling doesn't change the picture's layout size, so clip it to the card.
    return ClipRect(child: Transform.scale(scale: zoom, alignment: alignment, child: picture));
  }

  /// Pixels wide to decode at. `BoxFit.cover` on a box taller than the image's
  /// 16:9 shape (the grid cells) scales by height, so allow for that too.
  static int? _decodeWidth(BuildContext context, BoxConstraints size) {
    final coverWidth = size.maxHeight.isFinite ? max(size.maxWidth, size.maxHeight * 16 / 9) : size.maxWidth;
    if (!coverWidth.isFinite) return null; // unknown size: decode as is
    return (coverWidth * MediaQuery.devicePixelRatioOf(context)).round();
  }
}
