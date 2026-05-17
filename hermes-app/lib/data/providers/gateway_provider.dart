import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/gateway.dart';
import 'api_provider.dart';

class DiscoveredGateway {
  final String address;
  final bool online;
  final String? profileName;
  final String? model;
  final String? provider;
  final bool active;
  final String? apiKey;

  DiscoveredGateway({
    required this.address,
    this.online = true,
    this.profileName,
    this.model,
    this.provider,
    this.active = false,
    this.apiKey,
  });

  factory DiscoveredGateway.fromJson(Map<String, dynamic> json) {
    return DiscoveredGateway(
      address: json['address'] as String,
      online: json['online'] as bool? ?? true,
      profileName: json['profile_name'] as String?,
      model: json['model'] as String?,
      provider: json['provider'] as String?,
      active: json['active'] as bool? ?? false,
      apiKey: json['api_key'] as String?,
    );
  }
}

class GatewaysNotifier extends StateNotifier<AsyncValue<List<Gateway>>> {
  final Ref _ref;
  List<DiscoveredGateway> _discovered = [];
  bool _isScanning = false;

  List<DiscoveredGateway> get discovered => _discovered;
  bool get isScanning => _isScanning;

  GatewaysNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadGateways();
  }

  Future<void> loadGateways() async {
    state = const AsyncValue.loading();
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get('/gateways');
      final gateways = (response.data as List)
          .map((json) => Gateway.fromJson(json))
          .toList();
      state = AsyncValue.data(gateways);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<List<GatewayStatus>> fetchGatewayStatus() async {
    final dio = _ref.read(dioProvider);
    final response = await dio.get('/gateways/status');
    return (response.data as List)
        .map((json) => GatewayStatus.fromJson(json))
        .toList();
  }

  Future<void> addGateway(String address, {String? name, String? apiKey}) async {
    final dio = _ref.read(dioProvider);
    await dio.post('/gateways', data: {
      'address': address,
      'name': name,
      'api_key': apiKey,
    });
    await loadGateways();
  }

  Future<void> addDiscoveredGateway(DiscoveredGateway gateway, {String? name}) async {
    await addGateway(
      gateway.address,
      name: name ?? gateway.profileName ?? gateway.address,
      apiKey: gateway.apiKey,
    );
  }

  Future<void> deleteGateway(String id) async {
    final dio = _ref.read(dioProvider);
    await dio.delete('/gateways/$id');
    await loadGateways();
  }

  Future<void> updateGateway(String id, {String? name, String? apiKey}) async {
    final dio = _ref.read(dioProvider);
    await dio.patch('/gateways/$id', data: {
      'name': name,
      'api_key': apiKey,
    });
    await loadGateways();
  }

  Future<void> syncGateway(String id) async {
    final dio = _ref.read(dioProvider);
    await dio.post('/gateways/$id/sync');
    await loadGateways();
  }

  Future<bool> testGateway(String id) async {
    final dio = _ref.read(dioProvider);
    try {
      final response = await dio.post('/gateways/$id/test');
      return response.data['online'] as bool? ?? false;
    } catch (_) {
      return false;
    }
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

  Future<Map<String, dynamic>> stopGateway(String profile) async {
    final dio = _ref.read(dioProvider);
    final response = await dio.post('/gateways/stop', queryParameters: {'profile': profile});
    return response.data as Map<String, dynamic>;
  }
}

final gatewaysNotifierProvider = StateNotifierProvider<GatewaysNotifier, AsyncValue<List<Gateway>>>((ref) {
  return GatewaysNotifier(ref);
});