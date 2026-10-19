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
