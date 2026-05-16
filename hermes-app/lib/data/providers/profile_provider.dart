import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import '../models/agent.dart';
import 'api_provider.dart';

final profilesProvider = FutureProvider.family<List<Profile>, String>((ref, gatewayId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/gateways/$gatewayId/profiles');
  return (response.data as List).map((json) => Profile.fromJson(json)).toList();
});

final profileDetailProvider = FutureProvider.family<Profile, String>((ref, profileId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/profiles/$profileId');
  return Profile.fromJson(response.data);
});

final profileAgentsProvider = FutureProvider.family<List<Agent>, String>((ref, profileId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/profiles/$profileId/agents');
  return (response.data as List).map((json) => Agent.fromJson(json)).toList();
});

final allAgentsProvider = FutureProvider<List<Agent>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/agents');
  return (response.data as List).map((json) => Agent.fromJson(json)).toList();
});
