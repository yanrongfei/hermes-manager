import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  Future<String?> get(String key) async => _prefs.getString(key);
  Future<bool> set(String key, String value) async {
    await _prefs.setString(key, value);
    return true;
  }
  Future<bool> remove(String key) async {
    await _prefs.remove(key);
    return true;
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized before use');
});

final storageProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(sharedPreferencesProvider));
});