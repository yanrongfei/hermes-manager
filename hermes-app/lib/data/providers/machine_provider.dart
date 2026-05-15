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

class DiscoveredGateway {
  final String address;
  final bool online;

  DiscoveredGateway({required this.address, this.online = true});

  factory DiscoveredGateway.fromJson(Map<String, dynamic> json) {
    return DiscoveredGateway(
      address: json['address'] as String,
      online: json['online'] as bool? ?? true,
    );
  }
}

class MachinesNotifier extends StateNotifier<AsyncValue<List<Machine>>> {
  final Ref _ref;
  List<DiscoveredGateway> _discovered = [];
  bool _isScanning = false;

  List<DiscoveredGateway> get discovered => _discovered;
  bool get isScanning => _isScanning;

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

  Future<void> deleteMachine(String id) async {
    final dio = _ref.read(dioProvider);
    await dio.delete('/machines/$id');
    await loadMachines();
  }

  Future<void> updateMachine(String id, {String? name}) async {
    final dio = _ref.read(dioProvider);
    await dio.put('/machines/$id', data: {
      'name': name,
    });
    await loadMachines();
  }

  Future<void> discoverGateways() async {
    _isScanning = true;
    _discovered = [];
    // Notify listeners about scanning state
    state = state;
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get('/gateways/discover');
      _discovered = (response.data as List)
          .map((json) => DiscoveredGateway.fromJson(json))
          .toList();
    } catch (_) {
      _discovered = [];
    } finally {
      _isScanning = false;
      state = state;
    }
  }
}

final machinesNotifierProvider = StateNotifierProvider<MachinesNotifier, AsyncValue<List<Machine>>>((ref) {
  return MachinesNotifier(ref);
});
