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

  static const bool enableInApp = true;

  static const bool enableLocation = true;

  static const String demoDeviceToken = 'demo-fcm-device-token';
}
