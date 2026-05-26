import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/config/app_config.dart';
import '../models/room.dart';
import 'room_provider.dart';
import 'storage_provider.dart';

class NotificationState {
  final bool isConnected;
  final String? error;

  NotificationState({this.isConnected = false, this.error});

  NotificationState copyWith({bool? isConnected, String? error}) {
    return NotificationState(
      isConnected: isConnected ?? this.isConnected,
      error: error,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final Ref _ref;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  NotificationNotifier(this._ref) : super(NotificationState());

  Future<void> connect() async {
    if (state.isConnected) return;

    final storage = _ref.read(storageProvider);
    final token = await storage.get(AppConfig.accessTokenKey);
    if (token == null) return;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('${AppConfig.wsUrl}/ws/notifications?token=$token'),
      );

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
      );

      state = state.copyWith(isConnected: true, error: null);
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String);
      final event = json['event'] as String;
      final payload = json['data'] as Map<String, dynamic>? ?? {};

      if (event == 'room_updated') {
        _onRoomUpdated(payload);
      }
    } catch (e) {
      debugPrint('[NotificationNotifier] Error: $e');
    }
  }

  void _onRoomUpdated(Map<String, dynamic> payload) {
    final roomId = payload['roomId'] as String?;
    if (roomId == null) return;

    final roomsState = _ref.read(roomsProvider);
    roomsState.whenData((rooms) {
      final updated = rooms.map((r) {
        if (r.id != roomId) return r;
        return Room(
          id: r.id,
          name: r.name,
          avatar: r.avatar,
          ownerId: r.ownerId,
          mode: r.mode,
          agentId: r.agentId,
          profileId: r.profileId,
          inviteCode: r.inviteCode,
          createdAt: r.createdAt,
          type: r.type,
          memberCount: r.memberCount,
          onlineCount: r.onlineCount,
          lastMessage: payload['lastMessage'] as String? ?? r.lastMessage,
          updatedAt: payload['updatedAt'] as int? ?? r.updatedAt,
          hasRunningTasks: r.hasRunningTasks,
          runningTasksCount: r.runningTasksCount,
          unreadCount: (r.unreadCount ?? 0) + 1,
        );
      }).toList();

      // Re-sort by updatedAt
      updated.sort((a, b) {
        if (a.updatedAt == null && b.updatedAt == null) return 0;
        if (a.updatedAt == null) return 1;
        if (b.updatedAt == null) return -1;
        return b.updatedAt!.compareTo(a.updatedAt!);
      });

      _ref.read(roomsProvider.notifier).updateFromNotification(updated);
    });
  }

  void _scheduleReconnect() {
    state = state.copyWith(isConnected: false);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref);
});
