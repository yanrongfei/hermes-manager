import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import 'storage_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(ResponseLogInterceptor());

  return dio;
});

class ResponseLogInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    developer.log(
      '[${response.statusCode}] ${response.requestOptions.method} ${response.requestOptions.path}\n'
      'Response: ${response.data}',
      name: 'API',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    developer.log(
      '[${err.response?.statusCode ?? 'ERR'}] ${err.requestOptions.method} ${err.requestOptions.path}\n'
      'Response: ${err.response?.data}',
      name: 'API',
    );
    handler.next(err);
  }
}

class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final storage = _ref.read(storageProvider);
    final token = await storage.get(AppConfig.accessTokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Handle token refresh - TODO for later
    }
    handler.next(err);
  }
}
