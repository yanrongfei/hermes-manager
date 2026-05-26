import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tts_service.dart';

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(() => service.dispose());
  return service;
});

final ttsProvider = StateNotifierProvider<TtsNotifier, TtsState>((ref) {
  final service = ref.watch(ttsServiceProvider);
  return TtsNotifier(service);
});

final currentTtsMessageIdProvider = Provider<String?>((ref) {
  final service = ref.watch(ttsServiceProvider);
  return service.currentMessageId;
});

class TtsNotifier extends StateNotifier<TtsState> {
  final TtsService _service;

  TtsNotifier(this._service) : super(TtsState.idle) {
    _init();
  }

  Future<void> _init() async {
    await _service.initialize();
  }

  Future<void> speak(String text, String messageId) async {
    await _service.speak(text, messageId);
    state = _service.state;
  }

  Future<void> pause() async {
    await _service.pause();
    state = _service.state;
  }

  Future<void> resume() async {
    await _service.resume();
    state = _service.state;
  }

  Future<void> stop() async {
    await _service.stop();
    state = _service.state;
  }

  Future<void> toggle(String text, String messageId) async {
    if (_service.isPlaying && _service.currentMessageId == messageId) {
      await stop();
    } else if (_service.isPaused && _service.currentMessageId == messageId) {
      await resume();
    } else {
      await speak(text, messageId);
    }
  }
}