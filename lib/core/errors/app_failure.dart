class AppFailure implements Exception {
  AppFailure(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => 'AppFailure($statusCode): $message';
}
