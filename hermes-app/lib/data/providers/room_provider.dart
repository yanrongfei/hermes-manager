import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room.dart';
import 'api_provider.dart';

class RoomsNotifier extends StateNotifier<AsyncValue<List<Room>>> {
  final Ref _ref;

  RoomsNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadRooms();
  }

  Future<void> loadRooms() async {
    state = const AsyncValue.loading();
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get('/rooms');
      final rooms = (response.data as List)
          .map((json) => Room.fromJson(json))
          .toList();
      state = AsyncValue.data(rooms);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createRoom(String name, {String mode = 'broadcast'}) async {
    final dio = _ref.read(dioProvider);
    await dio.post('/rooms', data: {'name': name, 'mode': mode});
    await loadRooms();
  }

  Future<void> joinByCode(String inviteCode) async {
    final dio = _ref.read(dioProvider);
    await dio.post('/rooms/join', data: {'invite_code': inviteCode});
    await loadRooms();
  }

  Future<Room> createOneOnOneRoom(String agentName, String agentId) async {
    final dio = _ref.read(dioProvider);
    final response = await dio.post('/rooms', data: {
      'name': agentName,
      'mode': 'mention',
      'agent_id': agentId,
    });
    final room = Room.fromJson(response.data);
    await loadRooms();
    return room;
  }

  Future<void> updateRoom(String roomId, String name) async {
    final dio = _ref.read(dioProvider);
    await dio.put('/rooms/$roomId', data: {'name': name});
    await loadRooms();
  }

  Future<void> deleteRoom(String roomId) async {
    final dio = _ref.read(dioProvider);
    await dio.delete('/rooms/$roomId');
    await loadRooms();
  }
}

final roomsProvider = StateNotifierProvider<RoomsNotifier, AsyncValue<List<Room>>>((ref) {
  return RoomsNotifier(ref);
});
