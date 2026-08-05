/// Runtime config. Prefer `--dart-define` / flavors; never commit real secrets.
///
/// Example:
/// ```
/// fvm flutter run --dart-define=FLAVOR=dev \
///   --dart-define=BASE_URL=https://your-borrower-api.example
/// ```
class AppConfig {
  static const String flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'dev',
  );

  static const String appName = 'Zap Money';

  /// Django borrower API (`BaseURL.BASEURL` in RN).
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://seclusion-repeater-habitual.ngrok-free.dev',
  );

  /// Monexo gateway (`BaseURL.BASE_URL_MONEXO`).
  static const String monexoGatewayUrl = String.fromEnvironment(
    'MONEXO_GATEWAY_URL',
    defaultValue: 'http://uat-monexo-gateway-service.monexo.co',
  );

  /// OAuth security host.
  static const String securityBaseUrl = String.fromEnvironment(
    'SECURITY_BASE_URL',
    defaultValue: 'http://uat-monexo-security-service.monexo.co',
  );

  /// Matches RN typo `client_secrect` payload key value from source.
  /// Override via dart-define in production builds.
  static const String oauthClientId = String.fromEnvironment(
    'OAUTH_CLIENT_ID',
    defaultValue: 'monexo_borrower_client',
  );

  static const String oauthClientSecret = String.fromEnvironment(
    'OAUTH_CLIENT_SECRET',
    defaultValue: 'secrect',
  );

  static const String playStoreUrl = String.fromEnvironment(
    'PLAY_STORE_URL',
    defaultValue: 'https://play.google.com/store/apps/details?id=com.zapmoney',
  );

  static bool get isProd => flavor == 'prod';
}
