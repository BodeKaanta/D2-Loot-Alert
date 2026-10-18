import 'package:flutter/material.dart';

import '../theme.dart';

/// Title and one line of help at the top of the LOOT and RAIDS & DUNGEONS tabs.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, required this.help});

  final String title;
  final String help;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: AppText.appTitle),
          const SizedBox(height: 6),
          Text(help, style: AppText.itemType),
        ],
      ),
    );
  }
}
