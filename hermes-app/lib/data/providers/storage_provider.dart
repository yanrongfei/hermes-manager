import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final FlutterSecureStorage _secure;

  StorageService(this._secure);

  Future<String?> get(String key) async => _secure.read(key: key);
  Future<bool> set(String key, String value) async {
    await _secure.write(key: key, value: value);
    return true;
  }
  Future<bool> remove(String key) async {
    await _secure.delete(key: key);
    return true;
  }
}

final sharedPreferencesProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

final storageProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(sharedPreferencesProvider));
});
