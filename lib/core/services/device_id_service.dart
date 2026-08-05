import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../constants/storage_keys.dart';
import '../storage/session_storage.dart';

/// Device identifiers.
///
/// RN splits these:
/// - `getUniqueId()` → sent as `device_imei` on `/Register_api/`
/// - login `device_id` → DB pk used for ScreenStatus / profile APIs
class DeviceIdService {
  DeviceIdService(this._storage);

  final SessionStorage _storage;
  final _deviceInfo = DeviceInfoPlugin();
  final _uuid = const Uuid();

  /// Hardware/install id for Register_api (`device_imei`). Matches RN `getUniqueId()`.
  Future<String> getHardwareImei() async {
    final stored = await _storage.read(StorageKeys.deviceImei);
    if (stored != null && stored.isNotEmpty) {
      final cleaned = stored.replaceAll('"', '');
      if (cleaned.isNotEmpty && !_looksLikeDbDeviceId(cleaned)) {
        return cleaned;
      }
    }

    // Migrate mistaken caches: older builds stored DB device_id under deviceId
    // and reused it as imei — never treat short numeric DB ids as imei.
    final id = await _resolveHardwareId();
    await _storage.write(StorageKeys.deviceImei, id);
    return id;
  }

  /// Session device id for APIs that need the backend `device_id` (ScreenStatus).
  /// Falls back to hardware imei before first login.
  Future<String> getDeviceId() async {
    final stored = await _storage.read(StorageKeys.deviceId);
    if (stored != null && stored.isNotEmpty) {
      final cleaned = stored.replaceAll('"', '');
      if (cleaned.isNotEmpty) return cleaned;
    }
    return getHardwareImei();
  }

  Future<String> _resolveHardwareId() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = await _deviceInfo.androidInfo;
        final id = android.id;
        if (id.isNotEmpty) return id;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await _deviceInfo.iosInfo;
        final id = ios.identifierForVendor;
        if (id != null && id.isNotEmpty) return id;
      }
    } catch (_) {}
    return _uuid.v4();
  }

  /// Backend login `device_id` is a small integer pk (e.g. "64").
  bool _looksLikeDbDeviceId(String value) {
    final n = int.tryParse(value);
    return n != null && n > 0 && n < 100000000 && value.length <= 8;
  }
}
