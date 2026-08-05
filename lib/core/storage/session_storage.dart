import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/storage_keys.dart';

class SessionStorage {
  SessionStorage({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _secure;

  Future<String?> read(String key) => _secure.read(key: key);

  Future<void> write(String key, String value) =>
      _secure.write(key: key, value: value);

  Future<void> delete(String key) => _secure.delete(key: key);

  Future<void> writeJson(String key, Map<String, dynamic> value) =>
      write(key, jsonEncode(value));

  Future<Map<String, dynamic>?> readJson(String key) async {
    final raw = await read(key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  /// Mirrors RN `removeUserData` (does not clear NormalToken / StorageToken explicitly
  /// for all keys — RN clears mobile, customer, device, userType, token, sfCustomerId).
  Future<void> clearUserSession() async {
    await Future.wait([
      delete(StorageKeys.mobileNo),
      delete(StorageKeys.customerId),
      delete(StorageKeys.deviceId),
      delete(StorageKeys.userType),
      delete(StorageKeys.token),
      delete(StorageKeys.sfCustomerId),
      delete(StorageKeys.storageToken),
      delete(StorageKeys.normalToken),
      // Keep deviceImei — same install should keep RN-like getUniqueId().
    ]);
  }
}