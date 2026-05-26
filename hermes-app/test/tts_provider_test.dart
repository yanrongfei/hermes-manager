import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_app/data/services/tts_service.dart';
import 'package:hermes_app/data/providers/tts_provider.dart';

class MockTtsService extends Mock implements TtsService {}

void main() {
  setUpAll(() {
    registerFallbackValue(TtsState.idle);
  });

  group('TtsService Mock', () {
    late MockTtsService mockService;

    setUp(() {
      mockService = MockTtsService();
      when(() => mockService.initialize()).thenAnswer((_) async {});
      when(() => mockService.dispose()).thenAnswer((_) async {});
      when(() => mockService.state).thenReturn(TtsState.idle);
      when(() => mockService.currentMessageId).thenReturn(null);
    });

    test('initial state is idle on mock', () {
      when(() => mockService.state).thenReturn(TtsState.idle);
      expect(mockService.state, TtsState.idle);
    });

    test('isPlaying returns correct value', () {
      when(() => mockService.isPlaying).thenReturn(true);
      expect(mockService.isPlaying, isTrue);
    });

    test('isPaused returns correct value', () {
      when(() => mockService.isPaused).thenReturn(true);
      expect(mockService.isPaused, isTrue);
    });

    test('currentMessageId returns correct value', () {
      when(() => mockService.currentMessageId).thenReturn('msg-123');
      expect(mockService.currentMessageId, 'msg-123');
    });
  });

  group('TtsNotifier', () {
    late MockTtsService mockService;
    late ProviderContainer container;

    setUp(() {
      mockService = MockTtsService();
      when(() => mockService.initialize()).thenAnswer((_) async {});
      when(() => mockService.dispose()).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          ttsServiceProvider.overrideWithValue(mockService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is idle', () {
      when(() => mockService.state).thenReturn(TtsState.idle);
      final state = container.read(ttsProvider);
      expect(state, TtsState.idle);
    });

    test('toggle stops when same message is playing', () async {
      when(() => mockService.isPlaying).thenReturn(true);
      when(() => mockService.currentMessageId).thenReturn('msg-1');
      when(() => mockService.stop()).thenAnswer((_) async {});
      when(() => mockService.state).thenReturn(TtsState.idle);

      await container.read(ttsProvider.notifier).toggle('Hello', 'msg-1');

      verify(() => mockService.stop()).called(1);
    });

    test('toggle resumes when same message is paused', () async {
      when(() => mockService.isPlaying).thenReturn(false);
      when(() => mockService.isPaused).thenReturn(true);
      when(() => mockService.currentMessageId).thenReturn('msg-1');
      when(() => mockService.resume()).thenAnswer((_) async {});
      when(() => mockService.state).thenReturn(TtsState.playing);

      await container.read(ttsProvider.notifier).toggle('Hello', 'msg-1');

      verify(() => mockService.resume()).called(1);
    });

    test('toggle speaks when no audio is playing', () async {
      when(() => mockService.isPlaying).thenReturn(false);
      when(() => mockService.isPaused).thenReturn(false);
      when(() => mockService.speak(any(), any())).thenAnswer((_) async {});
      when(() => mockService.state).thenReturn(TtsState.playing);

      await container.read(ttsProvider.notifier).toggle('Hello', 'msg-2');

      verify(() => mockService.speak('Hello', 'msg-2')).called(1);
    });

    test('speak calls service and updates state', () async {
      when(() => mockService.speak(any(), any())).thenAnswer((_) async {});
      when(() => mockService.state).thenReturn(TtsState.playing);

      await container.read(ttsProvider.notifier).speak('Test text', 'msg-1');

      verify(() => mockService.speak('Test text', 'msg-1')).called(1);
    });

    test('pause calls service and updates state', () async {
      when(() => mockService.pause()).thenAnswer((_) async {});
      when(() => mockService.state).thenReturn(TtsState.paused);

      await container.read(ttsProvider.notifier).pause();

      verify(() => mockService.pause()).called(1);
    });

    test('resume calls service and updates state', () async {
      when(() => mockService.resume()).thenAnswer((_) async {});
      when(() => mockService.state).thenReturn(TtsState.playing);

      await container.read(ttsProvider.notifier).resume();

      verify(() => mockService.resume()).called(1);
    });

    test('stop calls service and updates state', () async {
      when(() => mockService.stop()).thenAnswer((_) async {});
      when(() => mockService.state).thenReturn(TtsState.idle);

      await container.read(ttsProvider.notifier).stop();

      verify(() => mockService.stop()).called(1);
    });
  });

  group('TtsProvider Integration', () {
    late MockTtsService mockService;
    late ProviderContainer container;

    setUp(() {
      mockService = MockTtsService();
      when(() => mockService.initialize()).thenAnswer((_) async {});
      when(() => mockService.dispose()).thenAnswer((_) async {});
      when(() => mockService.state).thenReturn(TtsState.idle);
      when(() => mockService.currentMessageId).thenReturn(null);

      container = ProviderContainer(
        overrides: [
          ttsServiceProvider.overrideWithValue(mockService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('ttsServiceProvider provides singleton instance', () {
      final service1 = container.read(ttsServiceProvider);
      final service2 = container.read(ttsServiceProvider);
      expect(service1, same(service2));
    });

    test('currentTtsMessageIdProvider reflects service state', () {
      when(() => mockService.currentMessageId).thenReturn('msg-1');
      expect(container.read(currentTtsMessageIdProvider), 'msg-1');
    });

    test('currentTtsMessageIdProvider returns null when idle', () {
      when(() => mockService.currentMessageId).thenReturn(null);
      expect(container.read(currentTtsMessageIdProvider), isNull);
    });
  });

  group('TtsState enum', () {
    test('has correct values', () {
      expect(TtsState.values.length, 3);
      expect(TtsState.values.contains(TtsState.idle), isTrue);
      expect(TtsState.values.contains(TtsState.playing), isTrue);
      expect(TtsState.values.contains(TtsState.paused), isTrue);
    });
  });
}