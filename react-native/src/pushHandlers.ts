import { Linking, Platform } from 'react-native';
import messaging, {
  FirebaseMessagingTypes,
} from '@react-native-firebase/messaging';
import notifee, {
  AndroidImportance,
  AndroidStyle,
  EventType,
  type Notification,
} from '@notifee/react-native';
import { MetricEvent, Zixflow } from 'zixflow-reactnative';

import { parseActionButtons } from './pushActions';
import { navigate, resolveInAppRoute } from './navigation';

/**
 * Pure JavaScript/TypeScript push notification handling for Android — no
 * custom native Kotlin code required (mirrors the Flutter SDK example, which
 * uses `firebase_messaging` + `flutter_local_notifications` entirely in Dart).
 *
 * `zixflow-reactnative`'s JS API does not emit incoming push messages to JS
 * (only `onMessageReceived` to *report* an already-known message for
 * tracking), so `@react-native-firebase/messaging` is used here as the FCM
 * listener, and `@notifee/react-native` displays the notification — including
 * dynamic action buttons parsed from the `action_buttons` payload field.
 *
 * The Zixflow SDK's own native FCM service still runs in parallel (Android
 * allows multiple manifest-declared FCM receivers) and continues to handle
 * device-token registration/refresh and default delivery tracking; this
 * module owns notification *display* and action-button tracking.
 */

const ANDROID_CHANNEL_ID = 'zixflow_default';
const ANDROID_CHANNEL_NAME = 'Zixflow Notifications';

let cachedToken: string | undefined;

/** Parses the Zixflow `action_buttons` JSON field into notifee actions. */
function buildNotifeeActions(data: Record<string, string | undefined>) {
  const buttons = parseActionButtons(data.action_buttons);
  return buttons.slice(0, 2).map((button, index) => ({
    title: button.name || `Action ${index + 1}`,
    pressAction: { id: `action_${index}` },
  }));
}

/** Logs the full incoming push payload (all RemoteMessage fields + data map). */
function logIncomingPush(
  state: string,
  message: FirebaseMessagingTypes.RemoteMessage,
) {
  const title =
    message.notification?.title ?? message.data?.title ?? '(no title)';
  const body =
    message.notification?.body ?? message.data?.body ?? '(no body)';

  console.log('');
  console.log('════════════════════════════════════════');
  console.log(`🔔 PUSH RECEIVED [${state}]`);
  console.log(`   messageId    : ${message.messageId}`);
  console.log(`   sentTime     : ${message.sentTime}`);
  console.log(`   ttl          : ${message.ttl}`);
  console.log(`   from         : ${message.from}`);
  console.log(`   collapseKey  : ${message.collapseKey}`);
  console.log(`   title        : ${title}`);
  console.log(`   body         : ${body}`);
  console.log('   data (full payload):');
  console.log(JSON.stringify(message.data ?? {}, null, 2));
  console.log('════════════════════════════════════════');
  console.log('');
}

/** Returns true if `value` looks like a usable http(s) image URL for notifee. */
function isValidImageUrl(value?: string): value is string {
  return Boolean(value) && /^https?:\/\//i.test(value as string);
}

/** Displays a local notification (with dynamic action buttons) via notifee. */
async function showNotification(
  message: FirebaseMessagingTypes.RemoteMessage,
) {
  const data = (message.data ?? {}) as Record<string, string | undefined>;
  const title =
    message.notification?.title ?? data.title ?? 'Notification';
  const body = message.notification?.body ?? data.body ?? '';

  const soundName =
    data.sound && data.sound !== 'default' && data.sound !== 'none'
      ? data.sound
      : undefined;
  const badgeCount = data.badge != null ? parseInt(data.badge, 10) : undefined;
  // "sticky": true means the notification survives swipe-dismiss and "Clear all", but
  // STILL gets removed when tapped or when an action button is pressed — sticky only
  // blocks passive dismissal, not active interaction. `autoCancel` is therefore always
  // true below; `ongoing` is what's actually driven by `sticky`. Android only — no iOS
  // equivalent.
  const sticky = data.sticky === 'true';

  if (badgeCount != null && !Number.isNaN(badgeCount)) {
    notifee.setBadgeCount(badgeCount).catch(() => {});
  }

  const hasBadge = badgeCount != null && !Number.isNaN(badgeCount);

  // notifee's validators check for key *presence* (`hasOwnProperty`), not just
  // truthiness — so `sound: undefined` / `badgeCount: undefined` / `largeIcon:
  // undefined` still fail validation ("must be a string/number value if
  // specified") because the key exists on the object. Conditionally spread
  // each optional field so the key is omitted entirely when there's no value.
  await notifee.displayNotification({
    title,
    body,
    data,
    android: {
      channelId: ANDROID_CHANNEL_ID,
      importance: AndroidImportance.HIGH,
      pressAction: { id: 'default' },
      actions: buildNotifeeActions(data),
      ...(isValidImageUrl(data.large_icon_url)
        ? { largeIcon: data.large_icon_url }
        : {}),
      ...(isValidImageUrl(data.image_url)
        ? { style: { type: AndroidStyle.BIGPICTURE, picture: data.image_url } }
        : {}),
      ...(soundName ? { sound: soundName } : {}),
      autoCancel: true,
      ongoing: sticky,
    },
    ios: {
      categoryId: 'ZX_2BTN',
      ...(soundName ? { sound: soundName } : {}),
      ...(hasBadge ? { badgeCount } : {}),
    },
  });
}


/** Tracks the "opened" metric for a delivered push using its delivery IDs. */
function trackOpened(data: Record<string, string | undefined>) {
  const deliveryId = data['Zixflow-Delivery-ID'] ?? '';
  const deliveryToken =
    data['Zixflow-Delivery-Token'] ?? cachedToken ?? '';

  if (deliveryId && deliveryToken) {
    Zixflow.trackMetric({
      deliveryID: deliveryId,
      deviceToken: deliveryToken,
      event: MetricEvent.Opened,
    }).catch(() => {});
  }
}

/** Tracks the "delivered" metric as soon as the data payload arrives — call this
 * from both the foreground `onMessage` listener and the background handler,
 * before displaying the local notification. */
function trackDelivered(data: Record<string, string | undefined>) {
  const deliveryId = data['Zixflow-Delivery-ID'] ?? '';
  const deliveryToken = data['Zixflow-Delivery-Token'] ?? cachedToken ?? '';

  if (deliveryId && deliveryToken) {
    Zixflow.trackMetric({
      deliveryID: deliveryId,
      deviceToken: deliveryToken,
      event: MetricEvent.Delivered,
    }).catch(() => {});
  }
}

/** Tracks "Push Notification Action Clicked" and opens the button's deeplink. */
function trackActionClick(
  data: Record<string, string | undefined>,
  actionId: string,
) {
  const actionIndex = parseInt(actionId.replace(/\D/g, ''), 10) || 0;
  const buttons = parseActionButtons(data.action_buttons);
  const button = buttons[actionIndex];
  const actionName = button?.name || `Action ${actionIndex + 1}`;
  const actionDeeplink = button?.deeplink ?? '';

  Zixflow.track('Push Notification Action Clicked', {
    'Zixflow-Delivery-ID': data['Zixflow-Delivery-ID'] ?? '',
    'Zixflow-Delivery-Token': data['Zixflow-Delivery-Token'] ?? '',
    notification_id: data['Zixflow-Delivery-ID'] ?? '',
    title: data.title ?? '',
    action_id: actionId,
    action_index: actionIndex,
    action_name: actionName,
    action_deeplink: actionDeeplink,
    source: 'local_notification',
  }).catch(() => {});

  handleDeeplink(actionDeeplink || data.deeplink_url);
}

function handleDeeplink(deeplink?: string) {
  if (!deeplink) return;
  console.log(`[PushHandlers] Deeplink: ${deeplink}`);

  const screen = resolveInAppRoute(deeplink);
  if (screen) {
    navigate(screen);
    return;
  }

  Linking.openURL(deeplink).catch(() => {});
}

/** Handles a notifee event (foreground or background) for a tap or action press. */
function handleNotifeeEvent(type: EventType, detail: { notification?: Notification; pressAction?: { id: string } }) {
  const data = (detail.notification?.data ?? {}) as Record<
    string,
    string | undefined
  >;

  if (type === EventType.PRESS) {
    trackOpened(data);
    handleDeeplink(data.deeplink_url);
  } else if (type === EventType.ACTION_PRESS && detail.pressAction) {
    trackOpened(data);
    trackActionClick(data, detail.pressAction.id);
    // Action buttons on Android are routed through notifee's background handler, so
    // `autoCancel` does NOT dismiss the notification for action presses (only for the
    // default body-tap `pressAction`) — it must be cancelled explicitly. This applies
    // regardless of `sticky`: pressing a button always removes the notification; only
    // swipe/"Clear all" is blocked when the push was marked sticky (via `ongoing`).
    if (detail.notification?.id) {
      notifee.cancelNotification(detail.notification.id).catch(() => {});
    }
  }
}

export const PushHandlers = {
  /** FCM token, updated on registration/refresh — read by the UI for display. */
  fcmToken: undefined as string | undefined,

  /** Call after `Zixflow.initialize()`. Sets up permissions, token, and listeners. */
  async initialize(): Promise<void> {
    await notifee.requestPermission();
    if (Platform.OS === 'android') {
      await notifee.createChannel({
        id: ANDROID_CHANNEL_ID,
        name: ANDROID_CHANNEL_NAME,
        importance: AndroidImportance.HIGH,
      });
    }

    if (Platform.OS === 'ios') {
      // iOS requires explicit APNs registration + permission via
      // @react-native-firebase/messaging before `getToken()` will resolve —
      // notifee's permission request alone does not register the device for
      // remote messages.
      await messaging().requestPermission();
      if (!messaging().isDeviceRegisteredForRemoteMessages) {
        await messaging().registerDeviceForRemoteMessages();
      }
    }

    await registerToken();
    messaging().onTokenRefresh(async (newToken) => {
      cachedToken = newToken;
      PushHandlers.fcmToken = newToken;
      await Zixflow.registerDeviceToken(newToken);
      console.log(`[PushHandlers] FCM token refreshed: ${newToken}`);
    });

    // Foreground: FCM message received while app is open.
    messaging().onMessage(async (message) => {
      logIncomingPush('FOREGROUND', message);
      trackDelivered((message.data ?? {}) as Record<string, string>);
      await showNotification(message);
    });

    // Notification tap that brought the app from background to foreground.
    messaging().onNotificationOpenedApp((message) => {
      logIncomingPush('OPENED (tapped from background)', message);
      trackOpened((message.data ?? {}) as Record<string, string>);
      handleDeeplink(message.data?.deeplink_url as string | undefined);
    });

    // App launched by tapping a notification while fully terminated.
    const initialMessage = await messaging().getInitialNotification();
    if (initialMessage) {
      logIncomingPush('OPENED (launched from terminated)', initialMessage);
      trackOpened((initialMessage.data ?? {}) as Record<string, string>);
      handleDeeplink(initialMessage.data?.deeplink_url as string | undefined);
    }

    // Foreground taps/action presses on notifee-displayed notifications.
    notifee.onForegroundEvent(({ type, detail }) => {
      handleNotifeeEvent(type, detail);
    });
  },
};

async function registerToken() {
  try {
    const token = await messaging().getToken();
    cachedToken = token;
    PushHandlers.fcmToken = token;
    await Zixflow.registerDeviceToken(token);
    console.log('');
    console.log('════════════════════════════════════════');
    console.log('[PushHandlers] FCM token registered:');
    console.log(token);
    console.log('════════════════════════════════════════');
    console.log('');
  } catch (error) {
    console.log(`[PushHandlers] Failed to register token: ${error}`);
  }
}

/**
 * Background FCM message handler — must be registered at the top level of
 * `index.js` (before `AppRegistry.registerComponent`), same pattern as
 * `FirebaseMessaging.onBackgroundMessage` in Flutter. Displays the
 * notification (with action buttons) while the app is backgrounded/killed.
 */
export async function firebaseBackgroundMessageHandler(
  message: FirebaseMessagingTypes.RemoteMessage,
): Promise<void> {
  logIncomingPush('BACKGROUND/TERMINATED', message);
  trackDelivered((message.data ?? {}) as Record<string, string>);
  await showNotification(message);
}

/**
 * Background notifee event handler (action button / notification tap while
 * app is backgrounded or terminated) — must be registered at the top level of
 * `index.js`.
 */
export async function notifeeBackgroundEventHandler({
  type,
  detail,
}: {
  type: EventType;
  detail: { notification?: Notification; pressAction?: { id: string } };
}): Promise<void> {
  handleNotifeeEvent(type, detail);
}
