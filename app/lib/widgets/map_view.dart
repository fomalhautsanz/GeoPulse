import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/device_status.dart';
import '../theme/app_colors.dart';
import '../theme/level_style.dart';
import 'pressable.dart';

/// A drawn (not real) map of the site, as in the Figma Map frame: contour
/// lines, a road, a river, the sensor node with its risk zone, the
/// evacuation area and "you". Tapping the node calls [onNodeTap].
///
/// A real map (e.g. OpenStreetMap tiles) can replace this later.
class MapView extends StatelessWidget {
  const MapView({super.key, required this.level, required this.onNodeTap});

  final StatusLevel level;
  final VoidCallback onNodeTap;

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder tells us how much space we have, so the markers can be
    // placed as fractions of the map's size.
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final node = Offset(w * 0.6, h * 0.3);
        final evac = Offset(w * 0.22, h * 0.53);
        final you = Offset(w * 0.39, h * 0.62);
        final showZone = level != StatusLevel.stable;

        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _MapPainter(node: node, showZone: showZone)),
              ),
              _place(
                you,
                Semantics(
                  label: 'You',
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.youHalo, shape: BoxShape.circle),
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: AppColors.wayfinding,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
              _place(
                evac,
                const _Marker(
                  color: AppColors.wayfinding,
                  icon: Icons.flag_outlined,
                  label: 'Evac area',
                ),
                labelBelow: true,
              ),
              _place(
                node,
                Semantics(
                  button: true,
                  label: 'Sensor node GP‑01, ${LevelStyle.of(level).label}. Show details',
                  child: Pressable(
                    onTap: onNodeTap,
                    child: ExcludeSemantics(
                      child: _Marker(
                        color: LevelStyle.of(level).container == AppColors.stableContainer
                            ? AppColors.ink
                            : LevelStyle.of(level).container,
                        icon: Icons.memory,
                        label: 'GP‑01',
                      ),
                    ),
                  ),
                ),
                labelBelow: true,
              ),
              const Positioned(left: 20, right: 0, top: 12, child: _Legend()),
            ],
          ),
        );
      },
    );
  }

  /// Centres [child] on [point] (markers with a label are centred on their circle).
  Widget _place(Offset point, Widget child, {bool labelBelow = false}) {
    const box = 90.0;
    return Positioned(
      left: point.dx - box / 2,
      top: point.dy - (labelBelow ? 18 : box / 2),
      width: box,
      child: labelBelow ? child : SizedBox(height: box, child: Center(child: child)),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.color, required this.icon, required this.label});

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface, width: 3),
            boxShadow: const [BoxShadow(color: AppColors.softShadow, blurRadius: 4, offset: Offset(0, 1))],
          ),
          child: Icon(icon, size: 18, color: AppColors.surface),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [BoxShadow(color: AppColors.softShadow, blurRadius: 3)],
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, String label, Color color) => Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [BoxShadow(color: AppColors.softShadow, blurRadius: 4)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink)),
            ],
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(Icons.memory, 'Sensor node', AppColors.ink),
          chip(Icons.flag_outlined, 'Evacuation area', AppColors.wayfinding),
          chip(Icons.near_me_outlined, 'You', AppColors.wayfinding),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({required this.node, required this.showZone});

  final Offset node;
  final bool showZone;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.mapLand);

    // Contour lines: gentle waves across the slope.
    final contour = Paint()
      ..color = AppColors.mapContour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 16; i++) {
      final base = i * h / 13 - 20;
      final path = Path()..moveTo(0, base);
      for (var x = 0.0; x <= w; x += 8) {
        path.lineTo(x, base + math.sin(x / w * math.pi * 1.6 + i * 0.5) * 16 + x * 0.06);
      }
      canvas.drawPath(path, contour);
    }

    // River
    final river = Path()
      ..moveTo(0, h * 0.66)
      ..cubicTo(w * 0.3, h * 0.6, w * 0.55, h * 0.72, w, h * 0.63);
    canvas.drawPath(
      river,
      Paint()
        ..color = AppColors.mapWater
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );

    // Road
    final road = Path()
      ..moveTo(w * 0.15, h + 10)
      ..cubicTo(w * 0.3, h * 0.55, w * 0.45, h * 0.25, w + 10, h * 0.08);
    canvas.drawPath(
      road,
      Paint()
        ..color = AppColors.mapRoad
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );

    // Risk zone around the node (dashed circle)
    if (showZone) {
      const r = 62.0;
      canvas.drawCircle(node, r, Paint()..color = AppColors.riskZoneFill);
      final dash = Paint()
        ..color = AppColors.riskZoneBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      const steps = 48;
      for (var i = 0; i < steps; i++) {
        final a = i * 2 * math.pi / steps;
        canvas.drawArc(Rect.fromCircle(center: node, radius: r), a, math.pi / steps, false, dash);
      }
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.node != node || old.showZone != showZone;
}
