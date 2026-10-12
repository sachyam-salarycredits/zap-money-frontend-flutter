import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/storage/session_storage.dart';
import '../authentication/presentation/providers/auth_providers.dart';

/// Active RN sync parity: location + device + permission statuses only.
class DeviceSyncService {
  DeviceSyncService(this._dio, this._storage, this._deviceId);

  final Dio _dio;
  final SessionStorage _storage;
  final Future<String> Function() _deviceId;

  Future<void> syncAfterPermissionGrant() async {
    try {
      await Future.wait([
        _syncLocation(),
        _syncDeviceAndPermissions(),
      ]);
    } catch (_) {
      // Non-fatal — RN continues even if sync fails.
    }
  }

  Future<void> _syncLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
    final deviceId = await _deviceId();
    final customerId =
        (await _storage.read(StorageKeys.customerId))?.replaceAll('"', '');
    final lat = position.latitude.toString();
    final lng = position.longitude.toString();
    await _dio.post(
      ApiEndpoints.storeCustomerDeviceLocation,
      data: {
        'device_id': deviceId,
        'latitude': lat,
        'longitude': lng,
        'action': 'GeolocationInfo',
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    if (customerId == null || customerId.isEmpty) return;
    final customerIdPayload = int.tryParse(customerId) ?? customerId;
    final locationBody = {
      'customer_id': customerIdPayload,
      'latitude': lat,
      'longitude': lng,
    };
    try {
      await _dio.post(
        ApiEndpoints.getLocationDetails,
        data: locationBody,
        options: Options(contentType: Headers.jsonContentType),
      );
      await _dio.post(
        ApiEndpoints.getLocationDecision,
        data: locationBody,
        options: Options(contentType: Headers.jsonContentType),
      );
    } catch (_) {
      // Non-fatal — device row + backend backfill may still apply.
    }
  }

  Future<void> _syncDeviceAndPermissions() async {
    final customerId =
        (await _storage.read(StorageKeys.customerId))?.replaceAll('"', '');
    final deviceId = await _deviceId();
    final loc = await Permission.location.status;
    final contacts = await Permission.contacts.status;
    final phone = await Permission.phone.status;

    await _dio.post(
      ApiEndpoints.permissionDataStore,
      data: {
        'cust_id': customerId,
        'device_id': deviceId,
        'request_category': 'DeviceInfo',
        'permission_data': {
          'location': loc.isGranted,
          'contacts': contacts.isGranted,
          'phone': phone.isGranted,
        },
      },
      options: Options(contentType: Headers.jsonContentType),
    );
  }
}

final deviceSyncServiceProvider = Provider<DeviceSyncService>((ref) {
  return DeviceSyncService(
    ref.watch(dioClientProvider).dio,
    ref.watch(sessionStorageProvider),
    () => ref.read(deviceIdServiceProvider).getDeviceId(),
  );
});
