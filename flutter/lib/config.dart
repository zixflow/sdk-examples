/// Runtime configuration for the Zixflow Flutter SDK demo.
///
/// Prefer `--dart-define=ZIXFLOW_API_KEY=...` (see README). Falls back to
/// [zixflowApiKeyDefault] when the define is not set.
class AppConfig {
  static const String zixflowApiKeyDefault = 'YOUR_API_KEY';

  static const String zixflowApiKey = String.fromEnvironment(
    'ZIXFLOW_API_KEY',
    defaultValue: zixflowApiKeyDefault,
  );

  static const bool enableLocation = true;

  /// When `true`, initializes Firebase + push handlers (FCM + action buttons).
  /// Keep `false` unless you have added Firebase config files — see README.
  /// Override at run time with `--dart-define=ENABLE_PUSH=true`.
  static const bool enablePush = bool.fromEnvironment(
    'ENABLE_PUSH',
    defaultValue: false,
  );

  static const String demoDeviceToken = 'demo-fcm-device-token';
}
