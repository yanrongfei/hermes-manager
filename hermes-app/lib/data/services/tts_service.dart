import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { idle, playing, paused }

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  TtsState _state = TtsState.idle;
  String? _currentMessageId;
  String? _currentText;

  TtsState get state => _state;
  String? get currentMessageId => _currentMessageId;
  bool get isPlaying => _state == TtsState.playing;
  bool get isPaused => _state == TtsState.paused;

  Future<void> initialize() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      _state = TtsState.playing;
    });

    _flutterTts.setCompletionHandler(() {
      _state = TtsState.idle;
      _currentMessageId = null;
      _currentText = null;
    });

    _flutterTts.setCancelHandler(() {
      _state = TtsState.idle;
      _currentMessageId = null;
      _currentText = null;
    });

    _flutterTts.setPauseHandler(() {
      _state = TtsState.paused;
    });

    _flutterTts.setContinueHandler(() {
      _state = TtsState.playing;
    });

    _flutterTts.setErrorHandler((msg) {
      _state = TtsState.idle;
      _currentMessageId = null;
      _currentText = null;
    });
  }

  Future<void> speak(String text, String messageId) async {
    if (_state == TtsState.playing && _currentMessageId == messageId) {
      await stop();
      return;
    }

    await stop();

    _currentMessageId = messageId;
    _currentText = text;
    _state = TtsState.playing;

    await _flutterTts.speak(text);
  }

  Future<void> pause() async {
    if (_state == TtsState.playing) {
      await _flutterTts.pause();
      _state = TtsState.paused;
    }
  }

  Future<void> resume() async {
    if (_state == TtsState.paused && _currentText != null) {
      _state = TtsState.playing;
      await _flutterTts.speak(_currentText!);
    }
  }

  Future<void> stop() async {
    if (_state != TtsState.idle) {
      await _flutterTts.stop();
      _state = TtsState.idle;
      _currentMessageId = null;
      _currentText = null;
    }
  }

  Future<void> dispose() async {
    await stop();
  }
}