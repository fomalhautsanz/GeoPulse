import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

// Small building blocks shared by many screens. Each one is a few lines,
// so they live together in this file.

/// A bold section heading, e.g. "Alerts" or "Triggered by".
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.color = AppColors.ink, this.trailing});

  final String text;
  final Color color;
  final Widget? trailing; // e.g. "Updated 8 s ago"

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            text,
            style: TextStyle(fontSize: 14, height: 1.172, fontWeight: FontWeight.w700, color: color),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

/// A small grey caps label for list groups: "TODAY", "YESTERDAY".
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

/// A coloured circle (or rounded square) with an icon in the middle.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 40,
    this.iconSize,
    this.rounded = false,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;
  final double? iconSize;
  final bool rounded; // rounded square instead of a circle

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: rounded ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: rounded ? BorderRadius.circular(size * 0.28) : null,
      ),
      child: Icon(icon, size: iconSize ?? size * 0.5, color: foreground),
    );
  }
}

/// A small chip with an optional icon, e.g. "Siren", "SMS 4/4", "Official".
/// [warning] makes it pale rose to flag a problem.
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.icon, this.warning = false});

  final String label;
  final IconData? icon;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final fg = warning ? AppColors.watchOn : AppColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: warning ? AppColors.watchContainer : AppColors.card,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(
            label,
            style: TextStyle(fontSize: 11, height: 1.3, fontWeight: FontWeight.w500, color: fg),
          ),
        ],
      ),
    );
  }
}

/// A tappable chip that can be selected. [dark] = the black "24H" style;
/// otherwise selected chips are pale rose with a check.
class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dark = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (dark) {
      bg = selected ? AppColors.ink : AppColors.card;
      fg = selected ? AppColors.surface : AppColors.ink;
    } else {
      bg = selected ? AppColors.watchContainer : AppColors.surface;
      fg = AppColors.ink;
    }
    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: dark ? 30 : 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: dark || selected ? null : Border.all(color: AppColors.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected && !dark) ...[
                Icon(Icons.check_rounded, size: 16, color: fg),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: dark ? 13 : 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of equal segments, one selected (Soil / Vibration / Tilt,
/// Low / Med / High). `<T>` lets the segments be any type of value.
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.showCheck = true,
    this.height = 42,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;
  final bool showCheck;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Row(
          children: [
            for (final value in values)
              Expanded(
                child: Semantics(
                  selected: value == selected,
                  child: Pressable(
                    onTap: () => onChanged(value),
                    child: Container(
                      color: value == selected ? AppColors.watchContainer : AppColors.surface,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showCheck && value == selected) ...[
                            const Icon(Icons.check_rounded, size: 16, color: AppColors.ink),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            label(value),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: value == selected ? FontWeight.w700 : FontWeight.w500,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A white rounded card with a thin border.
class OutlinedCard extends StatelessWidget {
  const OutlinedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surface,
    this.borderColor = AppColors.outline,
    this.borderWidth = 1,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(15),
      ),
      child: child,
    );
  }
}

/// A card of rows separated by thin lines (Settings, contacts, toggles).
class GroupedCard extends StatelessWidget {
  const GroupedCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.outline),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One row in a [GroupedCard]: leading icon, title, subtitle, and a
/// trailing widget (chevron, switch…). Tappable when [onTap] is set.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.bottom,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? bottom; // extra line under the subtitle (e.g. chips)
  final EdgeInsets padding;

  /// The standard "go to another screen" arrow.
  static const chevron = Icon(Icons.chevron_right_rounded, size: 24, color: AppColors.ink);

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, height: 1.25, fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.muted),
                    ),
                  ),
                if (bottom != null) Padding(padding: const EdgeInsets.only(top: 6), child: bottom),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap, child: row);
  }
}

/// A tinted note with an icon: "Prototype values…", "SMS goes out…".
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    required this.text,
    this.warning = false,
  });

  final IconData icon;
  final String text;
  final bool warning; // pale rose instead of grey

  @override
  Widget build(BuildContext context) {
    final fg = warning ? AppColors.watchOn : AppColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: warning ? AppColors.watchContainer : AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 16, color: fg)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, height: 17 / 12, color: fg)),
          ),
        ],
      ),
    );
  }
}

/// The app's on/off switch: brand red when on. [locked] shows it on but
/// faded and not changeable ("Critical alerts: always on").
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged, this.locked = false});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: locked ? null : onChanged,
      // WidgetStateProperty picks a colour based on the switch's state.
      thumbColor: const WidgetStatePropertyAll(AppColors.surface),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (!states.contains(WidgetState.selected)) return AppColors.outline;
        return states.contains(WidgetState.disabled) ? AppColors.switchOnDisabled : AppColors.brand;
      }),
    );
  }
}

/// A box with a dashed outline ("Add contact").
class DashedBorderBox extends StatelessWidget {
  const DashedBorderBox({super.key, required this.child, this.height = 46});

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(),
      child: SizedBox(height: height, child: Center(child: child)),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// "Something isn't built yet" message, used by placeholder actions.
void showNotYet(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$what isn’t available yet.')));
}

/// A plain SnackBar message.
void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
