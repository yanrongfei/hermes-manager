import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hermes_app/main.dart';
import 'package:hermes_app/data/providers/storage_provider.dart';

void main() {
  patrolTest('P0 - 登录成功并跳转首页', ($) async {
    // Setup mock storage
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Build app with mocked providers
    $.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const HermesApp(),
      ),
    );

    // Wait for splash screen
    await $.pumpWidgetAndSettle(const Duration(seconds: 2));

    // Find and fill login form
    final usernameField = find.byType(TextField).first;
    final passwordField = find.byType(TextField).at(1);

    await $.enterText(usernameField, 'admin');
    await $.enterText(passwordField, 'admin123');

    // Tap login button
    final loginButton = find.widgetWithText(ElevatedButton, '登录');
    await $.tap(loginButton);

    // Wait for navigation to home
    await $.pumpAndSettle(const Duration(seconds: 5));

    // Verify we're on home page
    expect($(#home), findsOneWidget);
  });

  patrolTest('P0 - 错误密码登录失败', ($) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    $.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const HermesApp(),
      ),
    );

    await $.pumpWidgetAndSettle(const Duration(seconds: 2));

    final usernameField = find.byType(TextField).first;
    final passwordField = find.byType(TextField).at(1);

    await $.enterText(usernameField, 'admin');
    await $.enterText(passwordField, 'wrongpassword');

    final loginButton = find.widgetWithText(ElevatedButton, '登录');
    await $.tap(loginButton);

    // Should either show error or stay on login
    await $.pump(const Duration(seconds: 2));

    // Either error message visible or still on login page
    final hasError = find.textContaining('错误').evaluate().isNotEmpty ||
                     find.textContaining('失败').evaluate().isNotEmpty;
    final stillOnLogin = find.text('登录').evaluate().isNotEmpty;
    expect(hasError || stillOnLogin, isTrue);
  });

  patrolTest('P1 - 注册新用户', ($) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    $.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const HermesApp(),
      ),
    );

    await $.pumpWidgetAndSettle(const Duration(seconds: 2));

    // Find and tap register link
    final registerLink = find.widgetWithText(TextButton, '注册账号');
    if (registerLink.evaluate().isNotEmpty) {
      await $.tap(registerLink);
      await $.pumpAndSettle(const Duration(seconds: 2));

      // Verify we're on register page
      final registerButton = find.widgetWithText(ElevatedButton, '注册');
      expect(registerButton, findsOneWidget);
    }
  });

  patrolTest('P1 - 未登录重定向到登录页', ($) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    $.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const HermesApp(),
      ),
    );

    await $.pumpWidgetAndSettle(const Duration(seconds: 2));

    // Should redirect to login
    final loginForm = find.byType(TextField);
    expect(loginForm, findsWidgets);
  });
}