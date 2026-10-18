import 'package:firebase_messaging/firebase_messaging.dart';

// Push notification helpers. Watching items (subscribing to topics like
// weapon_<itemHash>) comes in #9; for now these support the first test push.

/// Topic for test messages sent by hand from the Firebase console.
const testTopic = 'test';

/// Asks for permission to show notifications (Android 13+ and iOS ask the user).
Future<bool> requestNotificationPermission() async {
  final settings = await FirebaseMessaging.instance.requestPermission();
  return settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;
}

/// Subscribes this device to [topic]. Returns false if it failed, e.g. no
/// network, or on iOS before the push key from #17 is set up.
Future<bool> subscribe(String topic) async {
  try {
    await FirebaseMessaging.instance.subscribeToTopic(topic);
    return true;
  } catch (_) {
    return false;
  }
}
