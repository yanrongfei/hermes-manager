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

  Future<Room> createRoom({
    required String name,
    required List<String> agentIds,
    String mode = 'direct',
  }) async {
    final dio = _ref.read(dioProvider);
    final response = await dio.post('/rooms', data: {
      'name': name,
      'agentIds': agentIds,
      'mode': mode,
    });
    final room = Room.fromJson(response.data);
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
    return createRoom(
      name: agentName,
      agentIds: [agentId],
      mode: 'direct',
    );
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
