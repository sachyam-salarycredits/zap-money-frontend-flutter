class Validators {
  Validators._();

  static final mobile = RegExp(r'^[1-9]\d*$');

  static String? mobileNumber(String? value) {
    if (value == null || value.length < 10 || !mobile.hasMatch(value)) {
      return 'Please enter valid phone number';
    }
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.length != 6) {
      return 'OTP is not valid';
    }
    return null;
  }
}
