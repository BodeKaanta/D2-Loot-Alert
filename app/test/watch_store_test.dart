import 'dart:async';
import 'dart:convert';

import 'package:d2lootalert/models.dart';
import 'package:d2lootalert/watch_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fake Firebase: records topic changes instead of talking to FCM. Setting
// [gate] holds every topic change until the test completes it, like a slow network.
class FakePush {
  bool permission = true;
  bool networkUp = true;
  Completer<void>? gate;
  final topics = <String>{};

  Future<bool> requestPermission() async => permission;

  Future<bool> subscribe(String topic) async {
    await gate?.future;
    if (!networkUp) return false;
    topics.add(topic);
    return true;
  }

  Future<bool> unsubscribe(String topic) async {
    await gate?.future;
    if (!networkUp) return false;
    topics.remove(topic);
    return true;
  }
}

void main() {
  const spareRations = Weapon(id: 'spare-rations', itemHash: 123, name: 'Spare Rations', type: 'Hand Cannon');
  const lastWish = Featured(id: 'last-wish', name: 'Last Wish', kind: 'raid');

  late FakePush push;
  late SharedPreferences prefs;

  WatchStore newStore() => WatchStore(prefs,
      requestPermission: push.requestPermission, subscribe: push.subscribe, unsubscribe: push.unsubscribe);

  setUp(() async {
    SharedPreferences.setMockInitialValues({}); // an empty, in-memory "phone storage"
    prefs = await SharedPreferences.getInstance();
    push = FakePush();
  });

  test('watching a weapon subscribes to its topic and survives a restart', () async {
    final store = newStore();

    expect(await store.toggleWeapon(spareRations, 'Gambit Ops'), WatchResult.watching);
    await store.settled;
    expect(push.topics, {'weapon_spare-rations'});

    final reopened = newStore(); // like reopening the app
    expect(reopened.isWatchingWeapon('spare-rations'), isTrue);
    expect(reopened.weapons.single.category, 'Gambit Ops');
  });

  test('the bell updates before the network answers', () async {
    push.gate = Completer<void>(); // a network that hasn't answered yet
    final store = newStore();

    expect(await store.toggleWeapon(spareRations, 'Gambit Ops'), WatchResult.watching);
    expect(store.isWatchingWeapon('spare-rations'), isTrue); // already watching...
    expect(push.topics, isEmpty); // ...while the subscribe is still in flight

    push.gate!.complete();
    await store.settled;
    expect(push.topics, {'weapon_spare-rations'});
  });

  test('fast watch, unwatch, watch ends subscribed', () async {
    push.gate = Completer<void>();
    final store = newStore();

    await store.toggleWeapon(spareRations, 'Gambit Ops');
    await store.toggleWeapon(spareRations, 'Gambit Ops');
    await store.toggleWeapon(spareRations, 'Gambit Ops');
    push.gate!.complete();
    await store.settled;

    expect(store.isWatchingWeapon('spare-rations'), isTrue);
    expect(push.topics, {'weapon_spare-rations'}); // topic changes ran in tap order
  });

  test('tapping again stops watching and unsubscribes', () async {
    final store = newStore();
    await store.toggleWeapon(spareRations, 'Gambit Ops');

    expect(await store.toggleWeapon(spareRations, 'Gambit Ops'), WatchResult.stopped);
    await store.settled;
    expect(push.topics, isEmpty);
    expect(newStore().isWatchingWeapon('spare-rations'), isFalse);
  });

  test('raids use the raid_ topic', () async {
    final store = newStore();
    await store.toggleRaid(lastWish);
    await store.settled;
    expect(push.topics, {'raid_last-wish'});
    expect(store.isWatchingRaid('last-wish'), isTrue);
  });

  test('weapon watches saved before #26 (no id) are dropped, raids are kept', () async {
    SharedPreferences.setMockInitialValues({
      'watches': jsonEncode({
        'weapons': [
          {'itemHash': 123, 'name': 'Spare Rations', 'type': 'Hand Cannon', 'category': 'Gambit Ops'},
        ],
        'raids': [
          {'id': 'last-wish', 'name': 'Last Wish', 'kind': 'raid'},
        ],
      }),
    });
    prefs = await SharedPreferences.getInstance();

    final store = newStore();
    expect(store.weapons, isEmpty);
    expect(store.isWatchingRaid('last-wish'), isTrue);
  });

  test('nothing is saved without notification permission', () async {
    push.permission = false;
    final store = newStore();
    expect(await store.toggleWeapon(spareRations, 'Gambit Ops'), WatchResult.noPermission);
    expect(store.isWatchingWeapon('spare-rations'), isFalse);
  });

  test('a failed subscribe is undone and reported', () async {
    push.networkUp = false;
    final store = newStore();
    final failure = store.failures.first; // listen before tapping; events arrive asynchronously

    expect(await store.toggleWeapon(spareRations, 'Gambit Ops'), WatchResult.watching);
    await store.settled;

    expect(store.isWatchingWeapon('spare-rations'), isFalse); // rolled back
    expect(newStore().isWatchingWeapon('spare-rations'), isFalse); // and not saved as watched
    expect(await failure, contains('Spare Rations'));
  });
}
