/// Runtime configuration for the Zixflow Flutter SDK demo.
///
/// Prefer `--dart-define=ZIXFLOW_API_KEY=...` (see README). Falls back to
/// [zixflowApiKeyDefault] when the define is not set.
class AppConfig {
  /// Zixflow API key from Settings → Developers → API Keys.
  /// Prefer `--dart-define=ZIXFLOW_API_KEY=...` (see README) over editing this default.
  static const String zixflowApiKeyDefault = 'YOUR_API_KEY';

  static const String zixflowApiKey = String.fromEnvironment(
    'ZIXFLOW_API_KEY',
    defaultValue: zixflowApiKeyDefault,
  );

  /// Dev/staging workspace keys 401 against the default production host
  /// (api-events.zixflow.com). Opt in only via --dart-define, e.g.
  /// `--dart-define=ZIXFLOW_API_HOST=dev-events.zixflow.in/v1` — never commit
  /// a real default here, or every clone of this example silently targets a
  /// non-production backend. Empty (the default) means "no override".
  static const String _apiHostEnv = String.fromEnvironment('ZIXFLOW_API_HOST');
  static const String _cdnHostEnv = String.fromEnvironment('ZIXFLOW_CDN_HOST');
  static String? get zixflowApiHost => _apiHostEnv.isEmpty ? null : _apiHostEnv;
  static String? get zixflowCdnHost => _cdnHostEnv.isEmpty ? null : _cdnHostEnv;

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
