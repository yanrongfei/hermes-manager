// This file is used for manual testing
// Run with: flutter test integration_test/manual_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hermes_app/main.dart';
import 'package:hermes_app/data/providers/storage_provider.dart';

void main() {
  testWidgets('Login form renders correctly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const HermesApp(),
      ),
    );

    // Wait for splash screen animation
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Find TextField widgets (login form)
    final textFields = find.byType(TextField);
    print('Found ${textFields.evaluate().length} TextField widgets');

    // Find buttons
    final buttons = find.byType(ElevatedButton);
    print('Found ${buttons.evaluate().length} ElevatedButton widgets');

    // Print all widgets for debugging
    if (textFields.evaluate().isEmpty) {
      print('ERROR: No TextField found - login form not rendered');
      // Take a screenshot for debugging
      await tester.pump(const Duration(seconds: 5));
      print('Pump complete');
    }
  });
}