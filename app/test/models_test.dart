import 'package:d2lootalert/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a rotation/current document', () {
    final rotation = Rotation.fromMap({
      'resetId': '2026-10-17',
      'activities': [
        {
          'id': 'gambit-gambit',
          'name': 'Gambit',
          'category': 'Gambit',
          'image': 'https://www.bungie.net/img.jpg',
          'weapons': [
            {
              'id': 'last-man-standing',
              'itemHash': 4276696963,
              'name': 'Last Man Standing',
              'type': 'Shotgun',
              'icon': 'https://x/i.jpg',
            },
          ],
        },
      ],
      'featured': [
        {'id': 'last-wish', 'name': 'Last Wish', 'kind': 'raid'},
      ],
    });

    expect(rotation.resetId, '2026-10-17');
    expect(rotation.activities.single.weapons.single.name, 'Last Man Standing');
    expect(rotation.activities.single.weapons.single.id, 'last-man-standing');
    expect(rotation.activities.single.weapons.single.itemHash, 4276696963);
    expect(rotation.featured.single.kind, 'raid');
  });

  test('missing fields become empty values instead of crashing', () {
    final rotation = Rotation.fromMap({
      'activities': [
        {'name': 'Gambit'}, // no weapons, category or id
        'not a map',
      ],
    });

    expect(rotation.resetId, '');
    expect(rotation.activities, hasLength(1));
    expect(rotation.activities.single.weapons, isEmpty);
    expect(rotation.featured, isEmpty);
  });

  test('a weapon without an id (written before #26) falls back to its hash', () {
    expect(Weapon.fromMap({'itemHash': 123, 'name': 'Spare Rations'}).id, '123');
  });

  Weapon w(int hash, String name) =>
      Weapon(id: name.toLowerCase().replaceAll(' ', '-'), itemHash: hash, name: name, type: 'Pulse Rifle');
  LootPool pool(String name, String category, List<Weapon> weapons) =>
      LootPool(name: name, category: category, weapons: weapons);

  test('category loot: one list per Portal category, special-pool weapons say where', () {
    final crucibleMain = [w(1, 'Autumn Wind'), w(2, 'Better Devils')];

    final loot = buildCategoryLoot([
      pool('Gambit', 'Gambit Ops', [w(9, 'Spare Rations')]),
      pool('Control', 'Crucible Ops', crucibleMain),
      pool('Competitive', 'Crucible Ops', crucibleMain),
      pool('Trials of Osiris', 'Crucible Ops', [w(1, 'Autumn Wind'), w(3, 'Astral Horizon')]),
      pool('CRUX OF STASIS', 'Campaign', [w(7, 'Recurrent Impact')]), // hidden: not a Portal category
    ]);

    expect(loot.map((c) => c.category), ['Crucible Ops', 'Gambit Ops']); // Portal order
    final crucible = loot.first.weapons;
    expect(crucible.map((x) => x.weapon.name), ['Astral Horizon', 'Autumn Wind', 'Better Devils']);
    expect(crucible.first.onlyIn, ['Trials of Osiris']); // not in the main Control/Competitive pool
    expect(crucible[1].onlyIn, isEmpty); // Autumn Wind is in the main pool too
  });

  test('category loot lists each weapon once, even with several versions (#26)', () {
    final loot = buildCategoryLoot([
      pool('HyperNet Current', 'Fireteam Ops', [w(1405095983, 'Adored')]), // regular version
      pool('The Devils\' Lair', 'Fireteam Ops', [w(1405095983, 'Adored')]),
      pool('Warden of Nothing', 'Fireteam Ops', [w(891765152, 'Adored')]), // GM version, another hash
    ]);

    expect(loot.single.weapons.map((x) => x.weapon.name), ['Adored']);
    expect(loot.single.weapons.single.onlyIn, isEmpty); // the same weapon as the main pool's
  });

  test('Xûr: his stock and the catalog parse, and armor says its class (#13)', () {
    final rotation = Rotation.fromMap({
      'xur': [
        {'id': 'omnioculus', 'name': 'Omnioculus', 'class': 'Hunter', 'slot': 'Chest Armor', 'icon': 'https://x/o.jpg'},
      ],
    });
    expect(rotation.xur.single.description, 'Hunter chest armor');
    expect(Rotation.fromMap({}).xur, isEmpty); // not in the game, or an older document

    final catalog = ExoticArmorCatalog.fromMap({
      'armor': [
        {'id': 'stoicism', 'name': 'Stoicism', 'class': 'Titan', 'slot': 'Titan Mark'},
      ],
      'xurImage': 'https://x/tower_xur.jpg',
      'classImages': {'Titan': 'https://x/heart.jpg', 'Hunter': 7}, // a wrong type is skipped
    });
    expect(catalog.armor.single.description, 'Titan Mark'); // class items already name the class
    expect(catalog.xurImage, 'https://x/tower_xur.jpg');
    expect(catalog.classImages, {'Titan': 'https://x/heart.jpg'});
    expect(ExoticArmorCatalog.fromMap(null).armor, isEmpty); // no catalog written yet
  });

  test('READY TO FARM: only watched things available now, each place a weapon drops (#34)', () {
    ActivityGroup activity(String name, Weapon weapon) =>
        ActivityGroup(id: name, name: name, category: 'Solo Ops', weapons: [weapon]);
    final rotation = Rotation(
      resetId: '2026-10-20',
      activities: [
        activity('Quickplay', w(1, 'Ecliptic Distaff')),
        activity('Quickplay: Master', w(1, 'Ecliptic Distaff')),
        activity('Typhon Imperator', w(2, 'Reckless Endangerment')),
      ],
      featured: const [
        Featured(id: 'last-wish', name: 'Last Wish', kind: 'raid'),
        Featured(id: 'prophecy', name: 'Prophecy', kind: 'dungeon'),
      ],
      xur: const [ExoticArmor(id: 'omnioculus', name: 'Omnioculus', guardianClass: 'Hunter', slot: 'Chest Armor')],
    );

    final ready = ReadyToFarm.from(
      rotation,
      watchingWeapon: (id) => id == 'ecliptic-distaff',
      watchingRaid: (id) => id == 'prophecy',
      watchingArmor: (id) => id == 'omnioculus',
    );
    expect(ready.activities.map((a) => a.name), ['Quickplay', 'Quickplay: Master']); // both places
    expect(ready.featured.map((f) => f.name), ['Prophecy']);
    expect(ready.armor.single.name, 'Omnioculus');

    final nothing = ReadyToFarm.from(rotation,
        watchingWeapon: (_) => false, watchingRaid: (_) => false, watchingArmor: (_) => false);
    expect(nothing.isEmpty, isTrue); // the section is hidden
  });

  test('groups activities by category, keeping the backend order', () {
    ActivityGroup group(String name, String category) =>
        ActivityGroup(id: '', name: name, category: category, weapons: const []);

    final grouped = groupByCategory([
      group('K1 Logistics', 'Solo Ops'),
      group('Quickplay', 'Solo Ops'),
      group('The Coil', 'Pinnacle Ops'),
      group('Gambit', 'Gambit Ops'),
    ]);

    expect(grouped.keys, ['Solo Ops', 'Pinnacle Ops', 'Gambit Ops']);
    expect(grouped['Solo Ops']!.map((a) => a.name), ['K1 Logistics', 'Quickplay']);
  });
}
