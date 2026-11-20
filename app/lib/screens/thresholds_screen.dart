import 'package:flutter/material.dart';

import '../data/status_repository.dart';
import '../models/settings.dart';
import '../theme/app_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import '../widgets/sub_screen_scaffold.dart';

/// "Settings · Alert thresholds" in Figma: when each sensor raises an alert,
/// and which outputs the device uses. "Save and sync to device" sends them.
class ThresholdsScreen extends StatefulWidget {
  const ThresholdsScreen({super.key});

  @override
  State<ThresholdsScreen> createState() => _ThresholdsScreenState();
}

class _ThresholdsScreenState extends State<ThresholdsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _soilWatch = TextEditingController();
  final _soilCritical = TextEditingController();
  final _vibration = TextEditingController();
  final _tilt = TextEditingController();
  Thresholds? _t; // the values being edited; null while loading
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await getThresholds();
      if (!mounted) return;
      setState(() {
        _t = t;
        _error = null;
      });
      _soilWatch.text = '${t.soilWatchPercent}';
      _soilCritical.text = '${t.soilCriticalPercent}';
      _vibration.text = '${t.vibrationPerMin}';
      _tilt.text = t.tiltDegrees.toStringAsFixed(1);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    for (final c in [_soilWatch, _soilCritical, _vibration, _tilt]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Validator for a whole number between [min] and [max].
  FormFieldValidator<String> _intRange(int min, int max) => (v) {
    final n = int.tryParse(v ?? '');
    if (n == null) return 'Enter a number';
    if (n < min || n > max) return '$min–$max';
    return null;
  };

  Future<void> _save() async {
    final t = _t;
    if (t == null || _saving || !_formKey.currentState!.validate()) return;
    final watch = int.parse(_soilWatch.text);
    final critical = int.parse(_soilCritical.text);
    if (watch >= critical) {
      showMessage(context, 'Watch must be lower than Critical.');
      return;
    }
    setState(() => _saving = true);
    try {
      await saveThresholds(
        t.copyWith(
          soilWatchPercent: watch,
          soilCriticalPercent: critical,
          vibrationPerMin: int.parse(_vibration.text),
          tiltDegrees: double.parse(_tilt.text),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = null;
    });
    showMessage(context, 'Saved and synced to Node GP‑01.');
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Form(
      key: _formKey,
      child: SubScreenScaffold(
        title: 'Thresholds',
        bottom: AppButton(
          label: _saving ? 'Syncing…' : 'Save and sync to device',
          onPressed: t == null || _saving ? null : _save,
        ),
        children: _error != null
            ? [
                Text('Could not load or save thresholds: $_error'),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ]
            : t == null
            ? const [
                Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                ),
              ]
            : [
                const InfoBanner(
                  icon: Icons.info_outline_rounded,
                  warning: true,
                  text: 'Calibrate these sensor thresholds at the site. They are not universal scientific limits.',
                ),
                const SizedBox(height: 12),
                OutlinedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _CardHeader(
                        icon: Icons.water_drop_outlined,
                        title: 'Soil moisture',
                        subtitle: 'Landslide alert',
                      ),
                      const SizedBox(height: 8),
                      _SoilRangeSlider(
                        watch:
                            (int.tryParse(_soilWatch.text) ??
                                    t.soilWatchPercent)
                                .clamp(0, 100),
                        critical:
                            (int.tryParse(_soilCritical.text) ??
                                    t.soilCriticalPercent)
                                .clamp(0, 100),
                        onChanged: (watch, critical) => setState(() {
                          _soilWatch.text = '$watch';
                          _soilCritical.text = '$critical';
                        }),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _NumberField(
                              label: 'Watch at',
                              controller: _soilWatch,
                              unit: '%',
                              validator: _intRange(1, 99),
                              onChanged: () => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _NumberField(
                              label: 'Critical at',
                              controller: _soilCritical,
                              unit: '%',
                              validator: _intRange(2, 100),
                              onChanged: () => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _CardHeader(
                        icon: Icons.monitor_heart_outlined,
                        title: 'Ground vibration · ADXL345',
                        subtitle: 'Earthquake / seismic alert',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _NumberField(
                              label: 'Alert at',
                              controller: _vibration,
                              unit: 'events/min',
                              validator: _intRange(1, 60),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _FieldLabel('Sensitivity'),
                                SegmentedTabs<VibrationSensitivity>(
                                  values: VibrationSensitivity.values,
                                  selected: t.sensitivity,
                                  label: (v) => v.label,
                                  showCheck: false,
                                  height: 48,
                                  onChanged: (v) => setState(
                                    () => _t = t.copyWith(sensitivity: v),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: _CardHeader(
                          icon: Icons.trending_up_rounded,
                          title: 'Ground movement',
                          subtitle: 'ADXL345 tilt',
                        ),
                      ),
                      SizedBox(
                        width: 130,
                        child: _NumberField(
                          label: 'Alert at',
                          controller: _tilt,
                          unit: '°',
                          decimal: true,
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            if (n == null) return 'Enter a number';
                            if (n < 0.1 || n > 10) return '0.1–10';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const InfoBanner(
                  icon: Icons.info_outline_rounded,
                  warning: true,
                  text: 'Siren, LED, and SMS outputs are not supported by this firmware.',
                ),
              ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.brand),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        height: 1.172,
        color: AppColors.muted,
      ),
    ),
  );
}

/// A label + white number box with a unit, e.g. "Watch at [70 %]".
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    required this.unit,
    required this.validator,
    this.decimal = false,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String unit;
  final FormFieldValidator<String> validator;
  final bool decimal;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      controller: controller,
      suffixText: unit,
      fillColor: AppColors.surface,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      textInputAction: TextInputAction.done,
      validator: validator,
      onChanged: (_) => onChanged?.call(),
    );
  }
}

/// Two-handle slider for soil Watch and Critical. The track shows the
/// zones: grey (normal), coral (watch), maroon (critical).
class _SoilRangeSlider extends StatelessWidget {
  const _SoilRangeSlider({
    required this.watch,
    required this.critical,
    required this.onChanged,
  });

  final int watch;
  final int critical;
  final void Function(int watch, int critical) onChanged;

  @override
  Widget build(BuildContext context) {
    final start = watch.toDouble();
    final end = critical < watch ? start : critical.toDouble();
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 6,
        rangeTrackShape: const _ZoneTrackShape(),
        rangeThumbShape: const _RingThumbShape(),
        overlayColor: AppColors.watchContainer,
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: RangeSlider(
        min: 0,
        max: 100,
        divisions: 100,
        values: RangeValues(start, end),
        semanticFormatterCallback: (v) => '${v.round()}%',
        onChanged: (v) {
          if (v.end - v.start < 1) return; // keep Watch below Critical
          onChanged(v.start.round(), v.end.round());
        },
      ),
    );
  }
}

/// Paints the three zones, split at the two handles.
class _ZoneTrackShape extends RoundedRectRangeSliderTrackShape {
  const _ZoneTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset startThumbCenter,
    required Offset endThumbCenter,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );
    final radius = Radius.circular(rect.height / 2);
    final canvas = context.canvas;
    void segment(double from, double to, Color color) => canvas.drawRRect(
      RRect.fromLTRBR(from, rect.top, to, rect.bottom, radius),
      Paint()..color = color,
    );
    segment(rect.left, startThumbCenter.dx, AppColors.outline);
    segment(endThumbCenter.dx, rect.right, AppColors.criticalContainer);
    segment(startThumbCenter.dx, endThumbCenter.dx, AppColors.watchStrong);
  }
}

/// White handle with a maroon ring.
class _RingThumbShape extends RangeSliderThumbShape {
  const _RingThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(22, 22);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    bool isOnTop = false,
    TextDirection textDirection = TextDirection.ltr,
    required SliderThemeData sliderTheme,
    Thumb thumb = Thumb.start,
    bool isPressed = false,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, 10, Paint()..color = AppColors.surface);
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..color = AppColors.criticalContainer
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}
