import 'package:flutter/material.dart';

import '../theme.dart';

/// Bottom tabs in the Destiny style: caps labels, the active one off-white with
/// a short gold underline. (Not Material's stock NavigationBar.)
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.index, required this.onSelect});

  /// (label, share of the bar's width). "Raids & Dungeons" gets more room so
  /// it fits on one line, matching the game's wording.
  static const tabs = [('Today', 2), ('Loot', 2), ('Raids & Dungeons', 3)];

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false, // only keep clear of the phone's bottom gesture bar
        child: Row(
          children: [
            for (final (i, (label, share)) in tabs.indexed)
              Expanded(
                flex: share,
                child: _Tab(label: label, selected: i == index, onTap: () => onSelect(i)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                style: AppText.tabLabel.copyWith(
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(width: 24, height: 2, color: selected ? AppColors.exotic : Colors.transparent),
            ],
          ),
        ),
      ),
    );
  }
}
