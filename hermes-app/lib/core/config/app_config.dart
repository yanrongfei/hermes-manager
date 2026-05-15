class AppConfig {
  static const String appName = 'Hermes Agent';
  static const String baseUrl = 'http://127.0.0.1:3002';
  static const String wsUrl = 'ws://127.0.0.1:3002';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user';
}
