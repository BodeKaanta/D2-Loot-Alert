/// App-side copies of the Firestore documents written by backend/rotation.py
/// (see CLAUDE.md > Backend > Firestore layout).
///
/// Parsing is defensive: a missing or wrongly typed field becomes an empty
/// value instead of crashing the screen.
library;

class Weapon {
  const Weapon({required this.id, required this.itemHash, required this.name, required this.type, this.icon});

  /// The slug of the name, e.g. "d-f-a". It's the same for every version of the
  /// weapon (a GM version has its own [itemHash], #26), so watches and alert
  /// topics use this, not the hash.
  final String id;
  final int itemHash; // one of its versions
  final String name;
  final String type; // e.g. "Hand Cannon"
  final String? icon; // full https URL on bungie.net

  factory Weapon.fromMap(Map<String, dynamic> map) => Weapon(
        // Data written before #26 has no id; the hash still keeps weapons apart.
        id: map['id'] as String? ?? '${map['itemHash'] ?? ''}',
        itemHash: (map['itemHash'] as num?)?.toInt() ?? 0,
        name: map['name'] as String? ?? 'Unknown weapon',
        type: map['type'] as String? ?? '',
        icon: map['icon'] as String?,
      );
}

/// One activity as the app shows it, e.g. "Gambit". Variants like
/// Customize/Matchmade were already merged by the backend.
class ActivityGroup {
  const ActivityGroup({
    required this.id,
    required this.name,
    required this.category,
    required this.weapons,
    this.image,
  });

  final String id; // same id as its lootPools/{id} document
  final String name;
  final String category; // the in-game Portal category, e.g. "Solo Ops"
  final List<Weapon> weapons;
  final String? image;

  factory ActivityGroup.fromMap(Map<String, dynamic> map) => ActivityGroup(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? 'Unknown activity',
        category: map['category'] as String? ?? '',
        image: map['image'] as String?,
        weapons: _maps(map['weapons']).map(Weapon.fromMap).toList(),
      );
}

/// A raid or dungeon that is featured (farmable) this week.
class Featured {
  const Featured({required this.id, required this.name, required this.kind, this.image});

  final String id;
  final String name;
  final String kind; // "raid" or "dungeon"
  final String? image;

  factory Featured.fromMap(Map<String, dynamic> map) => Featured(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? 'Unknown',
        kind: map['kind'] as String? ?? '',
        image: map['image'] as String?,
      );
}

/// An exotic armor piece (#13): one Xûr is selling (rotation/current.xur), or one
/// in the full list people pick from (catalog/exoticArmor).
class ExoticArmor {
  const ExoticArmor({required this.id, required this.name, required this.guardianClass, required this.slot, this.icon});

  final String id; // the name slug, same as weapons (#26); its alert topic is xur_<id>
  final String name;
  final String guardianClass; // "Titan", "Hunter" or "Warlock"
  final String slot; // e.g. "Chest Armor"
  final String? icon; // full https URL on bungie.net

  /// "Hunter chest armor", since exotic names don't say which class they're for.
  /// Class items already name the class ("Titan Mark"). Matches backend/alerts.py.
  String get description => guardianClass.isEmpty || slot.startsWith(guardianClass)
      ? slot
      : '$guardianClass ${slot.toLowerCase()}';

  factory ExoticArmor.fromMap(Map<String, dynamic> map) => ExoticArmor(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? 'Unknown armor',
        guardianClass: map['class'] as String? ?? '',
        slot: map['slot'] as String? ?? '',
        icon: map['icon'] as String?,
      );

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'class': guardianClass, 'slot': slot, 'icon': icon};
}

/// The classes in the game's order, for grouping exotic armor.
const guardianClasses = ['Titan', 'Hunter', 'Warlock'];

/// The catalog/exoticArmor document: every exotic armor piece (in class order),
/// plus the banners for the Xûr cards.
class ExoticArmorCatalog {
  const ExoticArmorCatalog({this.armor = const [], this.xurImage, this.classImages = const {}});

  final List<ExoticArmor> armor;
  final String? xurImage; // Xûr at his spot in the Tower, for the XÛR card on LOOT
  final Map<String, String> classImages; // class -> one exotic's screenshot, for the class cards

  /// Null (no catalog written yet) gives an empty catalog.
  factory ExoticArmorCatalog.fromMap(Map<String, dynamic>? map) {
    final classImages = <String, String>{};
    final images = map?['classImages'];
    if (images is Map) {
      images.forEach((cls, url) {
        if (url is String) classImages['$cls'] = url;
      });
    }
    return ExoticArmorCatalog(
      armor: _maps(map?['armor']).map(ExoticArmor.fromMap).toList(),
      xurImage: map?['xurImage'] as String?,
      classImages: classImages,
    );
  }
}

/// The rotation/current document.
class Rotation {
  const Rotation({
    required this.resetId,
    required this.activities,
    required this.featured,
    this.raidsAndDungeons = const [],
    this.xur = const [],
  });

  final String resetId; // date of the daily reset, e.g. "2026-10-17"
  final List<ActivityGroup> activities;
  final List<Featured> featured;

  /// Every raid and dungeon that can rotate in, for the watch toggles.
  final List<Featured> raidsAndDungeons;

  /// The exotic armor Xûr is selling; empty when he's not in the game (#13).
  final List<ExoticArmor> xur;

  factory Rotation.fromMap(Map<String, dynamic> map) => Rotation(
        resetId: map['resetId'] as String? ?? '',
        activities: _maps(map['activities']).map(ActivityGroup.fromMap).toList(),
        featured: _maps(map['featured']).map(Featured.fromMap).toList(),
        raidsAndDungeons: _maps(map['raidsAndDungeons']).map(Featured.fromMap).toList(),
        xur: _maps(map['xur']).map(ExoticArmor.fromMap).toList(),
      );
}

/// The game's Portal categories, in its order. Keep in sync with CATEGORY_ORDER
/// in backend/rotation.py. The LOOT tab shows only these, which also hides
/// one-off quest weapons (Campaign, Story, World).
const portalCategories = [
  'Solo Ops', 'Fireteam Ops', 'Arena Ops', 'Pinnacle Ops', 'Crucible Ops', 'Gambit Ops',
];

/// A lootPools/{id} document: one activity's possible weapons.
class LootPool {
  const LootPool({required this.name, required this.category, required this.weapons, this.image});

  final String name;
  final String category;
  final List<Weapon> weapons;
  final String? image;

  factory LootPool.fromMap(Map<String, dynamic> map) => LootPool(
        name: map['name'] as String? ?? 'Unknown activity',
        category: map['category'] as String? ?? '',
        image: map['image'] as String?,
        weapons: _maps(map['weapons']).map(Weapon.fromMap).toList(),
      );
}

/// A weapon in a category's loot. [onlyIn] names the activities that drop it
/// when the category's main pool doesn't (e.g. "Trials of Osiris").
class LootWeapon {
  const LootWeapon({required this.weapon, this.onlyIn = const []});

  final Weapon weapon;
  final List<String> onlyIn;
}

/// Everything one Portal category can drop as a bonus focus.
class CategoryLoot {
  const CategoryLoot({required this.category, required this.weapons, this.image});

  final String category;
  final List<LootWeapon> weapons; // alphabetical
  final String? image; // a banner from the category's main activities
}

/// Combines the lootPools documents into one weapon list per Portal category.
///
/// Most activities in a category share one "main" pool (e.g. 34 Fireteam Ops
/// activities, same 10 weapons); a few have their own (Trials, Sparrow Racing,
/// a GM). Weapons outside the main pool note where they drop.
List<CategoryLoot> buildCategoryLoot(List<LootPool> pools) {
  final result = <CategoryLoot>[];
  for (final category in portalCategories) {
    final inCategory = pools.where((p) => p.category == category).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (inCategory.isEmpty) continue;

    // Group activities by their exact weapon list; the main pool is the list most activities share.
    final byWeaponList = <String, List<LootPool>>{};
    for (final pool in inCategory) {
      final key = (pool.weapons.map((w) => w.id).toList()..sort()).join(',');
      byWeaponList.putIfAbsent(key, () => []).add(pool);
    }
    final mainPools = byWeaponList.values.reduce((a, b) => a.length >= b.length ? a : b);
    final mainIds = {for (final w in mainPools.first.weapons) w.id};

    // Each weapon once, by id, so all its versions share one row and one bell.
    final weapons = <String, Weapon>{};
    final onlyIn = <String, Set<String>>{};
    for (final pool in inCategory) {
      for (final weapon in pool.weapons) {
        weapons.putIfAbsent(weapon.id, () => weapon);
        if (!mainIds.contains(weapon.id)) {
          onlyIn.putIfAbsent(weapon.id, () => {}).add(pool.name);
        }
      }
    }

    result.add(CategoryLoot(
      category: category,
      image: mainPools.map((p) => p.image).firstWhere((i) => i != null, orElse: () => null),
      weapons: [
        for (final weapon in weapons.values)
          LootWeapon(weapon: weapon, onlyIn: (onlyIn[weapon.id]?.toList() ?? [])..sort()),
      ]..sort((a, b) => a.weapon.name.compareTo(b.weapon.name)),
    ));
  }
  return result;
}

/// Activities grouped under their category, in the order the backend sent them
/// (the game's Portal order). Dart's map literals keep insertion order.
Map<String, List<ActivityGroup>> groupByCategory(List<ActivityGroup> activities) {
  final groups = <String, List<ActivityGroup>>{};
  for (final activity in activities) {
    groups.putIfAbsent(activity.category, () => []).add(activity);
  }
  return groups;
}

/// Firestore gives nested lists as `List<dynamic>`; keep only the map entries.
List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
}
