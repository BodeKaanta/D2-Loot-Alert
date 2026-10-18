import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'push.dart' as push;

/// What happened when the user tapped a bell.
enum WatchResult { watching, stopped, noPermission, failed, busy }

/// A watched weapon, with what the WATCHING list needs to show it.
class WatchedWeapon {
  const WatchedWeapon({required this.weapon, required this.category});

  final Weapon weapon;
  final String category; // where the user found it, e.g. "Gambit Ops"

  Map<String, dynamic> toJson() => {
        'itemHash': weapon.itemHash,
        'name': weapon.name,
        'type': weapon.type,
        'icon': weapon.icon,
        'category': category,
      };

  factory WatchedWeapon.fromJson(Map<String, dynamic> json) => WatchedWeapon(
        weapon: Weapon.fromMap(json),
        category: json['category'] as String? ?? '',
      );
}

/// Which weapons and raids/dungeons this phone gets alerts for.
///
/// Watching means subscribing to the item's FCM topic (`weapon_<itemHash>` or
/// `raid_<id>`). FCM can't tell an app which topics it's subscribed to, so the
/// list is also saved on the phone with shared_preferences.
///
/// It's a ChangeNotifier: widgets that read it through [WatchScope] rebuild
/// whenever something is watched or unwatched.
class WatchStore extends ChangeNotifier {
  WatchStore(
    this._prefs, {
    Future<bool> Function()? requestPermission,
    Future<bool> Function(String topic)? subscribe,
    Future<bool> Function(String topic)? unsubscribe,
  })  : _requestPermission = requestPermission ?? push.requestNotificationPermission,
        _subscribe = subscribe ?? push.subscribe,
        _unsubscribe = unsubscribe ?? push.unsubscribe {
    _load();
  }

  static const _key = 'watches';

  final SharedPreferences _prefs;
  // Swappable so tests can run without Firebase.
  final Future<bool> Function() _requestPermission;
  final Future<bool> Function(String topic) _subscribe;
  final Future<bool> Function(String topic) _unsubscribe;

  final Map<int, WatchedWeapon> _weapons = {};
  final Map<String, Featured> _raids = {};
  final Set<String> _pending = {}; // topics mid-change, so a double tap can't run twice

  List<WatchedWeapon> get weapons =>
      _weapons.values.toList()..sort((a, b) => a.weapon.name.compareTo(b.weapon.name));
  bool isWatchingWeapon(int itemHash) => _weapons.containsKey(itemHash);
  bool isWatchingRaid(String id) => _raids.containsKey(id);

  Future<WatchResult> toggleWeapon(Weapon weapon, String category) {
    final topic = push.weaponTopic(weapon.itemHash);
    return isWatchingWeapon(weapon.itemHash)
        ? _stop(topic, () => _weapons.remove(weapon.itemHash))
        : _start(topic, () => _weapons[weapon.itemHash] = WatchedWeapon(weapon: weapon, category: category));
  }

  Future<WatchResult> toggleRaid(Featured raid) {
    final topic = push.raidTopic(raid.id);
    return isWatchingRaid(raid.id)
        ? _stop(topic, () => _raids.remove(raid.id))
        : _start(topic, () => _raids[raid.id] = raid);
  }

  Future<WatchResult> _start(String topic, void Function() add) async {
    if (!_pending.add(topic)) return WatchResult.busy;
    try {
      if (!await _requestPermission()) return WatchResult.noPermission;
      if (!await _subscribe(topic)) return WatchResult.failed;
      add();
      await _save();
      notifyListeners();
      return WatchResult.watching;
    } finally {
      _pending.remove(topic);
    }
  }

  Future<WatchResult> _stop(String topic, void Function() remove) async {
    if (!_pending.add(topic)) return WatchResult.busy;
    try {
      if (!await _unsubscribe(topic)) return WatchResult.failed;
      remove();
      await _save();
      notifyListeners();
      return WatchResult.stopped;
    } finally {
      _pending.remove(topic);
    }
  }

  void _load() {
    final saved = _prefs.getString(_key);
    if (saved == null) return;
    try {
      final json = jsonDecode(saved) as Map<String, dynamic>;
      for (final w in (json['weapons'] as List? ?? const [])) {
        final watched = WatchedWeapon.fromJson(Map<String, dynamic>.from(w as Map));
        _weapons[watched.weapon.itemHash] = watched;
      }
      for (final r in (json['raids'] as List? ?? const [])) {
        final raid = Featured.fromMap(Map<String, dynamic>.from(r as Map));
        _raids[raid.id] = raid;
      }
    } catch (_) {
      // A damaged save shouldn't crash the app; it just starts with an empty list.
    }
  }

  Future<void> _save() => _prefs.setString(_key, jsonEncode({
        'weapons': [for (final w in _weapons.values) w.toJson()],
        'raids': [
          for (final r in _raids.values) {'id': r.id, 'name': r.name, 'kind': r.kind, 'image': r.image},
        ],
      }));
}

/// Makes the [WatchStore] available to every screen: `WatchScope.of(context)`.
/// Widgets that call it rebuild when the watch list changes.
class WatchScope extends InheritedNotifier<WatchStore> {
  const WatchScope({super.key, required WatchStore store, required super.child})
      : super(notifier: store);

  static WatchStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WatchScope>()!.notifier!;
}
