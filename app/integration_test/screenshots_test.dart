// App Store screenshots (#10). Not a normal test: it runs the real app in the
// iPhone simulator, walks through the screens, and pauses on each one while
// tool/screenshots.sh captures the simulator's screen. See CLAUDE.md > #10.
//
// Run it through tool/screenshots.sh, not on its own; the script does the capturing.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:d2lootalert/firebase_options.dart';
import 'package:d2lootalert/main.dart' as app;
import 'package:d2lootalert/models.dart';
import 'package:d2lootalert/watch_store.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Draw frames in real time, so banners and icons load while the test waits.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  /// Lets the screen load its images, then asks the script to capture it.
  Future<void> capture(WidgetTester tester, String name) async {
    await _wait(tester, const Duration(seconds: 6));
    // ignore: avoid_print
    print('SCREENSHOT:$name'); // the script watches the output for this line
    await _wait(tester, const Duration(seconds: 4)); // hold still while it captures
  }

  testWidgets('store screenshots', (tester) async {
    await _watchSomethingFromToday();
    // The app as main() starts it, minus the startup re-subscribe: that asks for
    // notification permission, and in the simulator nobody can answer the prompt.
    final watches = WatchStore(await SharedPreferences.getInstance());
    runApp(app.LootAlertApp(watches: watches, messenger: GlobalKey<ScaffoldMessengerState>()));
    await _wait(tester, const Duration(seconds: 2));

    // 1. TODAY, with READY TO FARM at the top.
    await capture(tester, '1_today');

    // 2. TODAY scrolled to the bonus focus activities.
    final bonusFocus = find.text('BONUS FOCUS');
    await tester.scrollUntilVisible(bonusFocus, 400, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(bonusFocus); // brings it to the top of the screen
    await capture(tester, '2_bonus_focus');

    // 3. LOOT: what's watched, then a card per category.
    await tester.tap(find.text('LOOT'));
    await capture(tester, '3_loot');

    // 4. One category's whole weapon list.
    final fireteam = find.text('FIRETEAM OPS');
    await tester.scrollUntilVisible(fireteam, 300, scrollable: find.byType(Scrollable).first); // hidden tabs are skipped
    await tester.tap(fireteam);
    await capture(tester, '4_category');
    await tester.pageBack();
    await _wait(tester, const Duration(seconds: 1));

    // 5. RAIDS & DUNGEONS, with this week's featured ones first.
    await tester.tap(find.text('RAIDS &\nDUNGEONS'));
    await capture(tester, '5_raids');
  });
}

/// Waits in real time while the app keeps drawing frames.
Future<void> _wait(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Saves a watch list built from today's rotation, as if the user had tapped
/// the bells, so READY TO FARM and WATCHING have something in them.
///
/// Tapping the bells instead would show iOS's notification permission dialog,
/// which nothing can dismiss in a simulator without its window. Saving the list
/// directly skips the topic subscriptions, which screenshots don't need.
Future<void> _watchSomethingFromToday() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final doc = await FirebaseFirestore.instance.doc('rotation/current').get();
  final rotation = Rotation.fromMap(doc.data() ?? {});

  // How many activities each weapon is the focus in. A weapon in two activities
  // would show twice in READY TO FARM, often under the same banner.
  final activityCount = <String, int>{};
  for (final activity in rotation.activities) {
    for (final w in activity.weapons) {
      activityCount[w.id] = (activityCount[w.id] ?? 0) + 1;
    }
  }

  // Three weapons from different categories, each the focus in just one
  // activity that has its own banner, so the first screenshot varies.
  final weapons = <WatchedWeapon>[];
  final categories = <String>{};
  for (final activity in rotation.activities) {
    if (activity.weapons.isEmpty || activity.image == null) continue;
    if (activityCount[activity.weapons.first.id] != 1) continue;
    if (!categories.add(activity.category)) continue;
    weapons.add(WatchedWeapon(weapon: activity.weapons.first, category: activity.category));
    if (weapons.length == 3) break;
  }

  // Same shape as WatchStore saves it.
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('watches', jsonEncode({
    'weapons': [for (final w in weapons) w.toJson()],
    'raids': [
      for (final r in rotation.featured.take(1)) {'id': r.id, 'name': r.name, 'kind': r.kind, 'image': r.image},
    ],
    'armor': [for (final a in rotation.xur.take(1)) a.toMap()],
  }));
}
