import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/config/app_config.dart';
import '../models/message.dart';
import 'storage_provider.dart';

class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final bool isConnected;
  final String? error;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isConnected = false,
    this.error,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isConnected,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      error: error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final String roomId;
  final Ref _ref;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  ChatNotifier(this.roomId, this._ref) : super(ChatState()) {
    _connect();
  }

  Future<void> _connect() async {
    final storage = _ref.read(storageProvider);
    final token = await storage.get(AppConfig.accessTokenKey);
    if (token == null) return;

    state = state.copyWith(isLoading: true);

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('${AppConfig.baseUrl}/ws/chat?token=$token'),
      );

      // Join room
      _channel!.sink.add(jsonEncode({
        'event': 'join',
        'data': {'roomId': roomId},
      }));

      _subscription = _channel!.stream.listen(
        (data) {
          final json = jsonDecode(data);
          final event = json['event'] as String;
          final payload = json['data'] as Map<String, dynamic>;

          switch (event) {
            case 'message':
              final msg = Message.fromJson(payload);
              state = state.copyWith(
                messages: [...state.messages, msg],
                isLoading: false,
                isConnected: true,
              );
              break;
            case 'member_joined':
              break;
            case 'member_left':
              break;
          }
        },
        onError: (e) {
          state = state.copyWith(error: e.toString(), isConnected: false);
        },
        onDone: () {
          state = state.copyWith(isConnected: false);
        },
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  void sendMessage(String content) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({
      'event': 'message',
      'data': {'content': content},
    }));
  }

  void sendTyping() {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({'event': 'typing'}));
  }

  void sendStopTyping() {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({'event': 'stop_typing'}));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider.family<ChatNotifier, ChatState, String>((ref, roomId) {
  return ChatNotifier(roomId, ref);
});