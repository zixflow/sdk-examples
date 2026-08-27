import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zixflow/zixflow.dart';

import 'config.dart';
import 'navigation.dart';

/// Parses the Zixflow `action_buttons` payload (JSON string or list).
List<Map<String, dynamic>> parseActionButtons(dynamic raw) {
  if (raw == null) return [];
  try {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    return List<Map<String, dynamic>>.from(decoded as List);
  } catch (e) {
    debugPrint('[PushHandlers] Error parsing action buttons: $e');
    return [];
  }
}

const String _androidChannelId = 'zixflow_default';
const String _androidChannelName = 'Zixflow Notifications';
// Selected when data['priority'] == 'normal' — lower importance, no heads-up banner,
// making FCM's own high/normal priority distinction (otherwise only a delivery-timing
// hint) observable in the custom-handled path.
const String _androidChannelIdNormal = 'zixflow_normal';
const String _androidChannelNameNormal = 'Zixflow Notifications (normal priority)';

// Persisted (not just in-memory) so the background isolate — which does NOT
// share Dart statics with the main isolate — can read the same value the user
// set in the UI. Defaults to true (today's existing custom-handling behavior).
const String _customHandlingPrefKey = 'zixflow_demo_custom_handling_enabled';

Future<bool> _isCustomHandlingEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_customHandlingPrefKey) ?? true;
}

/// True if [message] carries anything worth showing to the user — a native
/// `notification` block, or a `title`/`body` in `data` (Zixflow's own custom-UI
/// scheme, since the real dashboard sends data-only pushes — see BUG-A12 note
/// in the Android sample). False for pure silent/background-sync pushes (Case
/// 12 in android-fcm-push-test-cases-v2.md / Case 8 & 18 in the iOS doc) —
/// those must be "handled by ourselves, no custom UI": process data, show
/// nothing.
bool _hasDisplayableContent(RemoteMessage message) {
  return message.notification != null ||
      message.data['title'] != null ||
      message.data['body'] != null;
}

/// Background isolate entry point for FCM messages (app backgrounded or
/// terminated). Pure Dart: builds and displays the local notification —
/// including action buttons — directly here, the same way
/// [flutter_local_notifications] is used from a background isolate in any
/// Flutter app. No native Kotlin/Swift code required (mirrors zepto_poc).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  _logIncomingPush('BACKGROUND/TERMINATED', message);

  // Fresh plugin instance for this isolate — method-channel calls are
  // stateless, so there's no need to share the foreground singleton.
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('app_icon'),
    ),
    onDidReceiveNotificationResponse: _notificationTapBackground,
  );
  final androidPlugin = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: 'Zixflow push notifications',
      importance: Importance.high,
    ),
  );

  if (!await _isCustomHandlingEnabled()) {
    debugPrint(
      '[PushHandlers] Custom handling OFF — rendering stock-FCM-equivalent only (standard fields, no Zixflow extras)',
    );
    await _showStockEquivalentNotification(plugin, message);
    return;
  }

  _trackDelivered(message.data, 'firebaseMessagingBackgroundHandler');

  if (!_hasDisplayableContent(message)) {
    debugPrint(
      '[PushHandlers] Silent/data-only push (no notification content) — processing data, showing no UI',
    );
    return;
  }

  // A `notification` block delivered while backgrounded/terminated is already
  // auto-displayed by the OS (FCM bypasses this handler's *display* concerns —
  // it only runs this isolate to let the app process data alongside it). Building
  // our own local notification here too would show a duplicate. Only build one
  // ourselves for data-only messages carrying our own custom title/body fields.
  if (message.notification != null) {
    debugPrint(
      '[PushHandlers] Notification-block push in background — solely handled by FCM/OS, skipping local notification to avoid duplicate',
    );
    return;
  }

  await _showLocalNotification(plugin, message);
}

/// Handles a notification tap (body or action button) delivered to a
/// background isolate, i.e. the app was fully terminated. Re-initializes the
/// Zixflow SDK (required in a fresh isolate) before tracking the tap.
@pragma('vm:entry-point')
Future<void> _notificationTapBackground(NotificationResponse response) async {
  await Zixflow.initialize(
    config: ZixflowConfig(
      apiKey: AppConfig.zixflowApiKey,
      apiHost: AppConfig.zixflowApiHost,
    ),
  );
  _handleNotificationResponse(response);
}

/// Firebase Cloud Messaging + flutter_local_notifications with dynamic
/// action buttons — 100% Dart, no native Kotlin/Swift code required.
class PushHandlers {
  PushHandlers._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static String? _fcmToken;

  /// FCM token, exposed for UI display (e.g. copy-to-clipboard).
  static final ValueNotifier<String?> fcmToken = ValueNotifier<String?>(null);

  /// Push handling mode, exposed for a UI toggle. `true` (default) = today's
  /// existing custom handling (process data, track Delivered, show a local
  /// notification when there's displayable content). `false` = "solely
  /// handled by FCM/APNs": this app's code does nothing at all for incoming
  /// pushes — background/killed notification-block pushes still show via the
  /// OS (unaffected either way), but data-only pushes and foreground display
  /// are entirely skipped, exactly as if no push code had been written.
  static final ValueNotifier<bool> customHandlingEnabled =
      ValueNotifier<bool>(true);

  static Future<void> setCustomHandlingEnabled(bool value) async {
    customHandlingEnabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_customHandlingPrefKey, value);
  }

  static const String _iosCategoryId = 'ZX_2BTN';

  // Persisted key for the last token we actually called registerDeviceToken()
  // with. App-level guard: registerDeviceToken() is commonly called on every
  // app launch (as below, right after fetching the current FCM token), which
  // would otherwise re-send a "Device Created or Updated" event every single
  // time even when the token hasn't changed. Persisted via SharedPreferences
  // (not just an in-memory field) so the check survives the app process being
  // killed while backgrounded, then relaunched.
  static const String _lastRegisteredTokenPrefKey =
      'zixflow_demo_last_registered_device_token';

  /// Call after [Firebase.initializeApp] and [Zixflow.initialize].
  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    customHandlingEnabled.value = await _isCustomHandlingEnabled();

    await _requestPermission();
    await _initializeLocalNotifications();
    await _registerToken();
    _setupMessageListeners();
  }

  static Future<void> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint(
      '[PushHandlers] Permission: ${settings.authorizationStatus}',
    );
  }

  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('app_icon');

    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _iosCategoryId,
          actions: [
            DarwinNotificationAction.plain('ACTION_0', 'Action 1'),
            DarwinNotificationAction.plain('ACTION_1', 'Action 2'),
          ],
        ),
      ],
    );

    await _localNotifications.initialize(
      InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _notificationTapBackground,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: 'Zixflow push notifications',
        importance: Importance.high,
      ),
    );
  }

  static Future<void> _registerToken() async {
    _fcmToken = await FirebaseMessaging.instance.getToken();
    if (_fcmToken != null) {
      fcmToken.value = _fcmToken;
      await _registerDeviceTokenIfChanged(_fcmToken!);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      _fcmToken = newToken;
      fcmToken.value = newToken;
      await _registerDeviceTokenIfChanged(newToken);
    });
  }

  /// Only calls `registerDeviceToken()` when [token] differs from the last
  /// one we actually registered — see [_lastRegisteredTokenPrefKey].
  static Future<void> _registerDeviceTokenIfChanged(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final lastToken = prefs.getString(_lastRegisteredTokenPrefKey);
    if (lastToken == token) {
      debugPrint(
        '[PushHandlers] Device token unchanged since last registration, skipping duplicate registerDeviceToken call',
      );
      return;
    }

    Zixflow.instance.registerDeviceToken(deviceToken: token);
    await prefs.setString(_lastRegisteredTokenPrefKey, token);
    _printToken(lastToken == null ? 'FCM token registered' : 'FCM token refreshed', token);
  }

  static void _printToken(String label, String token) {
    debugPrint('');
    debugPrint('════════════════════════════════════════');
    debugPrint('[PushHandlers] $label:');
    debugPrint(token);
    debugPrint('════════════════════════════════════════');
    debugPrint('');
  }

  static void _setupMessageListeners() {
    // Foreground: show the local notification ourselves (with buttons).
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logIncomingPush('FOREGROUND', message);

      if (!customHandlingEnabled.value) {
        debugPrint(
          '[PushHandlers] Custom handling OFF — Firebase/OS handles this push entirely, app code does nothing',
        );
        return;
      }

      _trackDelivered(message.data, 'onMessage (foreground)');
      if (!_hasDisplayableContent(message)) {
        debugPrint(
          '[PushHandlers] Silent/data-only push (no notification content) — processing data, showing no UI',
        );
        return;
      }
      _showLocalNotification(_localNotifications, message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logIncomingPush('OPENED (tapped from background)', message);
      debugPrint('[PushHandlers] Notification BODY tapped (app resumed from background)');
      _trackOpened(message.data, 'onMessageOpenedApp (body tap)');
      if (!_resolveClickAction(message.data['click_action']?.toString())) {
        _handleDeeplink(message.data['deeplink_url']?.toString());
      }
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _logIncomingPush('OPENED (launched from terminated)', message);
        debugPrint('[PushHandlers] Notification BODY tapped (app launched from terminated)');
        _trackOpened(message.data, 'getInitialMessage (body tap)');
        if (!_resolveClickAction(message.data['click_action']?.toString())) {
          _handleDeeplink(message.data['deeplink_url']?.toString());
        }
      }
    });
  }
}

/// Handles taps on local notifications (body or ACTION_0 / ACTION_1) from the
/// foreground/running-app isolate. Shared by [PushHandlers] and the
/// background entry point.
void _handleNotificationResponse(NotificationResponse response) {
  if (response.payload == null || response.payload!.isEmpty) return;

  Map<String, dynamic> payload;
  try {
    payload = jsonDecode(response.payload!) as Map<String, dynamic>;
  } catch (_) {
    return;
  }

  // Body tap always tracks "Opened", regardless of whether an action button was also tapped.
  debugPrint('[PushHandlers] Notification BODY/local-notification tapped (foreground/background isolate)');
  _trackOpened(payload, 'flutter_local_notifications response (body or action tap)');

  if (response.actionId != null && response.actionId!.isNotEmpty) {
    _trackActionClick(payload, response.actionId!);
    // Action buttons on Android are routed through a broadcast-style handler, so
    // `autoCancel` does NOT dismiss the notification for action presses (only for a body
    // tap, which goes through the default content intent) — it must be cancelled explicitly.
    // This applies regardless of `sticky`: pressing a button always removes the notification;
    // only swipe/"Clear all" is blocked when the push was marked sticky (via `ongoing`).
    if (response.id != null) {
      FlutterLocalNotificationsPlugin().cancel(response.id!);
    }
    final buttons = parseActionButtons(payload['action_buttons']);
    final actionIndex =
        int.tryParse(response.actionId!.replaceAll(RegExp(r'\D'), '')) ?? -1;
    final buttonDeeplink = (actionIndex >= 0 && actionIndex < buttons.length)
        ? buttons[actionIndex]['deeplink']?.toString() ?? ''
        : '';
    _handleDeeplink(
      buttonDeeplink.isNotEmpty
          ? buttonDeeplink
          : payload['deeplink_url']?.toString(),
    );
  } else {
    if (!_resolveClickAction(payload['click_action']?.toString())) {
      _handleDeeplink(payload['deeplink_url']?.toString());
    }
  }
}

void _trackOpened(Map<String, dynamic> data, String source) {
  final deliveryId = data['Zixflow-Delivery-ID']?.toString() ?? '';
  final deliveryToken = data['Zixflow-Delivery-Token']?.toString() ?? '';

  if (deliveryId.isNotEmpty && deliveryToken.isNotEmpty) {
    _logOutgoingTrack('OPENED', source, {
      'Zixflow-Delivery-ID': deliveryId,
      'Zixflow-Delivery-Token': deliveryToken,
      'event': 'opened',
    });
    Zixflow.instance.trackMetric(
      deliveryID: deliveryId,
      deviceToken: deliveryToken,
      event: MetricEvent.opened,
    );
  } else {
    debugPrint(
      '[PushHandlers] Skipped OPENED tracking ($source): missing Zixflow-Delivery-ID/Token in payload',
    );
  }
}

/// Tracks the "Push Notification Delivered" metric as soon as the data
/// payload arrives — call this from both the foreground `onMessage` listener
/// and the background/terminated FCM handler, before displaying the local
/// notification.
void _trackDelivered(Map<String, dynamic> data, String source) {
  final deliveryId = data['Zixflow-Delivery-ID']?.toString() ?? '';
  final deliveryToken = data['Zixflow-Delivery-Token']?.toString() ?? '';

  if (deliveryId.isNotEmpty && deliveryToken.isNotEmpty) {
    _logOutgoingTrack('DELIVERED', source, {
      'Zixflow-Delivery-ID': deliveryId,
      'Zixflow-Delivery-Token': deliveryToken,
      'event': 'delivered',
    });
    Zixflow.instance.trackMetric(
      deliveryID: deliveryId,
      deviceToken: deliveryToken,
      event: MetricEvent.delivered,
    );
  } else {
    debugPrint(
      '[PushHandlers] Skipped DELIVERED tracking ($source): missing Zixflow-Delivery-ID/Token in payload',
    );
  }
}

void _trackActionClick(Map<String, dynamic> payload, String actionId) {
  final actionIndex =
      int.tryParse(actionId.replaceAll(RegExp(r'\D'), '')) ?? -1;
  final buttons = parseActionButtons(payload['action_buttons']);
  final actionName = (actionIndex >= 0 && actionIndex < buttons.length)
      ? buttons[actionIndex]['name']?.toString() ?? 'Action ${actionIndex + 1}'
      : 'Action ${actionIndex + 1}';
  final actionDeeplink = (actionIndex >= 0 && actionIndex < buttons.length)
      ? buttons[actionIndex]['deeplink']?.toString() ?? ''
      : '';

  final properties = {
    'Zixflow-Delivery-ID': payload['Zixflow-Delivery-ID'] ?? '',
    'Zixflow-Delivery-Token': payload['Zixflow-Delivery-Token'] ?? '',
    'notification_id': payload['Zixflow-Delivery-ID'] ?? '',
    'title': payload['title'] ?? '',
    'action_id': actionId,
    'action_index': actionIndex,
    'action_name': actionName,
    'action_deeplink': actionDeeplink,
    'source': 'local_notification',
  };
  _logOutgoingTrack('CLICKED (action button)', 'flutter_local_notifications ACTION', {
    'event': 'Push Notification Action Clicked',
    'properties': properties,
  });
  Zixflow.instance.track(
    name: 'Push Notification Action Clicked',
    properties: properties,
  );
}

/// Downloads [url] to a temp file and returns its local path, or null on
/// failure / when [url] is missing or not http(s).
Future<String?> _downloadToTempFile(String? url, String fileName) async {
  if (url == null || url.isEmpty || !url.startsWith('http')) return null;
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return null;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  } catch (e) {
    debugPrint('[PushHandlers] Failed to download $url: $e');
    return null;
  }
}

/// Renders ONLY what the stock FCM contract itself defines — `notification`
/// title/body and `android.notification.image` — nothing from Zixflow's own
/// custom `data.*` scheme (no action buttons, no large icon, no badge, no
/// custom sound). This exists because any app-declared `FirebaseMessagingService`
/// (which `firebase_messaging`/FlutterFire always installs) permanently
/// intercepts the OS's own zero-code auto-render path, and FlutterFire's own
/// built-in fallback (`fcm_fallback_notification_channel`) only does title+body
/// (BigTextStyle), silently dropping the image. This is the closest faithful
/// stand-in for genuine stock rendering, using only the fields FCM's own
/// contract promises.
Future<void> _showStockEquivalentNotification(
  FlutterLocalNotificationsPlugin plugin,
  RemoteMessage message,
) async {
  final notification = message.notification;
  if (notification == null) {
    // Real stock FCM never auto-renders pure data-only messages either.
    debugPrint('[PushHandlers] No notification block — stock FCM would show nothing either');
    return;
  }

  final title = notification.title ?? '';
  final body = notification.body ?? '';
  final imageUrl = notification.android?.imageUrl ?? notification.apple?.imageUrl;
  final imagePath = await _downloadToTempFile(imageUrl, 'stock_img_${message.hashCode}.jpg');

  final androidDetails = AndroidNotificationDetails(
    _androidChannelId,
    _androidChannelName,
    importance: Importance.high,
    priority: Priority.high,
    styleInformation: imagePath != null
        ? BigPictureStyleInformation(
            FilePathAndroidBitmap(imagePath),
            contentTitle: title,
            summaryText: body,
          )
        : null,
  );

  await plugin.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        attachments: imagePath != null ? [DarwinNotificationAttachment(imagePath)] : null,
      ),
    ),
  );
}

/// Builds and displays the local notification (with dynamic action buttons,
/// rich media, sound, and badge) for the given [message] using the provided
/// plugin instance. Works from both the main isolate (foreground) and a
/// background isolate.
Future<void> _showLocalNotification(
  FlutterLocalNotificationsPlugin plugin,
  RemoteMessage message,
) async {
  final data = Map<String, dynamic>.from(message.data);
  final title =
      message.notification?.title ?? data['title']?.toString() ?? 'Notification';
  final body = message.notification?.body ?? data['body']?.toString() ?? '';

  // Prefer notification title/body in the payload for action-click tracking.
  data['title'] ??= title;
  data['body'] ??= body;

  final imageUrl = data['image_url']?.toString();
  final largeIconUrl = data['large_icon_url']?.toString();
  final soundName = data['sound']?.toString();
  final badgeNumber = int.tryParse(data['badge']?.toString() ?? '');
  // "sticky": true means the notification survives swipe-dismiss and "Clear all", but
  // STILL gets removed when tapped or when an action button is pressed — sticky only
  // blocks passive dismissal, not active interaction. `autoCancel` is therefore always
  // true below; `ongoing` is what's actually driven by `sticky`. Android only — no iOS
  // equivalent.
  final sticky = data['sticky']?.toString() == 'true';
  final id = message.hashCode;

  // Download rich media concurrently (Android BigPictureStyle / iOS attachment).
  final imagePath = await _downloadToTempFile(imageUrl, 'push_img_$id.jpg');
  final largeIconPath =
      await _downloadToTempFile(largeIconUrl, 'push_icon_$id.jpg');

  final buttons = parseActionButtons(data['action_buttons']);
  final androidActions = <AndroidNotificationAction>[];
  for (var i = 0; i < buttons.length && i < 2; i++) {
    androidActions.add(
      AndroidNotificationAction(
        'ACTION_$i',
        buttons[i]['name']?.toString() ?? 'Action ${i + 1}',
        showsUserInterface: true,
      ),
    );
  }

  // Custom data.priority (distinct from FCM's own android.priority header, which the
  // app never observes directly) picks the channel — this is what makes priority
  // visibly different in the custom-handled path (normal = no heads-up banner).
  final priority = data['priority']?.toString();
  final channelId = priority == 'normal' ? _androidChannelIdNormal : _androidChannelId;
  final channelName = priority == 'normal' ? _androidChannelNameNormal : _androidChannelName;

  // click_action — historically an Android intent-action string used by the OS-rendered
  // path to launch a matching <intent-filter> Activity. It's already present in `data`
  // (and therefore the notification payload below) if sent — resolved on tap via
  // _resolveClickAction, taking priority over deeplink_url (see call sites above).

  final analyticsLabel = data['analytics_label']?.toString();
  if (priority != null || analyticsLabel != null) {
    debugPrint(
      '[PushHandlers] Diagnostics — priority: ${priority ?? '(unset)'}, analytics_label: ${analyticsLabel ?? '(unset)'}',
    );
  }

  StyleInformation? style;
  if (imagePath != null) {
    style = BigPictureStyleInformation(
      FilePathAndroidBitmap(imagePath),
      largeIcon:
          largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
      contentTitle: title,
      summaryText: body,
      hideExpandedLargeIcon: false,
    );
  }

  AndroidNotificationSound? androidSound;
  if (soundName != null && soundName != 'default' && soundName != 'none') {
    androidSound = RawResourceAndroidNotificationSound(soundName);
  }

  final androidDetails = AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: 'Zixflow push notifications',
    icon: 'ic_notification',
    color: const Color(0xFFFA2438),
    importance: priority == 'normal' ? Importance.defaultImportance : Importance.high,
    priority: priority == 'normal' ? Priority.defaultPriority : Priority.high,
    actions: androidActions,
    styleInformation: style,
    largeIcon:
        largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
    playSound: androidSound != null,
    sound: androidSound,
    autoCancel: true,
    ongoing: sticky,
  );

  final iosAttachments = <DarwinNotificationAttachment>[
    if (imagePath != null) DarwinNotificationAttachment(imagePath),
  ];

  final iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    categoryIdentifier: 'ZX_2BTN',
    attachments: iosAttachments,
    badgeNumber: badgeNumber,
    sound: (soundName != null && soundName != 'default' && soundName != 'none')
        ? soundName
        : null,
  );

  await plugin.show(
    id,
    title,
    body,
    NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    ),
    payload: jsonEncode(data),
  );

  // ttl_seconds — our own demo interpretation of "how long this notification stays
  // visible", distinct from FCM's actual server-side delivery-queue TTL (which the app
  // never observes directly). Not part of the official Zixflow payload schema — opt-in
  // via `data.ttl_seconds` for testing.
  final ttlSeconds = int.tryParse(data['ttl_seconds']?.toString() ?? '');
  if (ttlSeconds != null && ttlSeconds > 0) {
    Future.delayed(Duration(seconds: ttlSeconds), () {
      plugin.cancel(id);
      debugPrint('[PushHandlers] Notification $id auto-cancelled after ttl_seconds=$ttlSeconds');
    });
  }
}

/// Opens [deeplink] in-app if it matches one of this demo app's own screens
/// (`zixflowdemo://sale`, `zixflowdemo://dashboard`); otherwise falls back to
/// the browser / external app (works for `https://` URLs and other custom
/// schemes).
void _handleDeeplink(String? deeplink) {
  if (deeplink == null || deeplink.isEmpty) return;
  debugPrint('[PushHandlers] Deeplink: $deeplink');

  final inAppRoute = resolveInAppRoute(deeplink);
  if (inAppRoute != null) {
    navigatorKey.currentState?.pushNamed(inAppRoute);
    return;
  }

  final uri = Uri.tryParse(deeplink);
  if (uri == null) return;
  launchUrl(uri, mode: LaunchMode.externalApplication).catchError((e) {
    debugPrint('[PushHandlers] Failed to launch deeplink $deeplink: $e');
    return false;
  });
}

/// Resolves the custom `data.click_action` token (our own Zixflow scheme, not
/// FCM's native `android.notification.click_action` field, which the OS-rendered
/// path would route via a matching `<intent-filter>` action string instead) to
/// one of this demo's screens. Takes priority over `deeplink_url` when present.
/// Returns true if handled.
bool _resolveClickAction(String? clickAction) {
  switch (clickAction) {
    case 'OPEN_SALE':
      navigatorKey.currentState?.pushNamed(saleRoute);
      return true;
    case 'OPEN_DASHBOARD':
      navigatorKey.currentState?.pushNamed(dashboardRoute);
      return true;
    default:
      if (clickAction != null && clickAction.isNotEmpty) {
        debugPrint('[PushHandlers] Unrecognized click_action: $clickAction');
      }
      return false;
  }
}

/// Logs the exact outgoing payload being sent to the Zixflow SDK for a
/// Delivered/Opened/Clicked tracking call — use this to verify what's
/// actually being POSTed for each notification lifecycle event during testing.
void _logOutgoingTrack(String kind, String source, Map<String, dynamic> payload) {
  const encoder = JsonEncoder.withIndent('  ');
  debugPrint('');
  debugPrint('----------------------------------------');
  debugPrint('📤 OUTGOING TRACK [$kind] via $source');
  debugPrint(encoder.convert(payload));
  debugPrint('----------------------------------------');
  debugPrint('');
}

/// Logs the full incoming push payload (all RemoteMessage fields + data map)
/// for any app state — foreground, background, or opened.
void _logIncomingPush(String state, RemoteMessage message) {  const encoder = JsonEncoder.withIndent('  ');
  final title = message.notification?.title ?? message.data['title'] ?? '(no title)';
  final body = message.notification?.body ?? message.data['body'] ?? '(no body)';

  debugPrint('');
  debugPrint('════════════════════════════════════════');
  debugPrint('🔔 PUSH RECEIVED [$state]');
  debugPrint('   messageId       : ${message.messageId}');
  debugPrint('   messageType     : ${message.messageType}');
  debugPrint('   senderId        : ${message.senderId}');
  debugPrint('   category        : ${message.category}');
  debugPrint('   collapseKey     : ${message.collapseKey}');
  debugPrint('   contentAvailable: ${message.contentAvailable}');
  debugPrint('   sentTime        : ${message.sentTime}');
  debugPrint('   ttl             : ${message.ttl}');
  debugPrint('   from            : ${message.from}');
  debugPrint('   title           : $title');
  debugPrint('   body            : $body');
  if (message.notification?.android != null) {
    final android = message.notification!.android!;
    debugPrint('   android.channelId  : ${android.channelId}');
    debugPrint('   android.imageUrl   : ${android.imageUrl}');
    debugPrint('   android.clickAction: ${android.clickAction}');
  }
  if (message.notification?.apple != null) {
    final apple = message.notification!.apple!;
    debugPrint('   apple.badge  : ${apple.badge}');
    debugPrint('   apple.sound  : ${apple.sound?.name}');
    debugPrint('   apple.imageUrl: ${apple.imageUrl}');
  }
  debugPrint('   data (full payload):');
  try {
    encoder.convert(message.data).split('\n').forEach((line) {
      debugPrint('     $line');
    });
  } catch (_) {
    debugPrint('     ${message.data}');
  }
  debugPrint('════════════════════════════════════════');
  debugPrint('');
}
