import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geopulse/data/auth_repository.dart' as auth;
import 'package:geopulse/data/mock_data.dart';
import 'package:geopulse/data/status_repository.dart';
import 'package:geopulse/main.dart';
import 'package:geopulse/models/device_status.dart';
import 'package:geopulse/screens/critical_alert_screen.dart';
import 'package:geopulse/screens/main_shell.dart';

const _latency = Duration(milliseconds: 300); // mock network delay
const _settle = Duration(milliseconds: 400); // transitions, sheets, dialogs

Future<void> _openApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const GeoPulseApp(home: MainShell()));
  await tester.pump(_latency); // first reading
  await tester.pump(_latency); // other tabs' first loads
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(_settle);
}

/// Opens the debug menu and picks a level.
Future<void> _setLevel(WidgetTester tester, StatusLevel level) async {
  await _tap(tester, find.byKey(const ValueKey('debug-menu')));
  await _tap(tester, find.byKey(ValueKey('debug-level-${level.name}')));
  await tester.pump(_latency);
  await tester.pump(_settle);
}

Future<void> _openTab(WidgetTester tester, String label) =>
    _tap(tester, find.bySemanticsLabel(label).last);

Widget _alertScreen({VoidCallback? onSilenced}) => MaterialApp(
      home: CriticalAlertScreen(
        status: mockStatus(StatusLevel.critical),
        silenced: false,
        onSilenced: onSilenced ?? () {},
      ),
    );

void main() {
  setUp(() async {
    resetMockData(); // every test starts at "stable" with fresh sample data
    await auth.logIn(phoneOrEmail: 'test', password: 'test');
  });

  testWidgets('Status shows the stable sample first', (tester) async {
    await _openApp(tester);
    expect(find.text('Conditions Stable'), findsOneWidget);
    expect(find.text('49%'), findsOneWidget);
    expect(find.text('Normal · warning at 70%'), findsOneWidget);
    expect(find.text('Test alarm'), findsOneWidget);
  });

  testWidgets('Test alarm label is never cut off, even with large text', (tester) async {
    for (final scale in [1.0, 1.3]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      resetMockData();
      await _openApp(tester);
      final label = tester.renderObject<RenderParagraph>(find.text('Test alarm'));
      expect(label.didExceedMaxLines, isFalse, reason: 'text scale $scale');
    }
  });

  testWidgets('Debug menu switches levels; critical opens the full-screen alert', (tester) async {
    await _openApp(tester);

    await _setLevel(tester, StatusLevel.watch);
    expect(find.text('Landslide Watch'), findsOneWidget);
    expect(find.textContaining('Node offline since'), findsOneWidget);
    expect(find.text('Prepare your go-bag and route'), findsOneWidget);

    await _setLevel(tester, StatusLevel.high);
    expect(find.text('Landslide Risk: High'), findsOneWidget);
    expect(find.text('Siren on at the site · SMS sent 4 of 4'), findsOneWidget);
    expect(find.text('Test alarm'), findsNothing);

    await _setLevel(tester, StatusLevel.critical);
    expect(find.text('Combined Hazard Alert'), findsOneWidget);

    await _tap(tester, find.bySemanticsLabel('Close, back to Status'));
    expect(find.text('Critical Alert'), findsOneWidget);

    // Each change was also added to the in-app Notifications list.
    final titles = (await getNotifications()).map((n) => n.title).toList();
    expect(titles, containsAll(['Landslide Watch', 'Landslide Risk: High', 'Combined Hazard Alert']));
  });

  testWidgets('Tapping a sensor card opens Sensors on that sensor', (tester) async {
    await _openApp(tester);
    await _tap(tester, find.text('Ground Movement Status'));
    await tester.pump(_latency);
    expect(find.text('Ground tilt · MPU6050'), findsOneWidget);
    expect(find.text('Limit 2.0°'), findsNothing); // painted on the chart, not a widget
  });

  testWidgets('Every tab opens', (tester) async {
    await _openApp(tester);

    await _openTab(tester, 'History');
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Combined Hazard · Critical'), findsOneWidget);
    await _tap(tester, find.text('Tests'));
    expect(find.text('Alarm test'), findsOneWidget);
    expect(find.text('Combined Hazard · Critical'), findsNothing);

    await _openTab(tester, 'Map');
    expect(find.text('Evacuation area'), findsOneWidget);

    await _openTab(tester, 'Sensors');
    expect(find.text('Soil moisture · capacitive sensor'), findsOneWidget);

    await _openTab(tester, 'Settings');
    expect(find.text('Alert thresholds'), findsOneWidget);
    expect(find.text('GeoPulse Node GP‑01'), findsOneWidget);
  });

  testWidgets('Map node opens the details sheet; View readings goes to Sensors', (tester) async {
    await _openApp(tester);
    await _openTab(tester, 'Map');
    await _tap(tester, find.bySemanticsLabel(RegExp('Sensor node GP‑01')));
    expect(find.text('Route to evac area'), findsOneWidget);

    await _tap(tester, find.text('View readings'));
    await tester.pump(_latency);
    expect(find.text('Soil moisture · capacitive sensor'), findsOneWidget);
  });

  testWidgets('Bell opens Notifications; Mark all as read clears unread', (tester) async {
    await _openApp(tester);
    await _tap(tester, find.bySemanticsLabel('Notifications, unread'));
    await tester.pump(_latency);
    expect(find.text('2 unread'), findsOneWidget);

    await _tap(tester, find.text('Mark all as read'));
    await tester.pump(_latency);
    expect(find.text('All caught up'), findsOneWidget);
  });

  testWidgets('Thresholds save shows a SnackBar; bad values are refused', (tester) async {
    await _openApp(tester);
    await _openTab(tester, 'Settings');
    await _tap(tester, find.text('Alert thresholds'));
    await tester.pump(_latency);

    await tester.enterText(find.byType(TextFormField).first, '95'); // Watch above Critical
    await _tap(tester, find.text('Save and sync to device'));
    expect(find.text('Watch must be lower than Critical.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '65');
    await _tap(tester, find.text('Save and sync to device'));
    await tester.pump(_latency);
    expect(find.text('Saved and synced to Node GP‑01.'), findsOneWidget);
    expect((await getThresholds()).soilWatchPercent, 65);
  });

  testWidgets('Send test SMS asks first', (tester) async {
    await _openApp(tester);
    await _openTab(tester, 'Settings');
    await _tap(tester, find.text('SMS alert contacts'));
    await tester.pump(_latency);
    expect(find.text('Barangay DRRM Office'), findsOneWidget);

    await _tap(tester, find.text('Send test SMS to all'));
    expect(find.text('Send a test SMS?'), findsOneWidget);
    await _tap(tester, find.text('Send test SMS'));
    await tester.pump(_latency);
    expect(find.text('Test SMS sent to all 4 contacts.'), findsOneWidget);
  });

  testWidgets('Notification settings: critical is locked on, warnings can be turned off', (tester) async {
    await _openApp(tester);
    await _openTab(tester, 'Settings');
    await _tap(tester, find.text('Notifications'));
    await tester.pump(_latency);

    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.first.value, isTrue);
    expect(switches.first.onChanged, isNull); // can't turn critical off

    await _tap(tester, find.byType(Switch).at(1));
    expect((await getNotificationPrefs()).warnings, isFalse);
  });

  testWidgets('Profile → Log out returns to Landing', (tester) async {
    await _openApp(tester);
    await _openTab(tester, 'Settings');
    await _tap(tester, find.text('Profile and role'));
    expect(find.text('[Your name]'), findsOneWidget);

    await _tap(tester, find.text('Log out'));
    await _tap(tester, find.text('Log out').last); // confirm in the dialog
    await tester.pump(_settle);
    expect(find.text('Create an account'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  testWidgets('Silence needs a full 2-second hold', (tester) async {
    var silencedCalls = 0;
    await tester.pumpWidget(_alertScreen(onSilenced: () => silencedCalls++));
    final button = find.text('Silence on this phone');
    await tester.ensureVisible(button);
    double fill() => tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor!;

    var gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(); // first frame starts the animation clock
    await tester.pump(const Duration(seconds: 1));
    expect(fill(), closeTo(0.5, 0.01));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(fill(), 0); // snapped back
    expect(silencedCalls, 0);

    gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2050));
    await gesture.up();
    await tester.pump();
    expect(silencedCalls, 1);
    expect(find.text('Silenced on this phone'), findsOneWidget);
  });

  testWidgets('Test alarm asks for confirmation first', (tester) async {
    await _openApp(tester);
    await _tap(tester, find.text('Test alarm'));
    expect(find.text('Test the site alarm?'), findsOneWidget);
    await _tap(tester, find.text('Cancel'));
    expect(find.text('Test the site alarm?'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('With "Remove animations" on, the siren ring does not pulse', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_alertScreen());
    // pumpAndSettle fails if an animation keeps repeating.
    await tester.pumpAndSettle();
    expect(find.text('Combined Hazard Alert'), findsOneWidget);
  });

  testWidgets('With animations on, the siren ring keeps pulsing', (tester) async {
    await tester.pumpWidget(_alertScreen());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });
}
