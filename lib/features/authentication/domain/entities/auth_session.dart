class AuthSession {
  const AuthSession({
    required this.mobileNumber,
    required this.customerId,
    required this.deviceId,
    required this.accessToken,
    this.refreshToken,
    this.userType,
  });

  final String mobileNumber;
  final String customerId;
  final String deviceId;
  final String accessToken;
  final String? refreshToken;
  final String? userType;
}

class ProfileSnapshot {
  const ProfileSnapshot({
    this.userType,
    this.customerPlan = '1',
    this.sfCustomerId,
    this.firstName,
    this.lastName,
  });

  final String? userType;
  final String customerPlan;
  final String? sfCustomerId;
  final String? firstName;
  final String? lastName;
}
