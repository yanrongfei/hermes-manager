import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hermes_app/data/providers/auth_provider.dart';
import 'package:hermes_app/data/providers/storage_provider.dart';
import 'package:hermes_app/data/providers/api_provider.dart';
import 'package:hermes_app/core/config/app_config.dart';

// Mocks
class MockDio extends Mock implements Dio {}

class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  group('AuthNotifier', () {
    late MockDio mockDio;
    late SharedPreferences prefs;
    late ProviderContainer container;

    setUpAll(() {
      registerFallbackValue(RequestOptions(path: '/'));
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mockDio = MockDio();
    });

    tearDown(() {
      if (container != null) container.dispose();
    });

    test('login success - token and user data saved', () async {
      // Arrange
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          dioProvider.overrideWithValue(mockDio),
        ],
      );

      const username = 'testuser';
      const password = 'password123';
      const accessToken = 'test_access_token';
      const refreshToken = 'test_refresh_token';

      final userData = {
        'id': 'user-123',
        'username': username,
        'createdAt': '2024-01-01T00:00:00Z',
      };

      // Mock dio.post - match all optional parameters
      when(() => mockDio.post(
        any(),
        data: any(named: 'data'),
        cancelToken: any(named: 'cancelToken'),
        options: any(named: 'options'),
      )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/auth/login'),
            statusCode: 200,
            data: {
              'access_token': accessToken,
              'refresh_token': refreshToken,
            },
          ));

      when(() => mockDio.get(
        any(),
        cancelToken: any(named: 'cancelToken'),
        options: any(named: 'options'),
      )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/auth/me'),
            statusCode: 200,
            data: userData,
          ));

      // Act
      final authNotifier = container.read(authProvider.notifier);
      final result = await authNotifier.login(username, password);

      // Print error for debugging
      if (!result) {
        print('Login failed, error: ${container.read(authProvider).error}');
      }

      // Assert
      expect(result, isTrue);

      final state = container.read(authProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.user?.username, equals(username));

      // Verify token saved to storage
      final storedToken = prefs.getString(AppConfig.accessTokenKey);
      expect(storedToken, equals(accessToken));
    });

    test('login failure - invalid credentials', () async {
      when(() => mockDio.post(
        any(),
        data: any(named: 'data'),
        cancelToken: any(named: 'cancelToken'),
        options: any(named: 'options'),
      )).thenThrow(DioException(
            requestOptions: RequestOptions(path: '/auth/login'),
            response: Response(
              requestOptions: RequestOptions(path: '/auth/login'),
              statusCode: 401,
              data: {'msg': 'Invalid credentials'},
            ),
          ));

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          dioProvider.overrideWithValue(mockDio),
        ],
      );

      // Act
      final authNotifier = container.read(authProvider.notifier);
      final result = await authNotifier.login('wronguser', 'wrongpass');

      // Assert
      expect(result, isFalse);

      final state = container.read(authProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.error, contains('Invalid credentials'));
    });

    test('logout - clears tokens and user state', () async {
      SharedPreferences.setMockInitialValues({
        AppConfig.accessTokenKey: 'existing_token',
        AppConfig.refreshTokenKey: 'existing_refresh',
      });
      prefs = await SharedPreferences.getInstance();

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          dioProvider.overrideWithValue(mockDio),
        ],
      );

      // Act
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.logout();

      // Assert
      final state = container.read(authProvider);
      expect(state.isAuthenticated, isFalse);
      expect(prefs.getString(AppConfig.accessTokenKey), isNull);
    });

    test('checkAuth - restores user from valid token', () async {
      SharedPreferences.setMockInitialValues({
        AppConfig.accessTokenKey: 'valid_token',
        AppConfig.refreshTokenKey: 'valid_refresh',
      });
      prefs = await SharedPreferences.getInstance();

      final userData = {
        'id': 'user-456',
        'username': 'existinguser',
        'createdAt': '2024-01-01T00:00:00Z',
      };

      when(() => mockDio.get(
        any(),
        cancelToken: any(named: 'cancelToken'),
        options: any(named: 'options'),
      )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/auth/me'),
            statusCode: 200,
            data: userData,
          ));

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          dioProvider.overrideWithValue(mockDio),
        ],
      );

      // Act
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.checkAuth();

      // Assert
      final state = container.read(authProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.user?.username, equals('existinguser'));
    });

    test('checkAuth - fails with invalid token', () async {
      SharedPreferences.setMockInitialValues({
        AppConfig.accessTokenKey: 'invalid_token',
        AppConfig.refreshTokenKey: 'invalid_refresh',
      });
      prefs = await SharedPreferences.getInstance();

      when(() => mockDio.get(
        any(),
        cancelToken: any(named: 'cancelToken'),
        options: any(named: 'options'),
      )).thenThrow(DioException(
            requestOptions: RequestOptions(path: '/auth/me'),
            response: Response(
              requestOptions: RequestOptions(path: '/auth/me'),
              statusCode: 401,
              data: {'msg': 'Unauthorized'},
            ),
          ));

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          dioProvider.overrideWithValue(mockDio),
        ],
      );

      // Act
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.checkAuth();

      // Assert - should logout and clear state
      final state = container.read(authProvider);
      expect(state.isAuthenticated, isFalse);
    });
  });
}