import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room.dart';
import 'api_provider.dart';

class RoomsNotifier extends StateNotifier<AsyncValue<List<Room>>> {
  final Ref _ref;
  bool _isLoading = false;
  int _pendingCallsWhileLoading = 0;
  Timer? _debounceTimer;

  RoomsNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadRoomsInitial();
  }

  /// First load — shows loading spinner.
  Future<void> _loadRoomsInitial() async {
    try {
      final rooms = await _fetchRooms();
      state = AsyncValue.data(rooms);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Silent refresh — debounced to avoid duplicate calls.
  Future<void> loadRooms() async {
    _debounceTimer?.cancel();
    if (_isLoading) {
      _pendingCallsWhileLoading++;
      _debounceTimer = Timer(const Duration(milliseconds: 500), () => _doLoadRooms());
      return;
    }
    await _doLoadRooms();
  }

  Future<void> _doLoadRooms() async {
    _isLoading = true;
    try {
      final rooms = await _fetchRooms();
      state = AsyncValue.data(rooms);
    } catch (e, st) {
      if (state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
    } finally {
      _isLoading = false;
      _debounceTimer?.cancel();
      _debounceTimer = null;
      // If there was a call while loading, fire one more after debounce
      if (_pendingCallsWhileLoading > 0) {
        _pendingCallsWhileLoading = 0;
        _debounceTimer = Timer(const Duration(milliseconds: 500), () => _doLoadRooms());
      }
    }
  }

  Future<List<Room>> _fetchRooms() async {
    final dio = _ref.read(dioProvider);
    final response = await dio.get('/rooms');
    final rooms = (response.data as List)
        .map((json) => Room.fromJson(json))
        .toList();
    rooms.sort((a, b) {
      if (a.updatedAt == null && b.updatedAt == null) return 0;
      if (a.updatedAt == null) return 1;
      if (b.updatedAt == null) return -1;
      return b.updatedAt!.compareTo(a.updatedAt!);
    });
    return rooms;
  }

  Future<Room> createRoom({
    required String name,
    required List<String> agentIds,
    String mode = 'direct',
  }) async {
    final dio = _ref.read(dioProvider);
    final response = await dio.post('/rooms', data: {
      'name': name,
      'agent_ids': agentIds,
      'mode': mode,
    });
    final room = Room.fromJson(response.data);
    _ref.read(roomRefreshTriggerProvider.notifier).state++;
    await loadRooms();
    return room;
  }

  Future<void> joinByCode(String inviteCode) async {
    final dio = _ref.read(dioProvider);
    await dio.post('/rooms/join', data: {'invite_code': inviteCode});
    await loadRooms();
  }

  Future<Room> createOneOnOneRoom({
    required String agentName,
    required String agentId,
  }) async {
    final dio = _ref.read(dioProvider);
    final response = await dio.post('/rooms', data: {
      'name': agentName,
      'agent_ids': [agentId],
      'mode': 'direct',
    });
    final room = Room.fromJson(response.data);
    _ref.read(roomRefreshTriggerProvider.notifier).state++;
    await loadRooms();
    return room;
  }

  Future<void> updateRoom(String roomId, String name) async {
    final dio = _ref.read(dioProvider);
    await dio.put('/rooms/$roomId', data: {'name': name});
    await loadRooms();
  }

  Future<void> deleteRoom(String roomId) async {
    // Optimistically remove from local state
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.where((r) => r.id != roomId).toList());
    }
    try {
      final dio = _ref.read(dioProvider);
      await dio.delete('/rooms/$roomId');
      await loadRooms();
    } catch (_) {
      // Rollback on failure
      await loadRooms();
    }
  }

  Future<void> markRoomRead(String roomId) async {
    final current = state.valueOrNull;
    if (current != null) {
      final updated = current.map((r) {
        if (r.id == roomId) {
          return Room(
            id: r.id, name: r.name, avatar: r.avatar, ownerId: r.ownerId,
            mode: r.mode, agentId: r.agentId, profileId: r.profileId,
            inviteCode: r.inviteCode, createdAt: r.createdAt, type: r.type,
            memberCount: r.memberCount, onlineCount: r.onlineCount,
            lastMessage: r.lastMessage, updatedAt: r.updatedAt,
            hasRunningTasks: r.hasRunningTasks, runningTasksCount: r.runningTasksCount,
            unreadCount: 0,
          );
        }
        return r;
      }).toList();
      state = AsyncValue.data(updated);
    }

    try {
      final dio = _ref.read(dioProvider);
      await dio.post('/rooms/$roomId/read');
    } catch (_) {}
  }

  Future<void> addAgentToRoom(String roomId, String agentId) async {
    final dio = _ref.read(dioProvider);
    await dio.post('/rooms/$roomId/agents', queryParameters: {'agent_id': agentId});
  }

  Future<String> fetchInviteCode(String roomId) async {
    final dio = _ref.read(dioProvider);
    final response = await dio.post('/rooms/$roomId/invite');
    return response.data['invite_code'] as String;
  }

  /// Called by NotificationNotifier to update room list without full reload.
  void updateFromNotification(List<Room> rooms) {
    state = AsyncValue.data(rooms);
  }
}

final roomsProvider = StateNotifierProvider<RoomsNotifier, AsyncValue<List<Room>>>((ref) {
  return RoomsNotifier(ref);
});

final currentTabProvider = StateProvider<int>((ref) => 0);

// Incremented when returning from a chat room; ChatListTab watches this to trigger refresh
final roomRefreshTriggerProvider = StateProvider<int>((ref) => 0);
