import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A shaded range on the chart, e.g. the critical zone above 90%.
class ChartBand {
  const ChartBand(this.from, this.to, this.color);
  final double from;
  final double to;
  final Color color;
}

/// A dashed limit line with a label, e.g. "Warning 70%".
class ChartLimit {
  const ChartLimit(this.value, this.label);
  final double value;
  final String label;
}

/// The Sensors line chart: shaded bands, dashed limit lines, the reading
/// line and a dot on the latest value. Drawn with a `CustomPainter`, which
/// paints directly on a canvas, so no chart package is needed.
///
/// Live readings never animate: when new points arrive it just redraws.
class SensorChart extends StatelessWidget {
  const SensorChart({
    super.key,
    required this.points,
    required this.minY,
    required this.maxY,
    required this.xLabels,
    required this.semanticLabel,
    this.bands = const [],
    this.limits = const [],
    this.height = 160,
  });

  final List<double> points; // oldest first
  final double minY;
  final double maxY;
  final List<String> xLabels; // spread evenly under the chart
  final String semanticLabel; // what a screen reader says
  final List<ChartBand> bands;
  final List<ChartLimit> limits;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          label: semanticLabel,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _ChartPainter(points, minY, maxY, bands, limits),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in xLabels)
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.points, this.minY, this.maxY, this.bands, this.limits);

  final List<double> points;
  final double minY;
  final double maxY;
  final List<ChartBand> bands;
  final List<ChartLimit> limits;

  @override
  void paint(Canvas canvas, Size size) {
    const endRoom = 6.0; // space on the right for the end dot
    final w = size.width - endRoom;
    final h = size.height;
    double y(double v) => h - ((v - minY) / (maxY - minY)).clamp(0.0, 1.0) * h;

    for (final band in bands) {
      canvas.drawRect(
        Rect.fromLTRB(0, y(band.to), w + endRoom, y(band.from)),
        Paint()..color = band.color,
      );
    }

    // Bottom axis
    canvas.drawLine(Offset(0, h), Offset(w + endRoom, h), Paint()..color = AppColors.outline);

    final dash = Paint()
      ..color = AppColors.chartLimitLine
      ..strokeWidth = 1.2;
    for (final limit in limits) {
      final ly = y(limit.value);
      for (var x = 0.0; x < w + endRoom; x += 8) {
        canvas.drawLine(Offset(x, ly), Offset(x + 4, ly), dash);
      }
      final label = TextPainter(
        text: TextSpan(
          text: limit.label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.chartLimitLine,
            fontFamily: 'Roboto',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(4, ly - label.height - 1));
    }

    if (points.length < 2) return;
    final step = w / (points.length - 1);
    final line = Path()..moveTo(0, y(points.first));
    for (var i = 1; i < points.length; i++) {
      line.lineTo(i * step, y(points[i]));
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.chartLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(w, y(points.last)), 5, Paint()..color = AppColors.chartEndDot);
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points != points || old.minY != minY || old.maxY != maxY;
}

/// Small bar chart of recent values; the highest bar is red.
class MiniBars extends StatelessWidget {
  const MiniBars({super.key, required this.values, this.height = 22});

  final List<int> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final peak = values.fold<int>(1, (m, v) => v > m ? v : m);
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final v in values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Container(
                    height: 4 + (height - 4) * v / peak,
                    decoration: BoxDecoration(
                      color: v == peak ? AppColors.brand : AppColors.chartBar,
                      borderRadius: BorderRadius.circular(1.5),
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
