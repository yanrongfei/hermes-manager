import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  Future<String?> get(String key) async => _prefs.getString(key);
  Future<bool> set(String key, String value) async => _prefs.setString(key, value);
  Future<bool> remove(String key) async => _prefs.remove(key);
  Future<bool> clear() async => _prefs.clear();
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize in main.dart');
});

final storageProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(sharedPreferencesProvider));
});
