/// App-side copies of the Firestore documents written by backend/rotation.py
/// (see CLAUDE.md > Backend > Firestore layout).
///
/// Parsing is defensive: a missing or wrongly typed field becomes an empty
/// value instead of crashing the screen.
library;

class Weapon {
  const Weapon({required this.itemHash, required this.name, required this.type, this.icon});

  final int itemHash;
  final String name;
  final String type; // e.g. "Hand Cannon"
  final String? icon; // full https URL on bungie.net

  factory Weapon.fromMap(Map<String, dynamic> map) => Weapon(
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

/// The rotation/current document.
class Rotation {
  const Rotation({required this.resetId, required this.activities, required this.featured});

  final String resetId; // date of the daily reset, e.g. "2026-10-17"
  final List<ActivityGroup> activities;
  final List<Featured> featured;

  factory Rotation.fromMap(Map<String, dynamic> map) => Rotation(
        resetId: map['resetId'] as String? ?? '',
        activities: _maps(map['activities']).map(ActivityGroup.fromMap).toList(),
        featured: _maps(map['featured']).map(Featured.fromMap).toList(),
      );
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
