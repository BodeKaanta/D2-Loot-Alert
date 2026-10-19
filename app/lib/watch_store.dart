import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'push.dart' as push;

/// What a bell tap did. Network failures come later, through [WatchStore.failures].
enum WatchResult { watching, stopped, noPermission }

/// A watched weapon, with what the WATCHING list needs to show it.
class WatchedWeapon {
  const WatchedWeapon({required this.weapon, required this.category});

  final Weapon weapon;
  final String category; // where the user found it, e.g. "Gambit Ops"

  Map<String, dynamic> toJson() => {
        'id': weapon.id,
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
/// Watching means subscribing to the item's FCM topic (`weapon_<id>`,
/// `raid_<id>` or `xur_<id>`). FCM can't tell an app which topics it's subscribed to, so the
/// list is also saved on the phone with shared_preferences.
///
/// Taps feel instant: the list (and every bell showing it) changes right away,
/// and the topic change happens in the background (#20). If that fails, the
/// change is undone and a message goes out on [failures].
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

  final Map<String, WatchedWeapon> _weapons = {}; // by Weapon.id
  final Map<String, Featured> _raids = {};
  final Map<String, ExoticArmor> _armor = {}; // by ExoticArmor.id (#13)

  /// The last topic change queued for each topic. Changes to one topic run in
  /// tap order, so watch-unwatch-watch ends subscribed, however fast the taps.
  final Map<String, Future<void>> _topicQueue = {};

  /// Asked once; afterwards a tap doesn't wait on the permission check at all.
  bool _permissionGranted = false;

  final _failures = StreamController<String>.broadcast();

  /// Messages for background failures, e.g. no network. main.dart shows them.
  Stream<String> get failures => _failures.stream;

  /// Completes once every queued topic change has finished (used by tests).
  Future<void> get settled => Future.wait(_topicQueue.values.toList());

  List<WatchedWeapon> get weapons =>
      _weapons.values.toList()..sort((a, b) => a.weapon.name.compareTo(b.weapon.name));
  List<ExoticArmor> get armor => _armor.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  bool isWatchingWeapon(String id) => _weapons.containsKey(id);
  bool isWatchingRaid(String id) => _raids.containsKey(id);
  bool isWatchingArmor(String id) => _armor.containsKey(id);

  Future<WatchResult> toggleWeapon(Weapon weapon, String category) {
    final id = weapon.id;
    return _toggle(
      topic: push.weaponTopic(id),
      label: weapon.name,
      isWatching: () => isWatchingWeapon(id),
      add: () => _weapons[id] = WatchedWeapon(weapon: weapon, category: category),
      remove: () => _weapons.remove(id),
    );
  }

  Future<WatchResult> toggleRaid(Featured raid) => _toggle(
        topic: push.raidTopic(raid.id),
        label: raid.name,
        isWatching: () => isWatchingRaid(raid.id),
        add: () => _raids[raid.id] = raid,
        remove: () => _raids.remove(raid.id),
      );

  /// Exotic armor: a push when Xûr is selling it (#13).
  Future<WatchResult> toggleArmor(ExoticArmor armor) => _toggle(
        topic: push.xurTopic(armor.id),
        label: armor.name,
        isWatching: () => isWatchingArmor(armor.id),
        add: () => _armor[armor.id] = armor,
        remove: () => _armor.remove(armor.id),
      );

  Future<WatchResult> _toggle({
    required String topic,
    required String label,
    required bool Function() isWatching,
    required void Function() add,
    required void Function() remove,
  }) async {
    final watch = !isWatching();
    if (watch && !_permissionGranted) {
      // Only the first watch waits here (it may show Android's permission prompt).
      _permissionGranted = await _requestPermission();
      if (!_permissionGranted) return WatchResult.noPermission;
    }

    // Change the list right away so every bell updates on this frame.
    watch ? add() : remove();
    notifyListeners();
    unawaited(_save());

    // Then tell FCM, in the background.
    _queueTopicChange(topic, () async {
      final ok = watch ? await _subscribe(topic) : await _unsubscribe(topic);
      if (ok) return;
      // Undo, unless a later tap already put it back the way it was.
      if (isWatching() == watch) {
        watch ? remove() : add();
        notifyListeners();
        await _save();
      }
      _failures.add('Couldn\'t update alerts for $label. Check your connection and try again.');
    });
    return watch ? WatchResult.watching : WatchResult.stopped;
  }

  void _queueTopicChange(String topic, Future<void> Function() change) {
    final next = (_topicQueue[topic] ?? Future<void>.value()).then((_) => change());
    _topicQueue[topic] = next;
    next.whenComplete(() {
      if (identical(_topicQueue[topic], next)) _topicQueue.remove(topic);
    });
  }

  void _load() {
    final saved = _prefs.getString(_key);
    if (saved == null) return;
    try {
      final json = jsonDecode(saved) as Map<String, dynamic>;
      for (final w in (json['weapons'] as List? ?? const [])) {
        final map = Map<String, dynamic>.from(w as Map);
        // Saved before #26, keyed by item hash. Those topics no longer get
        // alerts, so drop them; the user re-taps the bells (Bode's choice).
        if (map['id'] == null) continue;
        final watched = WatchedWeapon.fromJson(map);
        _weapons[watched.weapon.id] = watched;
      }
      for (final r in (json['raids'] as List? ?? const [])) {
        final raid = Featured.fromMap(Map<String, dynamic>.from(r as Map));
        _raids[raid.id] = raid;
      }
      for (final a in (json['armor'] as List? ?? const [])) {
        final armor = ExoticArmor.fromMap(Map<String, dynamic>.from(a as Map));
        _armor[armor.id] = armor;
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
        'armor': [for (final a in _armor.values) a.toMap()],
      }));

  @override
  void dispose() {
    _failures.close();
    super.dispose();
  }
}

/// Makes the [WatchStore] available to every screen: `WatchScope.of(context)`.
/// Widgets that call it rebuild when the watch list changes.
class WatchScope extends InheritedNotifier<WatchStore> {
  const WatchScope({super.key, required WatchStore store, required super.child})
      : super(notifier: store);

  static WatchStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WatchScope>()!.notifier!;
}
