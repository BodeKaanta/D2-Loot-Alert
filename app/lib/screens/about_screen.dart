import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../push.dart';
import '../theme.dart';
import '../widgets/section_header.dart';

/// What the app is, credits and disclaimers, plus a push test panel in debug builds.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ABOUT')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text(
            'Get notified when a Destiny 2 weapon you want is a bonus focus drop, '
            'or when a raid or dungeon you want is featured this week.',
            style: AppText.body,
          ),
          const SizedBox(height: 24),
          const SectionHeader('Credits'),
          const Text(
            'Destiny imagery © Bungie, Inc. Weapon icons and activity art come from the Bungie.net API.',
            style: AppText.body,
          ),
          // The app icon artist's credit goes here once he decides how to be named (#10).
          const SizedBox(height: 12),
          const Text('Font: Inter by Rasmus Andersson (SIL Open Font License 1.1).', style: AppText.body),
          const SizedBox(height: 12),
          const Text(
            'D2 Loot Alert is an unofficial fan app, not affiliated with or endorsed by Bungie. '
            'Destiny is a trademark of Bungie, Inc.',
            style: AppText.body,
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () => showLicensePage(context: context, applicationName: 'D2 Loot Alert'),
              child: const Text('OPEN-SOURCE LICENSES'),
            ),
          ),
          // Debug builds only: lets Bode send this device a test push (#8).
          if (kDebugMode) ...[
            const SizedBox(height: 32),
            const SectionHeader('Push test (debug builds)'),
            const _PushTestPanel(),
          ],
        ],
      ),
    );
  }
}

/// Asks for notification permission and subscribes this device to the "test"
/// topic, the same mechanism real alerts use, so a message sent to that topic
/// from the Firebase console should arrive.
class _PushTestPanel extends StatefulWidget {
  const _PushTestPanel();

  @override
  State<_PushTestPanel> createState() => _PushTestPanelState();
}

class _PushTestPanelState extends State<_PushTestPanel> {
  String? _status;

  Future<void> _enable() async {
    final allowed = await requestNotificationPermission();
    final subscribed = allowed && await subscribe(testTopic);
    if (!mounted) return; // the user may have left the screen while we waited
    setState(() {
      _status = !allowed
          ? 'Notifications are turned off for this app.'
          : !subscribed
              ? "Couldn't subscribe to the test topic. Check your connection."
              : 'Subscribed to topic "$testTopic". Put the app in the background, then send a '
                  'message to that topic from Firebase console → Messaging.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton(onPressed: _enable, child: const Text('ENABLE NOTIFICATIONS')),
        if (status != null) ...[
          const SizedBox(height: 12),
          Text(status, style: AppText.itemType),
        ],
      ],
    );
  }
}
