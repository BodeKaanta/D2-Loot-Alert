import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

// Push notification helpers. Watching something = subscribing this phone to its
// topic; the backend sends each alert to a topic (backend/alerts.py).

/// Topic for test messages sent by hand from the Firebase console.
const testTopic = 'test';

/// Must match weapon_topic() / raid_topic() in backend/alerts.py.
String weaponTopic(String weaponId) => 'weapon_$weaponId'; // Weapon.id, the name slug (#26)
String raidTopic(String id) => 'raid_$id'; // dungeons too
String xurTopic(String armorId) => 'xur_$armorId'; // ExoticArmor.id, the name slug (#13)

/// Asks for permission to show notifications (Android 13+ and iOS ask the user).
/// Returns right away, without a prompt, once the user has answered.
Future<bool> requestNotificationPermission() async {
  final settings = await FirebaseMessaging.instance.requestPermission();
  return settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;
}

/// Subscribes this device to [topic]. Returns false if it failed, e.g. no
/// network, or on iOS if Apple never gave the app its push token.
Future<bool> subscribe(String topic) async {
  try {
    await _waitForApnsToken();
    await FirebaseMessaging.instance.subscribeToTopic(topic);
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> unsubscribe(String topic) async {
  try {
    await _waitForApnsToken();
    await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    return true;
  } catch (_) {
    return false;
  }
}

/// iOS only (#17). FCM reaches an iPhone or iPad through Apple's push service
/// (APNs), so it needs the device's APNs token before it can change topics.
/// iOS hands the token to the app a moment after launch, and firebase_messaging
/// throws `apns-token-not-set` instead of waiting for it. A bell tapped right
/// after opening the app could beat it, so wait up to 10 seconds. If the token
/// still isn't there, the topic call throws and the tap is undone as usual.
Future<void> _waitForApnsToken() async {
  if (!Platform.isIOS) return;
  for (var tries = 0; tries < 20; tries++) {
    if (await FirebaseMessaging.instance.getAPNSToken() != null) return;
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
