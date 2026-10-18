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
            {'itemHash': 4276696963, 'name': 'Last Man Standing', 'type': 'Shotgun', 'icon': 'https://x/i.jpg'},
          ],
        },
      ],
      'featured': [
        {'id': 'last-wish', 'name': 'Last Wish', 'kind': 'raid'},
      ],
    });

    expect(rotation.resetId, '2026-10-17');
    expect(rotation.activities.single.weapons.single.name, 'Last Man Standing');
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

  test('activity title adds the category only when it says something new', () {
    ActivityGroup group(String name, String category) =>
        ActivityGroup(id: '', name: name, category: category, weapons: const []);

    expect(group('Gambit', 'Gambit').title, 'Gambit');
    expect(group('Quickplay', 'Solo Ops').title, 'Quickplay · Solo Ops');
  });
}
