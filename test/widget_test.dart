import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride/main.dart';
import 'package:ride/screens/onboarding_screen.dart';
import 'package:ride/screens/login_screen.dart';
import 'package:ride/screens/guest_track_sheet.dart';
import 'package:ride/screens/signup_sheet.dart';

void main() {
  testWidgets('Apace Parcel App Onboarding & Auth Entry Verification', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ParcelApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);

    final guestTrackFinder = find.text('Quick Track as Guest');
    await tester.ensureVisible(guestTrackFinder);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(guestTrackFinder);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GuestTrackSheet), findsOneWidget);
    Navigator.of(tester.element(find.byType(GuestTrackSheet))).pop();
    await tester.pump(const Duration(milliseconds: 400));

    final signUpFinder = find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains('Sign Up'),
    );
    await tester.ensureVisible(signUpFinder);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(signUpFinder);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SignUpSheet), findsOneWidget);
  });
}
