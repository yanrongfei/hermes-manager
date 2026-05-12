import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/machine.dart';
import '../models/agent.dart';
import 'api_provider.dart';

final machinesProvider = FutureProvider<List<Machine>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/machines');
  return (response.data as List).map((json) => Machine.fromJson(json)).toList();
});

final machineAgentsProvider = FutureProvider.family<List<Agent>, String>((ref, machineId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/machines/$machineId/agents');
  return (response.data as List).map((json) => Agent.fromJson(json)).toList();
});

class MachinesNotifier extends StateNotifier<AsyncValue<List<Machine>>> {
  final Ref _ref;

  MachinesNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadMachines();
  }

  Future<void> loadMachines() async {
    state = const AsyncValue.loading();
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get('/machines');
      final machines = (response.data as List)
          .map((json) => Machine.fromJson(json))
          .toList();
      state = AsyncValue.data(machines);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addMachine(String address, {String? name}) async {
    final dio = _ref.read(dioProvider);
    await dio.post('/machines', data: {
      'address': address,
      'name': name,
    });
    await loadMachines();
  }
}

final machinesNotifierProvider = StateNotifierProvider<MachinesNotifier, AsyncValue<List<Machine>>>((ref) {
  return MachinesNotifier(ref);
});
