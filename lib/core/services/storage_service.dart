import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';

part 'storage_service.g.dart';

/// Service for managing local storage (secure and regular)
abstract class StorageService {
  // Secure storage operations (for sensitive data like tokens)
  Future<void> setSecure(String key, String value);
  Future<String?> getSecure(String key);
  Future<void> deleteSecure(String key);
  Future<void> deleteAllSecure();

  // Regular storage operations
  Future<void> setString(String key, String value);
  Future<String?> getString(String key);
  Future<void> setBool(String key, bool value);
  Future<bool?> getBool(String key);
  Future<void> setInt(String key, int value);
  Future<int?> getInt(String key);
  Future<void> setDouble(String key, double value);
  Future<double?> getDouble(String key);
  Future<void> remove(String key);
  Future<void> clear();
}

class StorageServiceImpl implements StorageService {

  StorageServiceImpl({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences prefs,
  })  : _secureStorage = secureStorage,
        _prefs = prefs;
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  // Secure storage
  @override
  Future<void> setSecure(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  @override
  Future<String?> getSecure(String key) async {
    return _secureStorage.read(key: key);
  }

  @override
  Future<void> deleteSecure(String key) async {
    await _secureStorage.delete(key: key);
  }

  @override
  Future<void> deleteAllSecure() async {
    await _secureStorage.deleteAll();
  }

  // Regular storage
  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<String?> getString(String key) async {
    return _prefs.getString(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  @override
  Future<bool?> getBool(String key) async {
    return _prefs.getBool(key);
  }

  @override
  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  @override
  Future<int?> getInt(String key) async {
    return _prefs.getInt(key);
  }

  @override
  Future<void> setDouble(String key, double value) async {
    await _prefs.setDouble(key, value);
  }

  @override
  Future<double?> getDouble(String key) async {
    return _prefs.getDouble(key);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    await _prefs.clear();
  }
}

@Riverpod(keepAlive: true)
Future<StorageService> storageService(StorageServiceRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  return StorageServiceImpl(
    secureStorage: secureStorage,
    prefs: prefs,
  );
}

// Convenience providers for common storage operations
@riverpod
Future<String?> savedSchoolCode(SavedSchoolCodeRef ref) async {
  final storage = await ref.watch(storageServiceProvider.future);
  return storage.getString(StorageKeys.schoolCode);
}
