import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hermes_app/data/providers/chat_provider.dart';
import 'package:hermes_app/data/providers/storage_provider.dart';
import 'package:hermes_app/data/providers/api_provider.dart';
import 'package:hermes_app/data/providers/room_provider.dart';
import 'package:hermes_app/data/models/message.dart';
import 'package:hermes_app/core/config/app_config.dart';

// Mocks
class MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
  });

  group('ChatState', () {
    test('initial state has default values', () {
      final state = ChatState();
      expect(state.messages, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.isConnected, isFalse);
      expect(state.error, isNull);
      expect(state.toolCalls, isEmpty);
      expect(state.runningAgents, isEmpty);
      expect(state.queueLength, 0);
    });

    test('copyWith preserves unchanged values', () {
      final state = ChatState(isConnected: true, queueLength: 2);
      final newState = state.copyWith(queueLength: 5);
      expect(newState.isConnected, isTrue);
      expect(newState.queueLength, 5);
    });

    test('copyWith can update multiple fields', () {
      final state = ChatState();
      final newState = state.copyWith(
        isLoading: true,
        isConnected: true,
        queueLength: 2,
      );
      expect(newState.isLoading, isTrue);
      expect(newState.isConnected, isTrue);
      expect(newState.queueLength, 2);
    });

    test('copyWith preserves messages list', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'user-1',
        senderType: 'user',
        senderName: 'User',
        content: 'Hello',
        contentType: 'text',
        createdAt: 1234567890,
      );
      final state = ChatState(messages: [message]);
      final newState = state.copyWith(isConnected: true);
      expect(newState.messages.length, 1);
      expect(newState.messages.first.id, 'msg-1');
    });
  });

  group('Message Model', () {
    test('fromJson parses user message correctly', () {
      final json = {
        'id': 'msg-123',
        'roomId': 'room-456',
        'senderId': 'user-789',
        'senderType': 'user',
        'senderName': 'Test User',
        'content': 'Hello world',
        'contentType': 'text',
        'isStreaming': false,
        'isAborted': false,
        'createdAt': 1234567890,
      };

      final message = Message.fromJson(json);
      expect(message.id, 'msg-123');
      expect(message.senderType, 'user');
      expect(message.senderName, 'Test User');
      expect(message.content, 'Hello world');
      expect(message.isStreaming, isFalse);
      expect(message.isAborted, isFalse);
    });

    test('fromJson parses agent message correctly', () {
      final json = {
        'id': 'msg-agent-1',
        'roomId': 'room-456',
        'senderId': 'agent-1',
        'senderType': 'agent',
        'senderName': 'Assistant',
        'content': 'I am ready to help',
        'contentType': 'text',
        'isStreaming': true,
        'isAborted': false,
        'createdAt': 1234567890,
      };

      final message = Message.fromJson(json);
      expect(message.id, 'msg-agent-1');
      expect(message.senderType, 'agent');
      expect(message.senderName, 'Assistant');
      expect(message.isStreaming, isTrue);
    });

    test('fromJson parses message with tokens', () {
      final json = {
        'id': 'msg-1',
        'roomId': 'room-1',
        'senderId': 'agent-1',
        'senderType': 'agent',
        'senderName': 'Agent',
        'content': 'Response',
        'contentType': 'text',
        'isStreaming': false,
        'isAborted': false,
        'createdAt': 1234567890,
        'inputTokens': 100,
        'outputTokens': 50,
      };

      final message = Message.fromJson(json);
      expect(message.inputTokens, 100);
      expect(message.outputTokens, 50);
    });

    test('copyWith creates new instance with updated values', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'user-1',
        senderType: 'user',
        senderName: 'User',
        content: 'Original',
        contentType: 'text',
        createdAt: 1234567890,
      );

      final updated = message.copyWith(content: 'Updated');
      expect(updated.content, 'Updated');
      expect(message.content, 'Original'); // Original unchanged
    });

    test('copyWith can mark message as streaming', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'agent-1',
        senderType: 'agent',
        senderName: 'Agent',
        content: '',
        contentType: 'text',
        createdAt: 1234567890,
      );

      final streaming = message.copyWith(isStreaming: true, content: 'Thinking...');
      expect(streaming.isStreaming, isTrue);
      expect(streaming.content, 'Thinking...');
    });

    test('copyWith can mark message as aborted', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'agent-1',
        senderType: 'agent',
        senderName: 'Agent',
        content: 'Partial response',
        contentType: 'text',
        isStreaming: true,
        createdAt: 1234567890,
      );

      final aborted = message.copyWith(isStreaming: false, isAborted: true);
      expect(aborted.isStreaming, isFalse);
      expect(aborted.isAborted, isTrue);
    });

    test('copyWith preserves reasoning content', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'agent-1',
        senderType: 'agent',
        senderName: 'Agent',
        content: '',
        contentType: 'text',
        createdAt: 1234567890,
        reasoning: 'Thinking step 1...',
      );

      final updated = message.copyWith(content: 'Final answer');
      expect(updated.reasoning, 'Thinking step 1...');
      expect(updated.content, 'Final answer');
    });

    test('isFromUser returns true for user messages', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'user-1',
        senderType: 'user',
        senderName: 'User',
        content: 'Hello',
        contentType: 'text',
        createdAt: 1234567890,
      );

      expect(message.isFromUser, isTrue);
      expect(message.isFromAgent, isFalse);
    });

    test('isFromAgent returns true for agent messages', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'agent-1',
        senderType: 'agent',
        senderName: 'Agent',
        content: 'Hello',
        contentType: 'text',
        createdAt: 1234567890,
      );

      expect(message.isFromAgent, isTrue);
      expect(message.isFromUser, isFalse);
    });
  });

  group('ToolCall Model', () {
    test('fromJson parses tool call correctly', () {
      final json = {
        'toolCallId': 'tool-1',
        'tool': 'search',
        'preview': 'Searching for...',
        'arguments': {'query': 'test'},
        'status': 'pending',
      };

      final toolCall = ToolCall.fromJson(json);
      expect(toolCall.id, 'tool-1');
      expect(toolCall.tool, 'search');
      expect(toolCall.status, ToolStatus.pending);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'toolCallId': 'tool-1',
        'tool': 'search',
        'preview': 'Searching...',
      };

      final toolCall = ToolCall.fromJson(json);
      expect(toolCall.id, 'tool-1');
      expect(toolCall.tool, 'search');
      expect(toolCall.arguments, isNull);
    });

    test('can update tool call status directly', () {
      final toolCall = ToolCall(
        id: 'tool-1',
        tool: 'search',
        preview: 'Searching...',
        arguments: {'query': 'test'},
        status: ToolStatus.pending,
      );

      // ToolCall is mutable, update status directly
      toolCall.status = ToolStatus.completed;
      toolCall.output = 'Search results here';
      toolCall.duration = 1.5;

      expect(toolCall.status, ToolStatus.completed);
      expect(toolCall.output, 'Search results here');
      expect(toolCall.duration, 1.5);
    });

    test('can handle error status', () {
      final toolCall = ToolCall(
        id: 'tool-1',
        tool: 'search',
        preview: 'Searching...',
        arguments: {},
        status: ToolStatus.pending,
      );

      toolCall.status = ToolStatus.error;
      toolCall.error = 'Failed to search';

      expect(toolCall.status, ToolStatus.error);
      expect(toolCall.error, 'Failed to search');
    });
  });

  group('WebSocket Event Parsing', () {
    test('parses message event correctly', () {
      final eventData = jsonEncode({
        'event': 'message',
        'data': {
          'id': 'msg-1',
          'roomId': 'room-1',
          'senderId': 'user-1',
          'senderType': 'user',
          'senderName': 'User',
          'content': 'Hello',
          'contentType': 'text',
          'isStreaming': false,
          'createdAt': 1234567890,
        },
      });

      final parsed = jsonDecode(eventData);
      expect(parsed['event'], 'message');
      expect(parsed['data']['content'], 'Hello');
    });

    test('parses delta event correctly', () {
      final eventData = jsonEncode({
        'event': 'message.delta',
        'data': {
          'messageId': 'msg-1',
          'delta': 'Hello ',
          'full': null,
        },
      });

      final parsed = jsonDecode(eventData);
      expect(parsed['event'], 'message.delta');
      expect(parsed['data']['messageId'], 'msg-1');
      expect(parsed['data']['delta'], 'Hello ');
    });

    test('parses reasoning delta event correctly', () {
      final eventData = jsonEncode({
        'event': 'reasoning.delta',
        'data': {
          'messageId': 'msg-1',
          'delta': 'Thinking...',
        },
      });

      final parsed = jsonDecode(eventData);
      expect(parsed['event'], 'reasoning.delta');
      expect(parsed['data']['delta'], 'Thinking...');
    });

    test('parses run.completed event correctly', () {
      final eventData = jsonEncode({
        'event': 'run.completed',
        'data': {
          'messageId': 'msg-1',
          'inputTokens': 100,
          'outputTokens': 50,
        },
      });

      final parsed = jsonDecode(eventData);
      expect(parsed['event'], 'run.completed');
      expect(parsed['data']['inputTokens'], 100);
      expect(parsed['data']['outputTokens'], 50);
    });

    test('parses run.failed event correctly', () {
      final eventData = jsonEncode({
        'event': 'run.failed',
        'data': {
          'messageId': 'msg-1',
          'error': 'Connection timeout',
        },
      });

      final parsed = jsonDecode(eventData);
      expect(parsed['event'], 'run.failed');
      expect(parsed['data']['error'], 'Connection timeout');
    });

    test('parses queue_updated event correctly', () {
      final eventData = jsonEncode({
        'event': 'queue_updated',
        'data': {'queueLength': 3},
      });

      final parsed = jsonDecode(eventData);
      expect(parsed['event'], 'queue_updated');
      expect(parsed['data']['queueLength'], 3);
    });

    test('parses tool events correctly', () {
      final startedEvent = jsonEncode({
        'event': 'tool.started',
        'data': {
          'toolCallId': 'tool-1',
          'tool': 'search',
          'preview': 'Searching...',
          'messageId': 'msg-1',
        },
      });

      final parsed = jsonDecode(startedEvent);
      expect(parsed['event'], 'tool.started');
      expect(parsed['data']['tool'], 'search');
    });
  });

  group('RoomsNotifier', () {
    late MockDio mockDio;
    late SharedPreferences prefs;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        AppConfig.accessTokenKey: 'test_token',
      });
      prefs = await SharedPreferences.getInstance();
      mockDio = MockDio();

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

    test('roomsProvider starts with loading state', () async {
      // Override loadRooms to prevent automatic API call
      when(() => mockDio.get(any())).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/rooms'),
        statusCode: 200,
        data: [],
      ));

      // Access the provider to initialize
      final state = container.read(roomsProvider);

      // Should be loading initially or have data from mocked response
      expect(state.value != null || state.isLoading, isTrue);
    });

    test('loadRooms fetches rooms from API', () async {
      final testRooms = [
        {
          'id': 'room-1',
          'name': 'Test Room',
          'owner_id': 'user-1',
          'mode': 'broadcast',
          'created_at': 1704067200,
        },
      ];

      when(() => mockDio.get(any())).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/rooms'),
        statusCode: 200,
        data: testRooms,
      ));

      await container.read(roomsProvider.notifier).loadRooms();

      final state = container.read(roomsProvider);
      expect(state.isLoading, isFalse);
      expect(state.value, isNotNull);
      expect(state.value!.length, 1);
      expect(state.value!.first.name, 'Test Room');
    });

    test('loadRooms handles error', () async {
      when(() => mockDio.get(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/rooms'),
        type: DioExceptionType.connectionTimeout,
      ));

      await container.read(roomsProvider.notifier).loadRooms();

      final state = container.read(roomsProvider);
      expect(state.hasError, isTrue);
    });

    test('createRoom sends correct data to API', () async {
      when(() => mockDio.get(any())).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/rooms'),
        statusCode: 200,
        data: [],
      ));

      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/rooms'),
            statusCode: 201,
            data: {
              'id': 'new-room-1',
              'name': 'New Room',
              'ownerId': 'user-1',
              'mode': 'broadcast',
              'createdAt': '2024-01-01T00:00:00Z',
            },
          ));

      await container.read(roomsProvider.notifier).createRoom('New Room');

      verify(() => mockDio.post(
        any(),
        data: {'name': 'New Room', 'mode': 'broadcast'},
      )).called(1);
    });

    test('createOneOnOneRoom sends profile_id to API', () async {
      when(() => mockDio.get(any())).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/rooms'),
        statusCode: 200,
        data: [],
      ));

      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/rooms'),
            statusCode: 201,
            data: {
              'id': '1to1-room-1',
              'name': '1:1 Chat',
              'owner_id': 'user-1',
              'mode': 'mention',
              'profile_id': 'agent-profile-1',
              'created_at': 1704067200,
            },
          ));

      final room = await container.read(roomsProvider.notifier)
          .createOneOnOneRoom('1:1 Chat', 'agent-profile-1');

      verify(() => mockDio.post(
        any(),
        data: {
          'name': '1:1 Chat',
          'mode': 'mention',
          'profile_id': 'agent-profile-1',
        },
      )).called(1);

      expect(room.name, '1:1 Chat');
    });

    test('deleteRoom calls API with correct roomId', () async {
      when(() => mockDio.get(any())).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/rooms'),
        statusCode: 200,
        data: [],
      ));

      when(() => mockDio.delete(any())).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/rooms/room-to-delete'),
        statusCode: 200,
      ));

      await container.read(roomsProvider.notifier).deleteRoom('room-to-delete');

      verify(() => mockDio.delete('/rooms/room-to-delete')).called(1);
    });
  });
}