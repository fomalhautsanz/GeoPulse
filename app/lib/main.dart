import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/status_repository.dart';
import 'firebase_options.dart'; // created by `flutterfire configure`
import 'models/device_status.dart';
import 'screens/critical_alert_screen.dart';
import 'screens/landing_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

/// Lets code outside the widget tree (a tapped notification) open screens.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// Every Dart program starts at `main()`. It's `async` because the
/// notification setup has to finish before the app starts.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // needed before plugins run
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // The database rules need a signed-in user; anonymous is enough for the app.
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (e) {
    debugPrint('Firebase setup failed: $e'); // the app still opens
  }
  final openedFromCriticalAlert = await NotificationService.init();
  NotificationService.fallbackOpenCritical = _openCriticalAlert;
  if (openedFromCriticalAlert) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCriticalAlert());
  }
  runApp(const GeoPulseApp());
}

/// Opens the Critical alert when nothing else handles it, e.g. the app was
/// closed and the full-screen alarm launched it.
Future<void> _openCriticalAlert() async {
  final context = appNavigatorKey.currentContext;
  if (context == null) return;
  final status = await getStatus();
  if (status.level != StatusLevel.critical || !context.mounted) return;
  appNavigatorKey.currentState?.push(
    criticalAlertRoute(context, status: status, silenced: false, onSilenced: () {}),
  );
}

/// The root widget: the app-wide theme and the first screen.
class GeoPulseApp extends StatelessWidget {
  const GeoPulseApp({super.key, this.home = const LandingScreen()});

  /// The first screen. Tests can start somewhere else.
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoPulse',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: buildAppTheme(),
      home: home,
    );
  }
}
