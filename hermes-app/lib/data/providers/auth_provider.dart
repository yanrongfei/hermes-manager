import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../models/auth.dart';
import '../models/user.dart';
import 'api_provider.dart';
import 'storage_provider.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(AuthState()) {
    checkAuth();
  }

  Future<bool> login(String username, String password) async {
    state = AuthState(isLoading: true);
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });
      final tokens = TokenResponse.fromJson(response.data);

      final storage = _ref.read(storageProvider);
      await storage.set(AppConfig.accessTokenKey, tokens.accessToken);
      await storage.set(AppConfig.refreshTokenKey, tokens.refreshToken);

      // Fetch user info
      final userResponse = await dio.get('/auth/me');
      final user = User.fromJson(userResponse.data);

      state = AuthState(user: user);
      return true;
    } on DioException catch (e) {
      final msg = _extractMsg(e) ?? '登录失败';
      state = AuthState(error: '$msg (${e.response?.statusCode})');
      return false;
    } catch (e, st) {
      state = AuthState(error: '登录失败: $e\n$st');
      return false;
    }
  }

  Future<bool> register(String username, String password) async {
    state = AuthState(isLoading: true);
    try {
      final dio = _ref.read(dioProvider);
      await dio.post('/auth/register', data: {
        'username': username,
        'password': password,
      });
      // Auto login after register
      return login(username, password);
    } on DioException catch (e) {
      state = AuthState(error: _extractMsg(e) ?? '注册失败');
      return false;
    } catch (e) {
      state = AuthState(error: '注册失败');
      return false;
    }
  }

  String? _extractMsg(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data['msg'] as String?;
    }
    return null;
  }

  Future<void> logout() async {
    final storage = _ref.read(storageProvider);
    await storage.remove(AppConfig.accessTokenKey);
    await storage.remove(AppConfig.refreshTokenKey);
    state = AuthState();
  }

  Future<void> checkAuth() async {
    final storage = _ref.read(storageProvider);
    final token = await storage.get(AppConfig.accessTokenKey);
    if (token == null) {
      state = AuthState();
      return;
    }
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get('/auth/me');
      state = AuthState(user: User.fromJson(response.data));
    } catch (e) {
      await logout();
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
