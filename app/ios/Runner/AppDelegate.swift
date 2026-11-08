import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The category the backend puts on alerts that have a banner (#31). Alerts
    // with it expand into the banner view in ios/NotificationContent. Must match
    // IOS_BANNER_CATEGORY in backend/alerts.py. It has no buttons, so a tap
    // still just opens the app.
    // Careful: setNotificationCategories REPLACES every category the app has
    // registered. Anything else that calls it later would silently remove this
    // one, e.g. flutter_local_notifications' initialize() if it's ever run on iOS
    // (the app only initializes it on Android). Add other categories here instead.
    UNUserNotificationCenter.current().setNotificationCategories([
      UNNotificationCategory(identifier: "banner", actions: [], intentIdentifiers: [], options: [])
    ])
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
