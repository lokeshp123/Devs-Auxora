import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Make sure 'skydevs' matches the exact name in your pubspec.yaml
import 'package:skydevs/main.dart';

void main() {
  testWidgets('App loads developer login screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We pass isLoggedIn: false to simulate a user opening the app for the first time.
    await tester.pumpWidget(const SkyDevsApp(isLoggedIn: false));

    // Wait for the UI to finish building (since your login screen fetches APIs on load)
    await tester.pumpAndSettle();

    // Verify that the Login Screen loaded by looking for specific text on the screen.
    expect(find.text('Admin sign in'), findsOneWidget);
    expect(find.text('Authenticate_User()'), findsOneWidget); // Checks for your custom button

    // Ensure the dashboard hasn't loaded yet
    expect(find.text('SkyDevs Console'), findsNothing);
  });
}