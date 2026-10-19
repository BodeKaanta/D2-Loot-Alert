import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/armor_row.dart';
import '../widgets/link_card.dart';

/// How a class card frames its picture, when the default (centered, no zoom)
/// doesn't match the other cards. The pictures are picked in CLASS_BANNER_ARMOR
/// (backend/rotation.py).
const _classImageFraming = {
  // Wings of Sacred Dawn is a full-body render, while the Titan and Hunter
  // pieces are torso close-ups. Zooming 1.8x (their shoulder widths compared)
  // around its chest gem (79% across, 26% down) makes the three match (Bode).
  'Warlock': (alignment: Alignment(0.58, -0.6), zoom: 1.8),
};

/// Xûr on LOOT: one card per class, since all 141 exotics at once is a lot to
/// scroll (Bode). A card opens that class's exotics, each with a bell (#13).
class XurScreen extends StatelessWidget {
  const XurScreen({super.key});

  static final _catalog = FirebaseFirestore.instance.doc('catalog/exoticArmor');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('XÛR')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _catalog.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Couldn't load the exotic armor list.", style: AppText.body));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final catalog = ExoticArmorCatalog.fromMap(snapshot.data!.data());
          final byClass = {
            for (final guardianClass in guardianClasses)
              guardianClass: catalog.armor.where((a) => a.guardianClass == guardianClass).toList(),
          };
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Xûr sells exotic armor from Friday until the Tuesday reset. '
                  'Pick a class, then tap a bell to get a push when he has that piece.',
                  style: AppText.itemType,
                ),
              ),
              if (catalog.armor.isEmpty)
                const Text('The exotic armor list isn\'t ready yet. It\'s built on the next daily run.',
                    style: AppText.body),
              for (final MapEntry(key: guardianClass, value: armor) in byClass.entries)
                if (armor.isNotEmpty)
                  LinkCard(
                    title: guardianClass,
                    label: '${armor.length} exotics',
                    image: catalog.classImages[guardianClass], // one of the class's exotics
                    imageAlignment: _classImageFraming[guardianClass]?.alignment ?? Alignment.center,
                    imageZoom: _classImageFraming[guardianClass]?.zoom ?? 1,
                    destination: (_) => _ClassScreen(guardianClass: guardianClass, armor: armor),
                  ),
            ],
          );
        },
      ),
    );
  }
}

/// One class's exotic armor, each with its watch bell.
class _ClassScreen extends StatelessWidget {
  const _ClassScreen({required this.guardianClass, required this.armor});

  final String guardianClass;
  final List<ExoticArmor> armor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('XÛR · ${guardianClass.toUpperCase()}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // The class is already in the title, so each row just says its slot.
          for (final piece in armor) ArmorRow(armor: piece, subtitle: piece.slot),
        ],
      ),
    );
  }
}
