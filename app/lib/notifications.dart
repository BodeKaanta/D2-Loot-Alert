import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Android alerts arrive as FCM data messages, and the app draws them itself (#30):
// the weapon icon when collapsed, the activity's banner when expanded. FCM's own
// notifications have room for one image, used for both.
//
// iPhones still get their alerts straight from APNs, so everything here is
// Android-only for now (#31 adds the banner on iOS).

final _plugin = FlutterLocalNotificationsPlugin();

const _settings = InitializationSettings(
  android: AndroidInitializationSettings('@mipmap/ic_launcher'), // the small status bar icon
);

/// Our own channel instead of FCM's "Misc". High importance makes alerts pop up.
/// AndroidManifest.xml points FCM's own notifications (console tests) here too.
const _channel = AndroidNotificationChannel(
  'bonus_drops',
  'Bonus drops',
  description: 'Watched weapons that are a bonus focus today, and watched raids and dungeons '
      'that are featured this week.',
  importance: Importance.high,
);

final _taps = StreamController<String?>.broadcast();

/// The `kind` ("weapon", "raid", "dungeon") of each alert tapped while the app
/// is running, so HomeScreen can open the right tab.
Stream<String?> get alertTaps => _taps.stream;

/// Called once from main(). Creates the channel up front, so it's in the
/// phone's settings before the first alert, and shows alerts that arrive while
/// the app is open (Android never shows those on its own).
Future<void> initAlertNotifications() async {
  if (!Platform.isAndroid) return;
  await _plugin.initialize(
    settings: _settings,
    onDidReceiveNotificationResponse: (response) => _taps.add(response.payload),
  );
  await _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);
  FirebaseMessaging.onMessage.listen(showAlert);
}

/// The `kind` of the alert whose tap launched the app, if one did.
Future<String?> launchedFromAlert() async {
  if (!Platform.isAndroid) return null;
  final details = await _plugin.getNotificationAppLaunchDetails();
  if (details == null || !details.didNotificationLaunchApp) return null;
  return details.notificationResponse?.payload;
}

/// Runs when an alert arrives while the app is in the background or closed.
/// firebase_messaging starts it in a separate isolate (a fresh copy of Dart with
/// none of the app's state), so it sets up the plugin again before drawing.
/// It has to be a top-level function, marked so release builds keep it.
@pragma('vm:entry-point')
Future<void> onBackgroundAlert(RemoteMessage message) async {
  if (!Platform.isAndroid) return;
  await _plugin.initialize(settings: _settings);
  await showAlert(message);
}

/// Draws one alert from the fields backend/alerts.py puts in the data:
/// title, body, icon (weapon) and banner (activity), all optional but the title.
Future<void> showAlert(RemoteMessage message) async {
  if (!Platform.isAndroid) return;
  final data = message.data;
  final title = data['title'];
  if (title == null) return; // not one of our alerts

  // Both downloads at once; either one missing just leaves that image out.
  final [iconBytes, bannerBytes] = await Future.wait([_download(data['icon']), _download(data['banner'])]);
  // Raids and dungeons have no icon, so their banner doubles as the thumbnail
  // (Android crops it to fit).
  final thumbnailBytes = iconBytes ?? bannerBytes;
  final icon = thumbnailBytes == null ? null : ByteArrayAndroidBitmap(thumbnailBytes);

  await _plugin.show(
    // One notification per weapon, raid or Xûr armor piece, so a repeat replaces
    // it instead of stacking. The kind keeps a raid and an armor id apart.
    id: '${data['kind']}:${data['weaponId'] ?? data['id'] ?? title}'.hashCode,
    title: title,
    body: data['body'],
    payload: data['kind'],
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        largeIcon: icon, // the thumbnail on the right while collapsed
        styleInformation: bannerBytes == null
            ? null
            : BigPictureStyleInformation(
                ByteArrayAndroidBitmap(bannerBytes), // fills the expanded view
                contentTitle: title,
                summaryText: data['body'], // expanded notifications show this instead of the body
                hideExpandedLargeIcon: true, // the banner replaces the thumbnail when expanded
              ),
      ),
    ),
  );
}

/// An image's bytes, or null if there's no URL or it can't be fetched in time.
Future<Uint8List?> _download(String? url) async {
  if (url == null) return null;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final response = await (await client.getUrl(Uri.parse(url))).close();
    if (response.statusCode != HttpStatus.ok) return null;
    return await consolidateHttpClientResponseBytes(response).timeout(const Duration(seconds: 10));
  } catch (_) {
    return null; // show the alert without this image rather than not at all
  } finally {
    client.close();
  }
}
