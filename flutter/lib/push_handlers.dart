import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:zixflow/zixflow.dart';

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

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Delivery tracking is handled by the native Zixflow push module when configured.
  // This handler keeps FCM from dropping background data messages.
  debugPrint('[PushHandlers] Background message: ${message.messageId}');
}

/// Firebase Cloud Messaging + flutter_local_notifications with ACTION_0 / ACTION_1.
class PushHandlers {
  PushHandlers._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static String? _fcmToken;

  static const String _androidChannelId = 'zixflow_default';
  static const String _androidChannelName = 'Zixflow Notifications';
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
      settings: InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
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
      Zixflow.instance.registerDeviceToken(deviceToken: _fcmToken!);
      debugPrint('[PushHandlers] FCM token registered');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      Zixflow.instance.registerDeviceToken(deviceToken: newToken);
      debugPrint('[PushHandlers] FCM token refreshed');
    });
  }

  static void _setupMessageListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _trackOpened(message.data);
      _handleDeeplink(message.data['deeplink_url']?.toString());
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _trackOpened(message.data);
        _handleDeeplink(message.data['deeplink_url']?.toString());
      }
    });
  }

  /// Handles taps on local notifications (body or ACTION_0 / ACTION_1).
  static void onDidReceiveNotificationResponse(NotificationResponse response) {
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

  static void _trackOpened(Map<String, dynamic> data) {
    final deliveryId = data['Zixflow-Delivery-ID']?.toString() ?? '';
    final deliveryToken =
        data['Zixflow-Delivery-Token']?.toString() ?? _fcmToken ?? '';

    if (deliveryId.isNotEmpty && deliveryToken.isNotEmpty) {
      Zixflow.instance.trackMetric(
        deliveryID: deliveryId,
        deviceToken: deliveryToken,
        event: MetricEvent.opened,
      );
    }
  }

  static void _trackActionClick(Map<String, dynamic> payload, String actionId) {
    final actionIndex =
        int.tryParse(actionId.replaceAll(RegExp(r'\D'), '')) ?? -1;
    final buttons = parseActionButtons(payload['action_buttons']);
    final actionName = (actionIndex >= 0 && actionIndex < buttons.length)
        ? buttons[actionIndex]['name']?.toString() ??
            'Action ${actionIndex + 1}'
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

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final data = Map<String, dynamic>.from(message.data);
    final title = message.notification?.title ??
        data['title']?.toString() ??
        'Notification';
    final body =
        message.notification?.body ?? data['body']?.toString() ?? '';

    // Prefer notification title/body in the payload for action-click tracking.
    data['title'] ??= title;
    data['body'] ??= body;

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

    final androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: 'Zixflow push notifications',
      importance: Importance.high,
      priority: Priority.high,
      actions: androidActions,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: _iosCategoryId,
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: jsonEncode(data),
    );
  }

  static void _handleDeeplink(String? deeplink) {
    if (deeplink == null || deeplink.isEmpty) return;
    debugPrint('[PushHandlers] Deeplink: $deeplink');
  }
}
