import 'package:flutter/material.dart';

import '../theme.dart';

/// "BONUS FOCUS ──────────": caps label followed by a thin rule.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(title.toUpperCase(), style: AppText.sectionHeader),
          const SizedBox(width: 12),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
