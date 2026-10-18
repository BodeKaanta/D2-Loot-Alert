import 'package:d2lootalert/models.dart';
import 'package:d2lootalert/watch_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fake Firebase: records topic changes instead of talking to FCM.
class FakePush {
  bool permission = true;
  bool networkUp = true;
  final topics = <String>{};

  Future<bool> requestPermission() async => permission;
  Future<bool> subscribe(String topic) async => networkUp && topics.add(topic);
  Future<bool> unsubscribe(String topic) async => networkUp && topics.remove(topic);
}

void main() {
  const spareRations = Weapon(itemHash: 123, name: 'Spare Rations', type: 'Hand Cannon');
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
    expect(push.topics, {'weapon_123'});

    final reopened = newStore(); // like reopening the app
    expect(reopened.isWatchingWeapon(123), isTrue);
    expect(reopened.weapons.single.category, 'Gambit Ops');
  });

  test('tapping again stops watching and unsubscribes', () async {
    final store = newStore();
    await store.toggleWeapon(spareRations, 'Gambit Ops');

    expect(await store.toggleWeapon(spareRations, 'Gambit Ops'), WatchResult.stopped);
    expect(push.topics, isEmpty);
    expect(newStore().isWatchingWeapon(123), isFalse);
  });

  test('raids use the raid_ topic', () async {
    final store = newStore();
    await store.toggleRaid(lastWish);
    expect(push.topics, {'raid_last-wish'});
    expect(store.isWatchingRaid('last-wish'), isTrue);
  });

  test('nothing is saved without notification permission', () async {
    push.permission = false;
    final store = newStore();
    expect(await store.toggleWeapon(spareRations, 'Gambit Ops'), WatchResult.noPermission);
    expect(store.isWatchingWeapon(123), isFalse);
  });

  test('a failed subscribe leaves the weapon unwatched', () async {
    push.networkUp = false;
    final store = newStore();
    expect(await store.toggleWeapon(spareRations, 'Gambit Ops'), WatchResult.failed);
    expect(store.isWatchingWeapon(123), isFalse);
  });
}
