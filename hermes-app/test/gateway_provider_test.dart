import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hermes_app/data/providers/gateway_provider.dart';
import 'package:hermes_app/data/providers/storage_provider.dart';
import 'package:hermes_app/data/providers/api_provider.dart';
import 'package:hermes_app/data/models/gateway.dart';
import 'package:hermes_app/core/config/app_config.dart';

class MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
  });

  group('Gateway Model', () {
    test('fromJson parses gateway correctly', () {
      final json = {
        'id': 'gw-1',
        'name': 'Test Gateway',
        'address': 'http://localhost:8642',
        'api_key': 'key-123',
        'status': 'online',
        'last_seen': 1704067200,
        'created_at': 1704067200,
        'profile_count': 3,
        'agent_count': 5,
      };

      final gw = Gateway.fromJson(json);
      expect(gw.id, 'gw-1');
      expect(gw.name, 'Test Gateway');
      expect(gw.address, 'http://localhost:8642');
      expect(gw.apiKey, 'key-123');
      expect(gw.status, 'online');
      expect(gw.isOnline, isTrue);
      expect(gw.profileCount, 3);
      expect(gw.agentCount, 5);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'gw-2',
        'address': 'http://localhost:8642',
        'created_at': 1704067200,
      };

      final gw = Gateway.fromJson(json);
      expect(gw.name, isNull);
      expect(gw.status, 'unknown');
      expect(gw.isOnline, isFalse);
      expect(gw.profileCount, 0);
      expect(gw.agentCount, 0);
    });

    test('isOnline returns false for offline status', () {
      final json = {
        'id': 'gw-3',
        'address': 'http://localhost:8642',
        'status': 'offline',
        'created_at': 1704067200,
      };
      final gw = Gateway.fromJson(json);
      expect(gw.isOnline, isFalse);
    });
  });

  group('GatewayStatus Model', () {
    test('fromJson parses status correctly', () {
      final json = {
        'profile': 'default',
        'host': '127.0.0.1',
        'port': 8642,
        'url': 'http://127.0.0.1:8642',
        'running': true,
        'pid': 12345,
        'model': 'gpt-4',
        'provider': 'openai',
        'profile_path': '/home/.hermes',
        'skills_count': 10,
        'has_env': true,
        'has_soul': false,
      };

      final status = GatewayStatus.fromJson(json);
      expect(status.profile, 'default');
      expect(status.host, '127.0.0.1');
      expect(status.port, 8642);
      expect(status.running, isTrue);
      expect(status.pid, 12345);
      expect(status.model, 'gpt-4');
      expect(status.provider, 'openai');
      expect(status.skillsCount, 10);
      expect(status.hasEnv, isTrue);
      expect(status.hasSoul, isFalse);
    });

    test('fromJson uses defaults for missing fields', () {
      final json = <String, dynamic>{};

      final status = GatewayStatus.fromJson(json);
      expect(status.profile, '');
      expect(status.host, '127.0.0.1');
      expect(status.port, 8642);
      expect(status.running, isFalse);
      expect(status.skillsCount, 0);
      expect(status.hasEnv, isFalse);
      expect(status.hasSoul, isFalse);
    });
  });

  group('DiscoveredGateway Model', () {
    test('fromJson parses discovered gateway', () {
      final json = {
        'address': 'http://192.168.1.100:8642',
        'online': true,
        'profile_name': 'my-agent',
        'model': 'claude-3',
        'provider': 'anthropic',
        'active': true,
        'api_key': 'test-key',
      };

      final dg = DiscoveredGateway.fromJson(json);
      expect(dg.address, 'http://192.168.1.100:8642');
      expect(dg.online, isTrue);
      expect(dg.profileName, 'my-agent');
      expect(dg.model, 'claude-3');
      expect(dg.provider, 'anthropic');
      expect(dg.active, isTrue);
      expect(dg.apiKey, 'test-key');
    });

    test('fromJson uses defaults for missing fields', () {
      final json = {'address': 'http://localhost:8642'};

      final dg = DiscoveredGateway.fromJson(json);
      expect(dg.online, isTrue);
      expect(dg.profileName, isNull);
      expect(dg.active, isFalse);
      expect(dg.apiKey, isNull);
    });
  });

  group('GatewaysNotifier', () {
    late MockDio mockDio;
    late SharedPreferences prefs;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        AppConfig.accessTokenKey: 'test_token',
      });
      prefs = await SharedPreferences.getInstance();
      mockDio = MockDio();

      // Mock loadGateways (called in constructor)
      when(() => mockDio.get(any())).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/gateways'),
        statusCode: 200,
        data: [],
      ));

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          dioProvider.overrideWithValue(mockDio),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('loadGateways fetches gateways from API', () async {
      when(() => mockDio.get(any())).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/gateways'),
        statusCode: 200,
        data: [
          {
            'id': 'gw-1',
            'name': 'Test',
            'address': 'http://localhost:8642',
            'status': 'online',
            'created_at': 1704067200,
          },
        ],
      ));

      await container.read(gatewaysNotifierProvider.notifier).loadGateways();

      final state = container.read(gatewaysNotifierProvider);
      expect(state.value, isNotNull);
      expect(state.value!.length, 1);
      expect(state.value!.first.name, 'Test');
    });

    test('loadGateways handles error', () async {
      when(() => mockDio.get(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/gateways'),
        type: DioExceptionType.connectionTimeout,
      ));

      await container.read(gatewaysNotifierProvider.notifier).loadGateways();
      final state = container.read(gatewaysNotifierProvider);
      expect(state.hasError, isTrue);
    });

    test('addGateway sends correct data', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/gateways'),
        statusCode: 201,
        data: {},
      ));

      await container.read(gatewaysNotifierProvider.notifier).addGateway(
        'http://localhost:8642',
        name: 'My Gateway',
        apiKey: 'key-123',
      );

      verify(() => mockDio.post(
        any(),
        data: {
          'address': 'http://localhost:8642',
          'name': 'My Gateway',
          'api_key': 'key-123',
        },
      )).called(1);
    });

    test('deleteGateway calls API with correct id', () async {
      when(() => mockDio.delete(any())).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/gateways/gw-1'),
        statusCode: 204,
      ));

      await container.read(gatewaysNotifierProvider.notifier).deleteGateway('gw-1');

      verify(() => mockDio.delete('/gateways/gw-1')).called(1);
    });

    test('updateGateway sends correct data', () async {
      when(() => mockDio.patch(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/gateways/gw-1'),
        statusCode: 200,
        data: {},
      ));

      await container.read(gatewaysNotifierProvider.notifier).updateGateway(
        'gw-1',
        name: 'Updated Name',
        apiKey: 'new-key',
      );

      verify(() => mockDio.patch(
        any(),
        data: {'name': 'Updated Name', 'api_key': 'new-key'},
      )).called(1);
    });

    test('syncGateway calls correct endpoint', () async {
      when(() => mockDio.post(any())).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/gateways/gw-1/sync'),
        statusCode: 200,
        data: {},
      ));

      await container.read(gatewaysNotifierProvider.notifier).syncGateway('gw-1');

      verify(() => mockDio.post('/gateways/gw-1/sync')).called(1);
    });

    test('testGateway returns online status', () async {
      when(() => mockDio.post(any())).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/gateways/gw-1/test'),
        statusCode: 200,
        data: {'gateway_id': 'gw-1', 'online': true},
      ));

      final result = await container.read(gatewaysNotifierProvider.notifier).testGateway('gw-1');
      expect(result, isTrue);
    });

    test('testGateway returns false on error', () async {
      when(() => mockDio.post(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/gateways/gw-1/test'),
      ));

      final result = await container.read(gatewaysNotifierProvider.notifier).testGateway('gw-1');
      expect(result, isFalse);
    });

    test('fetchGatewayStatus returns status list', () async {
      when(() => mockDio.get('/gateways/status')).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/gateways/status'),
        statusCode: 200,
        data: [
          {
            'profile': 'default',
            'host': '127.0.0.1',
            'port': 8642,
            'url': 'http://127.0.0.1:8642',
            'running': true,
            'pid': 12345,
          },
        ],
      ));

      final statuses = await container.read(gatewaysNotifierProvider.notifier).fetchGatewayStatus();
      expect(statuses.length, 1);
      expect(statuses.first.profile, 'default');
      expect(statuses.first.running, isTrue);
    });

    test('discoverGateways populates discovered list', () async {
      when(() => mockDio.get('/gateways/discover')).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/gateways/discover'),
        statusCode: 200,
        data: [
          {
            'address': 'http://192.168.1.100:8642',
            'online': true,
            'profile_name': 'agent-1',
          },
        ],
      ));

      await container.read(gatewaysNotifierProvider.notifier).discoverGateways();
      final notifier = container.read(gatewaysNotifierProvider.notifier);
      expect(notifier.discovered.length, 1);
      expect(notifier.discovered.first.address, 'http://192.168.1.100:8642');
      expect(notifier.isScanning, isFalse);
    });

    test('stopGateway calls correct endpoint', () async {
      when(() => mockDio.post(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/gateways/stop'),
        statusCode: 200,
        data: {'success': true, 'message': 'Stopped'},
      ));

      final result = await container.read(gatewaysNotifierProvider.notifier).stopGateway('default');
      expect(result['success'], isTrue);
    });
  });
}
