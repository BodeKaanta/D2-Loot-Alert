import 'package:flutter/material.dart';

import '../theme.dart';

/// "▌PINNACLE OPS ──────────": a gold bar, the caps label, then a rule.
/// The gold bar is the one bright accent on the page, so the eye catches each
/// section while scrolling fast.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(width: 4, height: 20, color: AppColors.exotic),
          const SizedBox(width: 10),
          Text(title.toUpperCase(), style: AppText.sectionHeader),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: AppColors.tileBorder)),
        ],
      ),
    );
  }
}
