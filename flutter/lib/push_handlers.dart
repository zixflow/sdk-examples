import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zixflow/zixflow.dart';

import 'config.dart';

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

  await _showLocalNotification(plugin, message);
}

/// Handles a notification tap (body or action button) delivered to a
/// background isolate, i.e. the app was fully terminated. Re-initializes the
/// Zixflow SDK (required in a fresh isolate) before tracking the tap.
@pragma('vm:entry-point')
Future<void> _notificationTapBackground(NotificationResponse response) async {
  await Zixflow.initialize(
    config: ZixflowConfig(apiKey: AppConfig.zixflowApiKey),
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

  static const String _iosCategoryId = 'ZX_2BTN';

  /// Call after [Firebase.initializeApp] and [Zixflow.initialize].
  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

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
      Zixflow.instance.registerDeviceToken(deviceToken: _fcmToken!);
      _printToken('FCM token registered', _fcmToken!);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      fcmToken.value = newToken;
      Zixflow.instance.registerDeviceToken(deviceToken: newToken);
      _printToken('FCM token refreshed', newToken);
    });
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
      _showLocalNotification(_localNotifications, message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logIncomingPush('OPENED (tapped from background)', message);
      _trackOpened(message.data);
      _handleDeeplink(message.data['deeplink_url']?.toString());
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _logIncomingPush('OPENED (launched from terminated)', message);
        _trackOpened(message.data);
        _handleDeeplink(message.data['deeplink_url']?.toString());
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

  _trackOpened(payload);

  if (response.actionId != null && response.actionId!.isNotEmpty) {
    _trackActionClick(payload, response.actionId!);
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
    _handleDeeplink(payload['deeplink_url']?.toString());
  }
}

void _trackOpened(Map<String, dynamic> data) {
  final deliveryId = data['Zixflow-Delivery-ID']?.toString() ?? '';
  final deliveryToken = data['Zixflow-Delivery-Token']?.toString() ?? '';

  if (deliveryId.isNotEmpty && deliveryToken.isNotEmpty) {
    Zixflow.instance.trackMetric(
      deliveryID: deliveryId,
      deviceToken: deliveryToken,
      event: MetricEvent.opened,
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

  Zixflow.instance.track(
    name: 'Push Notification Action Clicked',
    properties: {
      'Zixflow-Delivery-ID': payload['Zixflow-Delivery-ID'] ?? '',
      'Zixflow-Delivery-Token': payload['Zixflow-Delivery-Token'] ?? '',
      'notification_id': payload['Zixflow-Delivery-ID'] ?? '',
      'title': payload['title'] ?? '',
      'action_id': actionId,
      'action_index': actionIndex,
      'action_name': actionName,
      'action_deeplink': actionDeeplink,
      'source': 'local_notification',
    },
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
    _androidChannelId,
    _androidChannelName,
    channelDescription: 'Zixflow push notifications',
    importance: Importance.high,
    priority: Priority.high,
    actions: androidActions,
    styleInformation: style,
    largeIcon:
        largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
    playSound: androidSound != null,
    sound: androidSound,
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
}

/// Opens [deeplink] in the browser / external app (works for both `https://`
/// URLs and custom schemes like `zixflow://`).
void _handleDeeplink(String? deeplink) {
  if (deeplink == null || deeplink.isEmpty) return;
  debugPrint('[PushHandlers] Deeplink: $deeplink');
  final uri = Uri.tryParse(deeplink);
  if (uri == null) return;
  launchUrl(uri, mode: LaunchMode.externalApplication).catchError((e) {
    debugPrint('[PushHandlers] Failed to launch deeplink $deeplink: $e');
    return false;
  });
}

/// Logs the full incoming push payload (all RemoteMessage fields + data map)
/// for any app state — foreground, background, or opened.
void _logIncomingPush(String state, RemoteMessage message) {
  const encoder = JsonEncoder.withIndent('  ');
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
