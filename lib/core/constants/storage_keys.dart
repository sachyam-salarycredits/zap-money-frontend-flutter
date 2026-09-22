/// Storage keys mirrored from RN `AsyncStorageData.js`.
class StorageKeys {
  StorageKeys._();

  static const customerId = 'customerId';
  static const sfCustomerId = 'sfCustomerId';
  static const deviceId = 'deviceId';
  /// Hardware / install id used as `device_imei` on Register_api (RN getUniqueId).
  /// Must NOT be overwritten with the DB device_id from login.
  static const deviceImei = 'deviceImei';
  static const mobileNo = 'mobileNo';
  static const token = 'token';
  static const userType = 'userType';
  static const storageToken = 'StorageToken';
  static const normalToken = 'NormalToken';
  static const pendingEmiPayment = 'pendingEmiPayment';
  /// Latest Finarkein AA run id — background ingest + Waiting sync.
  static const finarkeinRequestId = 'finarkeinRequestId';
}
