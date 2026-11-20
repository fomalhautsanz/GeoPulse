import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geopulse/data/auth_repository.dart' as auth;
import 'package:geopulse/main.dart';
import 'package:geopulse/models/user_profile.dart';

const _transition = Duration(milliseconds: 300);
const _authLatency = Duration(milliseconds: 600);
const _statusLatency = Duration(milliseconds: 300);

Future<void> _openApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const GeoPulseApp()); // starts on Landing
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pump();
  await tester.pump(_transition);
}

void main() {
  setUp(() async {
    await auth.logOut();
  });

  testWidgets('Landing → Log in shows errors, then logs in to Status', (
    tester,
  ) async {
    await _openApp(tester);
    expect(find.text('GeoPulse'), findsOneWidget);

    await _tapText(tester, 'Log in'); // the Landing button
    expect(find.text('Welcome back'), findsOneWidget);

    // Empty form: both fields complain, nothing happens.
    await _tapText(tester, 'Log in');
    expect(find.text('Enter your phone number or email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '09171234567');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await _tapText(tester, 'Log in');
    await tester.pump(_authLatency);
    await tester.pump(_transition);
    await tester.pump(_statusLatency);

    expect(find.text('Conditions Stable'), findsOneWidget);
    expect(auth.currentUser, isNotNull);
    // Landing and Log in were removed, so there's nothing to go back to.
    expect(
      Navigator.of(tester.element(find.text('Conditions Stable'))).canPop(),
      isFalse,
    );
  });

  testWidgets('Sign up has the four roles and a barangay field', (
    tester,
  ) async {
    await _openApp(tester);
    await _tapText(tester, 'Create an account');
    expect(find.text('Barangay / site'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<UserRole>));
    await tester.pumpAndSettle();
    for (final role in UserRole.values) {
      expect(find.text(role.label), findsWidgets);
    }
    await tester.tap(find.text('Barangay DRRM').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Ana Cruz');
    await tester.enterText(find.byType(TextFormField).at(1), '0917 123 4567');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'Brgy. San Isidro',
    );
    await tester.enterText(find.byType(TextFormField).at(3), 'longpassword');
    await _tapText(tester, 'Create account');
    await tester.pump(_authLatency);
    await tester.pump(_transition);
    await tester.pump(_statusLatency);

    expect(find.text('Conditions Stable'), findsOneWidget);
    expect(auth.currentUser?.role, UserRole.barangayDrrm);
    expect(auth.currentUser?.barangay, 'Brgy. San Isidro');
  });

  testWidgets('Sign up rejects a short phone and password, and no role', (
    tester,
  ) async {
    await _openApp(tester);
    await _tapText(tester, 'Create an account');

    await tester.enterText(find.byType(TextFormField).at(1), '0917');
    await tester.enterText(find.byType(TextFormField).at(3), 'short');
    await _tapText(tester, 'Create account');

    expect(
      find.text('Enter a full phone number, e.g. 09XX XXX XXXX'),
      findsOneWidget,
    );
    expect(find.text('Choose your role'), findsWidgets); // hint + error
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  testWidgets('Log in ↔ Sign up switch keeps Back going to Landing', (
    tester,
  ) async {
    await _openApp(tester);
    await _tapText(tester, 'Log in');
    await _tapText(tester, 'Create an account');
    expect(find.text('Create your account'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pump();
    await tester.pump(_transition);
    expect(find.text('GeoPulse'), findsOneWidget); // Landing
  });
}
