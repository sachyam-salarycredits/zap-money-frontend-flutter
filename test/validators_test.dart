import 'package:flutter_test/flutter_test.dart';
import 'package:zap_money/core/utils/validators.dart';

void main() {
  test('mobile validator matches RN rules', () {
    expect(Validators.mobileNumber(null), isNotNull);
    expect(Validators.mobileNumber('0123456789'), isNotNull);
    expect(Validators.mobileNumber('987654321'), isNotNull);
    expect(Validators.mobileNumber('9876543210'), isNull);
  });

  test('otp validator requires 6 digits', () {
    expect(Validators.otp('12345'), isNotNull);
    expect(Validators.otp('123456'), isNull);
  });
}
