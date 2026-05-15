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
  final String mode;
  final String? profileName;
  final String? model;
  final String? provider;
  final bool active;
  final bool apiServerConnected;
  final String? apiKey;

  DiscoveredGateway({
    required this.address,
    this.online = true,
    this.mode = 'http',
    this.profileName,
    this.model,
    this.provider,
    this.active = false,
    this.apiServerConnected = false,
    this.apiKey,
  });

  bool get isLocal => mode == 'local';

  factory DiscoveredGateway.fromJson(Map<String, dynamic> json) {
    return DiscoveredGateway(
      address: json['address'] as String,
      online: json['online'] as bool? ?? true,
      mode: json['mode'] as String? ?? 'http',
      profileName: json['profile_name'] as String?,
      model: json['model'] as String?,
      provider: json['provider'] as String?,
      active: json['active'] as bool? ?? false,
      apiServerConnected: json['api_server_connected'] as bool? ?? false,
      apiKey: json['api_key'] as String?,
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
      final response = await dio.get('/gateways');
      final machines = (response.data as List)
          .map((json) => Machine.fromJson(json))
          .toList();
      state = AsyncValue.data(machines);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addMachine(String address, {String? name, String? apiKey, String mode = 'http', String? profileName}) async {
    final dio = _ref.read(dioProvider);
    await dio.post('/gateways', data: {
      'address': address,
      'name': name,
      'api_key': apiKey,
      'mode': mode,
      'profile_name': profileName,
    });
    await loadMachines();
  }

  Future<void> addDiscoveredGateway(DiscoveredGateway gateway, {String? name}) async {
    await addMachine(
      gateway.address,
      name: name ?? gateway.profileName ?? gateway.address,
      apiKey: gateway.apiKey,
      mode: gateway.mode,
      profileName: gateway.profileName,
    );
  }

  Future<void> deleteMachine(String id) async {
    final dio = _ref.read(dioProvider);
    await dio.delete('/gateways/$id');
    await loadMachines();
  }

  Future<void> updateMachine(String id, {String? name}) async {
    final dio = _ref.read(dioProvider);
    await dio.patch('/gateways/$id', data: {
      'name': name,
    });
    await loadMachines();
  }

  Future<void> discoverGateways() async {
    _isScanning = true;
    _discovered = [];
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
