import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geopulse/models/device_status.dart';
import 'package:geopulse/screens/critical_alert_screen.dart';
import 'package:geopulse/screens/map_screen.dart';
import 'package:geopulse/state/status_controller.dart';

import 'test_data.dart';

Widget _alertScreen({VoidCallback? onSilenced}) => MaterialApp(
  home: CriticalAlertScreen(
    status: mockStatus(StatusLevel.critical),
    silenced: false,
    onSilenced: onSilenced ?? () {},
  ),
);

void main() {
  testWidgets('critical alert does not claim unsupported site outputs', (
    tester,
  ) async {
    await tester.pumpWidget(_alertScreen());

    expect(find.text('Siren / LED / SMS'), findsOneWidget);
    expect(find.text('Not available in firmware'), findsOneWidget);
    expect(find.text('Hotline unavailable'), findsOneWidget);
    expect(find.text('SMS 0 of 0'), findsNothing);
  });

  testWidgets('map stays unavailable when the node has no location data', (
    tester,
  ) async {
    final controller = StatusController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: StatusScope(controller: controller, child: const MapScreen()),
      ),
    );

    expect(find.text('Map location unavailable'), findsOneWidget);
    expect(find.textContaining('Waiting for node data'), findsOneWidget);
  });

  testWidgets('silence needs a full 2-second hold', (tester) async {
    var silencedCalls = 0;
    await tester.pumpWidget(_alertScreen(onSilenced: () => silencedCalls++));
    final button = find.text('Silence on this phone');
    await tester.ensureVisible(button);
    double fill() => tester
        .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .widthFactor!;

    var gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(fill(), closeTo(0.5, 0.01));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(fill(), 0);
    expect(silencedCalls, 0);

    gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2050));
    await gesture.up();
    await tester.pump();
    expect(silencedCalls, 1);
    expect(find.text('Silenced on this phone'), findsOneWidget);
  });

  testWidgets('reduced motion stops the critical alert pulse', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_alertScreen());
    await tester.pumpAndSettle();
    expect(find.text('Combined Hazard Alert'), findsOneWidget);
  });

  testWidgets('critical alert pulse animates when motion is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(_alertScreen());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });
}
