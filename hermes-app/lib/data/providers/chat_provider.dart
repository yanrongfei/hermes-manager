import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/config/app_config.dart';
import '../models/message.dart';
import 'api_provider.dart';
import 'storage_provider.dart';

class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final bool isConnected;
  final String? error;
  final Map<String, List<ToolCall>> toolCalls;
  final Set<String> runningAgents;
  final String? compressingStatus;
  final int queueLength;
  final Map<String, int> thinkingStartedAt; // messageId -> timestamp ms

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isConnected = false,
    this.error,
    this.toolCalls = const {},
    this.runningAgents = const {},
    this.compressingStatus,
    this.queueLength = 0,
    this.thinkingStartedAt = const {},
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isConnected,
    String? error,
    Map<String, List<ToolCall>>? toolCalls,
    Set<String>? runningAgents,
    String? compressingStatus,
    int? queueLength,
    Map<String, int>? thinkingStartedAt,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      error: error,
      toolCalls: toolCalls ?? this.toolCalls,
      runningAgents: runningAgents ?? this.runningAgents,
      compressingStatus: compressingStatus ?? this.compressingStatus,
      queueLength: queueLength ?? this.queueLength,
      thinkingStartedAt: thinkingStartedAt ?? this.thinkingStartedAt,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final String roomId;
  final Ref _ref;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  ChatNotifier(this.roomId, this._ref) : super(ChatState()) {
    _init();
  }

  Future<void> _init() async {
    await _loadHistory();
    await _connect();
  }

  Future<void> _loadHistory() async {
    state = state.copyWith(isLoading: true);
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get('/rooms/$roomId/messages', queryParameters: {'limit': 50});
      final data = response.data;
      final List msgs = data['messages'] ?? [];
      final messages = msgs.map((json) => Message.fromJson(json)).toList();
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _connect() async {
    final storage = _ref.read(storageProvider);
    final token = await storage.get(AppConfig.accessTokenKey);
    if (token == null) return;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('${AppConfig.wsUrl}/ws/chat?token=$token'),
      );

      _channel!.sink.add(jsonEncode({
        'event': 'join',
        'data': {'roomId': roomId},
      }));

      _subscription = _channel!.stream.listen(
        (data) => _handleMessage(data),
        onError: (e) {
          // Clear running agents and mark streaming messages as done
          final msgs = state.messages.map((m) {
            if (m.isStreaming) return m.copyWith(isStreaming: false, error: 'Connection lost');
            return m;
          }).toList();
          state = state.copyWith(
            error: e.toString(),
            isConnected: false,
            isLoading: false,
            runningAgents: {},
            messages: msgs,
          );
        },
        onDone: () {
          // Clear running agents and mark streaming messages as done
          final msgs = state.messages.map((m) {
            if (m.isStreaming) return m.copyWith(isStreaming: false);
            return m;
          }).toList();
          state = state.copyWith(
            isConnected: false,
            isLoading: false,
            runningAgents: {},
            messages: msgs,
          );
        },
      );

      state = state.copyWith(isConnected: true);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String);
      final event = json['event'] as String;
      final payload = json['data'] as Map<String, dynamic>? ?? {};

      switch (event) {
        case 'message':
          _handleNewMessage(payload);
          break;
        case 'message.delta':
          _handleDelta(payload);
          break;
        case 'reasoning.delta':
          _handleReasoningDelta(payload);
          break;
        case 'tool.started':
          _handleToolStarted(payload);
          break;
        case 'tool.completed':
          _handleToolCompleted(payload);
          break;
        case 'tool.error':
          _handleToolError(payload);
          break;
        case 'run.started':
          _handleRunStarted(payload);
          break;
        case 'run.completed':
          _handleRunCompleted(payload);
          break;
        case 'run.failed':
          _handleRunFailed(payload);
          break;
        case 'abort.started':
          _handleAbortStarted(payload);
          break;
        case 'abort.completed':
          _handleAbort(payload);
          break;
        case 'context_status':
          state = state.copyWith(compressingStatus: payload['status'] as String?);
          break;
        case 'queue_updated':
          state = state.copyWith(queueLength: payload['queueLength'] as int? ?? 0);
          break;
      }
    } catch (e) {
      // Prevent unhandled errors from crashing the stream listener
      debugPrint('[ChatNotifier] Error handling message: $e');
    }
  }

  void _handleNewMessage(Map<String, dynamic> payload) {
    final msg = Message.fromJson(payload);
    // Avoid duplicate if already in history
    if (state.messages.any((m) => m.id == msg.id)) return;
    state = state.copyWith(
      messages: [...state.messages, msg],
      isConnected: true,
    );
  }

  void _handleDelta(Map<String, dynamic> payload) {
    final messageId = payload['messageId'] as String;
    final delta = payload['delta'] as String? ?? '';
    final full = payload['full'] as String?;

    final msgs = state.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(
          content: full ?? (m.content + delta),
          isStreaming: true,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(
      messages: msgs,
      runningAgents: {...state.runningAgents, messageId},
    );
  }

  void _handleReasoningDelta(Map<String, dynamic> payload) {
    final messageId = payload['messageId'] as String;
    final delta = payload['delta'] as String? ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;

    final thinking = Map<String, int>.from(state.thinkingStartedAt);
    if (!thinking.containsKey(messageId)) {
      thinking[messageId] = now;
    }

    final msgs = state.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(reasoning: (m.reasoning ?? '') + delta);
      }
      return m;
    }).toList();

    state = state.copyWith(messages: msgs, thinkingStartedAt: thinking);
  }

  void _handleToolStarted(Map<String, dynamic> payload) {
    final messageId = payload['messageId'] as String?;
    final tc = ToolCall.fromJson(payload);
    if (messageId == null) return;

    final currentTools = Map<String, List<ToolCall>>.from(state.toolCalls);
    currentTools[messageId] = [...currentTools[messageId] ?? [], tc];
    state = state.copyWith(toolCalls: currentTools);
  }

  void _handleToolCompleted(Map<String, dynamic> payload) {
    final toolCallId = payload['toolCallId'] as String;
    final output = payload['output'] as String?;
    final duration = (payload['duration'] as num?)?.toDouble();
    final hasError = payload['error'] == true;

    final newToolCalls = <String, List<ToolCall>>{};
    for (final entry in state.toolCalls.entries) {
      newToolCalls[entry.key] = entry.value.map((tc) {
        if (tc.id == toolCallId) {
          return ToolCall(
            id: tc.id,
            tool: tc.tool,
            preview: tc.preview,
            arguments: tc.arguments,
            status: hasError ? ToolStatus.error : ToolStatus.completed,
            output: output,
            duration: duration,
            error: hasError ? 'Tool execution failed' : null,
          );
        }
        return tc;
      }).toList();
    }
    state = state.copyWith(toolCalls: newToolCalls);
  }

  void _handleToolError(Map<String, dynamic> payload) {
    _handleToolCompleted({...payload, 'error': true});
  }

  void _handleRunStarted(Map<String, dynamic> payload) {
    final messageId = payload['messageId'] as String?;
    if (messageId != null) {
      state = state.copyWith(runningAgents: {...state.runningAgents, messageId});
    }
  }

  void _handleRunCompleted(Map<String, dynamic> payload) {
    final messageId = payload['messageId'] as String;
    final inputTokens = payload['inputTokens'] as int?;
    final outputTokens = payload['outputTokens'] as int?;

    final msgs = state.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(isStreaming: false, inputTokens: inputTokens, outputTokens: outputTokens);
      }
      return m;
    }).toList();

    final running = Set<String>.from(state.runningAgents)..remove(messageId);
    state = state.copyWith(messages: msgs, runningAgents: running);
  }

  void _handleRunFailed(Map<String, dynamic> payload) {
    final messageId = payload['messageId'] as String;
    final error = payload['error'] as String? ?? 'Unknown error';

    final msgs = state.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(isStreaming: false, error: error);
      }
      return m;
    }).toList();

    final running = Set<String>.from(state.runningAgents)..remove(messageId);
    state = state.copyWith(messages: msgs, runningAgents: running);
  }

  void _handleAbortStarted(Map<String, dynamic> payload) {
    // Mark all running agents as aborted
    final msgs = state.messages.map((m) {
      if (state.runningAgents.contains(m.id)) {
        return m.copyWith(isStreaming: false, isAborted: true);
      }
      return m;
    }).toList();
    state = state.copyWith(messages: msgs, runningAgents: {});
  }

  void _handleAbort(Map<String, dynamic> payload) {
    final messageId = payload['messageId'] as String?;
    if (messageId == null) return;

    final msgs = state.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(isStreaming: false, isAborted: true);
      }
      return m;
    }).toList();
    final running = Set<String>.from(state.runningAgents)..remove(messageId);
    state = state.copyWith(messages: msgs, runningAgents: running);
  }

  void sendMessage(String content) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({
      'event': 'message',
      'data': {'content': content},
    }));
  }

  void sendAbort() {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({'event': 'abort', 'data': {}}));
  }

  void sendTyping() {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({'event': 'typing'}));
  }

  void sendStopTyping() {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({'event': 'stop_typing'}));
  }

  Future<void> updateRoomName(String name) async {
    final dio = _ref.read(dioProvider);
    await dio.put('/rooms/$roomId', data: {'name': name});
  }

  Future<void> reconnect() async {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _subscription = null;
    await _init();
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
