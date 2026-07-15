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
  /// Defaults to `true` since `google-services.json` is bundled — see README.
  /// Override at run time with `--dart-define=ENABLE_PUSH=false`.
  static const bool enablePush = bool.fromEnvironment(
    'ENABLE_PUSH',
    defaultValue: true,
  );

  static const String demoDeviceToken = 'demo-fcm-device-token';
}
