import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

/// One tab in [BottomNav]: either a single-colour PNG ([iconAsset]) or a
/// Material [icon]. Either way it gets tinted.
class BottomNavItem {
  const BottomNavItem({
    required this.label,
    required this.iconSize,
    this.iconAsset,
    this.icon,
  }) : assert(iconAsset != null || icon != null);

  final String label; // read out by screen readers
  final String? iconAsset;
  final IconData? icon;
  final double iconSize; // each Figma icon has its own size
}

/// The red rounded navigation bar at the bottom of the screen.
/// The selected tab sits in a white tile with a red icon.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<BottomNavItem> items;
  final int selectedIndex;

  /// Called with the tapped tab's index. `ValueChanged<int>` = a function
  /// that takes an int.
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 63,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          // `for` inside a list builds one child per item.
          for (var i = 0; i < items.length; i++)
            Expanded(child: _buildTab(items[i], i == selectedIndex, i)),
        ],
      ),
    );
  }

  Widget _buildTab(BottomNavItem item, bool selected, int index) {
    final color = selected ? AppColors.brand : AppColors.onBrand;
    final asset = item.iconAsset;
    final Widget icon = asset != null
        ? Image.asset(
            asset,
            width: item.iconSize,
            height: item.iconSize,
            color: color,
            colorBlendMode: BlendMode.srcIn,
          )
        : Icon(item.icon, size: item.iconSize, color: color);

    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: () => onSelected(index),
        semanticLabel: item.label,
        child: Center(
          child: selected
              ? Container(
                  width: 51.69,
                  height: 51.69,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(color: AppColors.shadow, blurRadius: 4),
                    ],
                  ),
                  child: icon,
                )
              : icon,
        ),
      ),
    );
  }
}
