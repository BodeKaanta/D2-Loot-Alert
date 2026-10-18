import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../widgets/app_tab_bar.dart';
import 'loot_screen.dart';
import 'raids_screen.dart';
import 'today_screen.dart';

/// The three tabs, plus opening the right one when the user taps a push.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _today = 0, _raids = 2;

  int _tab = _today;
  StreamSubscription<RemoteMessage>? _openedFromPush;

  @override
  void initState() {
    super.initState();
    // A push tapped while the app was closed...
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _openTabFor(message);
    });
    // ...or while it was in the background.
    _openedFromPush = FirebaseMessaging.onMessageOpenedApp.listen(_openTabFor);
  }

  @override
  void dispose() {
    _openedFromPush?.cancel();
    super.dispose();
  }

  /// Weapon alerts open Today (where the bonus focus is); raid and dungeon alerts
  /// open Raids & Dungeons. `kind` comes from the alert's data (backend/alerts.py).
  void _openTabFor(RemoteMessage message) {
    if (!mounted) return;
    final tab = switch (message.data['kind']) {
      'weapon' => _today,
      'raid' || 'dungeon' => _raids,
      _ => _tab,
    };
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps every tab alive, so switching tabs keeps your scroll position.
      body: IndexedStack(
        index: _tab,
        children: const [TodayScreen(), LootScreen(), RaidsScreen()],
      ),
      bottomNavigationBar: AppTabBar(index: _tab, onSelect: (i) => setState(() => _tab = i)),
    );
  }
}
