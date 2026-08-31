/// Runtime configuration for the Zixflow Flutter SDK demo.
///
/// Prefer `--dart-define=ZIXFLOW_API_KEY=...` (see README). Falls back to
/// [zixflowApiKeyDefault] when the define is not set.
class AppConfig {
  /// TEMPORARY: set to the Data Pipelines (event-ingress) dev workspace write key
  /// for local end-to-end push notification testing (same workspace used by the
  /// React Native sample).
  ///   Workspace ID: 68be4f797a6494676161e98b
  ///   Write key:    yKFQ9h4gqa5kM3Hf2hUyKeOk1lMjBADE
  /// Revert to 'YOUR_API_KEY' before committing.
  static const String zixflowApiKeyDefault = 'yKFQ9h4gqa5kM3Hf2hUyKeOk1lMjBADE';

  static const String zixflowApiKey = String.fromEnvironment(
    'ZIXFLOW_API_KEY',
    defaultValue: zixflowApiKeyDefault,
  );

  static const String zixflowApiHostDefault = 'dev-events.zixflow.in/v1';

  static const String zixflowApiHost = String.fromEnvironment(
    'ZIXFLOW_API_HOST',
    defaultValue: zixflowApiHostDefault,
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
