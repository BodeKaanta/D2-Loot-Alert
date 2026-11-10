import 'dart:async';

import 'package:flutter/material.dart';

/// A network image that tries again when its download fails (#43).
///
/// Flutter's `Image.network` downloads once. If that fails (the app opened during
/// a network blip, or Bungie's server hiccupped), it shows its error widget and
/// never tries again: rebuilding it with the same URL counts as "nothing changed".
/// The image stayed blank until the app was restarted, which hid every Bungie
/// image on the iPad on 2026-11-09.
///
/// This retries after 2, 4, 8, 16 and 32 seconds (about a minute), then stops so a
/// truly broken link isn't fetched forever. Coming back to the app retries too,
/// since the connection may be back by then.
class RetryingNetworkImage extends StatefulWidget {
  const RetryingNetworkImage(
    this.url, {
    super.key,
    this.fit,
    this.alignment = Alignment.center,
    this.cacheWidth,
  });

  final String url;
  final BoxFit? fit;
  final Alignment alignment;

  /// Decode at this many pixels wide instead of the full image (see BannerImage).
  final int? cacheWidth;

  /// How many times a failed image is retried before giving up until the app
  /// comes back to the foreground.
  static const maxRetries = 5;

  @override
  State<RetryingNetworkImage> createState() => _RetryingNetworkImageState();
}

class _RetryingNetworkImageState extends State<RetryingNetworkImage> with WidgetsBindingObserver {
  /// Bumped on each retry. It's the inner Image's key, so a new value makes
  /// Flutter build a fresh Image, which starts a new download.
  int _attempt = 0;

  /// The current attempt has failed (and a retry may be scheduled).
  bool _failed = false;
  Timer? _retryTimer;

  /// The same provider `Image.network` builds: the URL, resized when cacheWidth is set.
  ImageProvider get _provider => ResizeImage.resizeIfNeeded(widget.cacheWidth, null, NetworkImage(widget.url));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // to hear when the app comes back
  }

  @override
  void didUpdateWidget(RetryingNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      // A different picture: start over with a full set of retries.
      _retryTimer?.cancel();
      _attempt = 0;
      _failed = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel(); // no retries for a picture that's gone off screen
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _failed) {
      _retryTimer?.cancel();
      _retry();
    }
  }

  /// Called by the Image's errorBuilder, during a build, so it must not call
  /// setState itself. It only schedules the retry.
  void _onError() {
    if (_failed) return; // this attempt's failure is already handled
    _failed = true;
    if (_attempt >= RetryingNetworkImage.maxRetries) return; // wait for the app to come back
    _retryTimer = Timer(Duration(seconds: 2 << _attempt), _retry); // 2, 4, 8, 16, 32 s
  }

  Future<void> _retry() async {
    // Drop the failed image from Flutter's image cache, so the new Image
    // downloads it again instead of reusing the failure.
    await _provider.evict();
    if (!mounted) return;
    setState(() {
      _attempt++;
      _failed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Image(
      key: ValueKey(_attempt),
      image: _provider,
      fit: widget.fit,
      alignment: widget.alignment,
      errorBuilder: (_, _, _) {
        _onError();
        return const SizedBox(); // blank (the card's dark background) until it loads
      },
    );
  }
}
