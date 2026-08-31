import { Linking, Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
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
// Selected when `data.priority === 'normal'` — lower importance, no heads-up banner,
// mirroring FCM's own high/normal priority distinction (which otherwise only affects
// delivery timing, not anything visible — this channel makes the difference observable
// in the custom-handled path).
const ANDROID_CHANNEL_ID_NORMAL = 'zixflow_normal';
// Bundled at android/app/src/main/res/raw/notification_tone.wav — reference it in a
// test payload as `"sound": "notification_tone"` to hear a real custom sound (a synthesized
// two-tone chime, not a licensed asset, safe to ship in this demo).
const BUNDLED_TEST_SOUND = 'notification_tone';

let cachedToken: string | undefined;

// Persisted (not just in-memory) so a fresh headless JS context spun up for
// `firebaseBackgroundMessageHandler` after the app was fully killed still sees
// whatever the user last set in the UI.
const CUSTOM_HANDLING_PREF_KEY = 'zixflow_demo_custom_handling_enabled';

// Cached for synchronous reads in the foreground `onMessage` listener (same JS
// context as the UI, so no need to hit AsyncStorage on every message).
let cachedCustomHandlingEnabled = true;

async function isCustomHandlingEnabled(): Promise<boolean> {
  const stored = await AsyncStorage.getItem(CUSTOM_HANDLING_PREF_KEY);
  return stored == null ? true : stored === 'true';
}

async function setCustomHandlingEnabled(value: boolean): Promise<void> {
  cachedCustomHandlingEnabled = value;
  await AsyncStorage.setItem(CUSTOM_HANDLING_PREF_KEY, value ? 'true' : 'false');
}

type NotificationDataValue = string | number | object;
type NotificationData = Record<string, NotificationDataValue>;

function toLogString(value: unknown): string {
  if (typeof value === 'string') return value;
  if (value == null) return '';
  try {
    return JSON.stringify(value);
  } catch {
    return '[unserializable]';
  }
}

function sanitizeNotificationData(
  data: Record<string, unknown>,
): NotificationData {
  const entries = Object.entries(data).filter(([, value]) => value !== undefined);
  return Object.fromEntries(entries) as NotificationData;
}

function getStringField(
  data: Record<string, unknown>,
  key: string,
): string | undefined {
  const value = data[key];
  return typeof value === 'string' ? value : undefined;
}

/** Parses the Zixflow `action_buttons` JSON field into notifee actions. */
function buildNotifeeActions(data: Record<string, unknown>) {
  const buttons = parseActionButtons(getStringField(data, 'action_buttons'));
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
  const titleRaw =
    message.notification?.title ?? message.data?.title ?? '(no title)';
  const bodyRaw =
    message.notification?.body ?? message.data?.body ?? '(no body)';

  console.log('');
  console.log('════════════════════════════════════════');
  console.log(`🔔 PUSH RECEIVED [${state}]`);
  console.log(`   messageId    : ${message.messageId}`);
  console.log(`   sentTime     : ${message.sentTime}`);
  console.log(`   ttl          : ${message.ttl}`);
  console.log(`   from         : ${message.from}`);
  console.log(`   collapseKey  : ${message.collapseKey}`);
  console.log(`   title        : ${toLogString(titleRaw)}`);
  console.log(`   body         : ${toLogString(bodyRaw)}`);
  console.log('   data (full payload):');
  console.log(JSON.stringify(message.data ?? {}, null, 2));
  console.log('════════════════════════════════════════');
  console.log('');
}

/** Returns true if `value` looks like a usable http(s) image URL for notifee. */
function isValidImageUrl(value?: string): value is string {
  return Boolean(value) && /^https?:\/\//i.test(value as string);
}

/**
 * True if `message` carries anything worth showing — a native `notification`
 * block, or a `title`/`body` in `data` (Zixflow's own custom-UI scheme, since
 * the real dashboard sends data-only pushes). False for pure silent/
 * background-sync pushes (Case 12 android / Case 8 & 18 iOS in the test docs)
 * — those must be "handled by ourselves, no custom UI": process data, show
 * nothing.
 */
function hasDisplayableContent(
  message: FirebaseMessagingTypes.RemoteMessage,
): boolean {
  return Boolean(
    message.notification || message.data?.title || message.data?.body,
  );
}

/**
 * Logs the exact outgoing payload being sent to the Zixflow SDK for a
 * Delivered/Opened/Clicked tracking call — use this to verify what's actually
 * being POSTed for each notification lifecycle event during testing.
 */
function logOutgoingTrack(kind: string, source: string, payload: unknown) {
  console.log('');
  console.log('----------------------------------------');
  console.log(`\u{1F4E4} OUTGOING TRACK [${kind}] via ${source}`);
  console.log(JSON.stringify(payload, null, 2));
  console.log('----------------------------------------');
  console.log('');
}

/** Displays a local notification (with dynamic action buttons) via notifee. */
async function showNotification(
  message: FirebaseMessagingTypes.RemoteMessage,
) {
  const data: NotificationData = sanitizeNotificationData(
    (message.data ?? {}) as Record<string, unknown>,
  );
  const titleFromData = getStringField(data, 'title');
  const bodyFromData = getStringField(data, 'body');
  const soundFromData = getStringField(data, 'sound');
  const badgeFromData = getStringField(data, 'badge');
  const stickyFromData = getStringField(data, 'sticky');
  const largeIconUrl = getStringField(data, 'large_icon_url');
  const imageUrl = getStringField(data, 'image_url');
  const title =
    message.notification?.title ?? titleFromData ?? 'Notification';
  const body = message.notification?.body ?? bodyFromData ?? '';

  const soundName =
    soundFromData && soundFromData !== 'default' && soundFromData !== 'none'
      ? soundFromData
      : undefined;
  const badgeCount =
    badgeFromData != null ? Number.parseInt(badgeFromData, 10) : undefined;
  // "sticky": true means the notification survives swipe-dismiss and "Clear all", but
  // STILL gets removed when tapped or when an action button is pressed — sticky only
  // blocks passive dismissal, not active interaction. `autoCancel` is therefore always
  // true below; `ongoing` is what's actually driven by `sticky`. Android only — no iOS
  // equivalent.
  const sticky = stickyFromData === 'true';

  if (badgeCount != null && !Number.isNaN(badgeCount)) {
    notifee.setBadgeCount(badgeCount).catch(() => {});
  }

  const hasBadge = badgeCount != null && !Number.isNaN(badgeCount);

  // Priority — FCM's own android.priority only affects delivery timing (Doze bypass),
  // not anything visible. We make the difference observable here by picking a lower-
  // importance channel for "normal", so a normal-priority push doesn't heads-up banner.
  const priorityFromData = getStringField(data, 'priority');
  const channelId = priorityFromData === 'normal' ? ANDROID_CHANNEL_ID_NORMAL : ANDROID_CHANNEL_ID;

  // click_action — historically an Android intent-action string used by the OS-rendered
  // path to launch a matching <intent-filter> Activity. notifee/RN has no direct "set
  // Intent.action" API, so we treat it as an alternate, higher-priority routing signal
  // for the body tap, resolved the same way as deeplink_url (see resolveClickAction).
  const clickAction = getStringField(data, 'click_action');

  // Diagnostic-only fields — not used to build the notification, just surfaced in
  // tracking so campaign debugging can see what the server actually sent.
  const ttl = message.ttl;
  const analyticsLabel = getStringField(data, 'analytics_label');

  // notifee's validators check for key *presence* (`hasOwnProperty`), not just
  // truthiness — so `sound: undefined` / `badgeCount: undefined` / `largeIcon:
  // undefined` still fail validation ("must be a string/number value if
  // specified") because the key exists on the object. Conditionally spread
  // each optional field so the key is omitted entirely when there's no value.
  const notificationId = await notifee.displayNotification({
    title,
    body,
    data: { ...data, ...(clickAction ? { click_action: clickAction } : {}) },
    android: {
      channelId,
      importance: AndroidImportance.HIGH,
      smallIcon: 'ic_notification', // matches the bundled drawable + manifest default
      pressAction: { id: 'default' },
      actions: buildNotifeeActions(data),
      ...(isValidImageUrl(largeIconUrl)
        ? { largeIcon: largeIconUrl }
        : {}),
      ...(isValidImageUrl(imageUrl)
        ? { style: { type: AndroidStyle.BIGPICTURE, picture: imageUrl } }
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

  // ttl_seconds — our own demo interpretation of "how long this notification stays
  // visible", distinct from FCM's actual server-side delivery-queue TTL (which the app
  // never observes directly; `message.ttl` above is diagnostic only). Not part of the
  // official Zixflow payload schema — opt-in via `data.ttl_seconds` for testing.
  const ttlSecondsFromData = getStringField(data, 'ttl_seconds');
  if (ttlSecondsFromData) {
    const ttlSeconds = Number.parseInt(ttlSecondsFromData, 10);
    if (!Number.isNaN(ttlSeconds) && ttlSeconds > 0) {
      setTimeout(() => {
        notifee.cancelNotification(notificationId).catch(() => {});
        console.log(`[PushHandlers] Notification ${notificationId} auto-cancelled after ttl_seconds=${ttlSeconds}`);
      }, ttlSeconds * 1000);
    }
  }

  if (ttl != null || priorityFromData || analyticsLabel) {
    console.log(
      `[PushHandlers] Diagnostics — ttl(server): ${ttl}, priority: ${priorityFromData ?? '(unset)'}, analytics_label: ${analyticsLabel ?? '(unset)'}`,
    );
  }
}


/** Tracks the "opened" metric for a delivered push using its delivery IDs. */
function trackOpened(data: Record<string, unknown>, source: string) {
  const deliveryId = getStringField(data, 'Zixflow-Delivery-ID') ?? '';
  const deliveryToken =
    getStringField(data, 'Zixflow-Delivery-Token') ?? cachedToken ?? '';

  if (deliveryId && deliveryToken) {
    const payload = {
      deliveryID: deliveryId,
      deviceToken: deliveryToken,
      event: MetricEvent.Opened,
    };
    logOutgoingTrack('OPENED', source, {
      'Zixflow-Delivery-ID': deliveryId,
      'Zixflow-Delivery-Token': deliveryToken,
      event: MetricEvent.Opened,
    });
    Zixflow.trackMetric(payload).catch((error) => {
      console.log(`[PushHandlers] trackMetric(Opened) failed: ${error}`);
    });
  } else {
    console.log(
      `[PushHandlers] Skipped OPENED tracking (${source}): missing Zixflow-Delivery-ID/Token in payload`,
    );
  }
}

/** Tracks the "delivered" metric as soon as the data payload arrives — call this
 * from both the foreground `onMessage` listener and the background handler,
 * before displaying the local notification. */
function trackDelivered(data: Record<string, unknown>, source: string) {
  const deliveryId = getStringField(data, 'Zixflow-Delivery-ID') ?? '';
  const deliveryToken = getStringField(data, 'Zixflow-Delivery-Token') ?? cachedToken ?? '';

  if (!deliveryId || !deliveryToken) {
    console.log(
      `[PushHandlers] Skipped DELIVERED tracking (${source}): missing Zixflow-Delivery-ID/Token in payload`,
    );
    return;
  }

  const payload = {
    deliveryID: deliveryId,
    deviceToken: deliveryToken,
    event: MetricEvent.Delivered,
  };
  logOutgoingTrack('DELIVERED', source, {
    'Zixflow-Delivery-ID': deliveryId,
    'Zixflow-Delivery-Token': deliveryToken,
    event: MetricEvent.Delivered,
  });
  Zixflow.trackMetric(payload).catch((error) => {
    console.log(`[PushHandlers] trackMetric(Delivered) failed: ${error}`);
  });

  // analytics_label isn't part of trackMetric's fixed schema — surfaced as a separate
  // named event so it's still queryable/correlatable in the dashboard.
  const analyticsLabel = getStringField(data, 'analytics_label');
  if (analyticsLabel) {
    Zixflow.track('Push Notification Analytics Label', {
      'Zixflow-Delivery-ID': deliveryId,
      analytics_label: analyticsLabel,
    }).catch(() => {});
  }
}

/** Tracks "Push Notification Action Clicked" and opens the button's deeplink. */
function trackActionClick(
  data: Record<string, unknown>,
  actionId: string,
) {
  const actionIndex = Number.parseInt(actionId.replace(/\D/g, ''), 10) || 0;
  const buttons = parseActionButtons(getStringField(data, 'action_buttons'));
  const button = buttons[actionIndex];
  const actionName = button?.name || `Action ${actionIndex + 1}`;
  const actionDeeplink = button?.deeplink ?? '';

  const properties = {
    'Zixflow-Delivery-ID': getStringField(data, 'Zixflow-Delivery-ID') ?? '',
    'Zixflow-Delivery-Token': getStringField(data, 'Zixflow-Delivery-Token') ?? '',
    notification_id: getStringField(data, 'Zixflow-Delivery-ID') ?? '',
    title: getStringField(data, 'title') ?? '',
    action_id: actionId,
    action_index: actionIndex,
    action_name: actionName,
    action_deeplink: actionDeeplink,
    source: 'local_notification',
  };
  logOutgoingTrack('CLICKED (action button)', 'notifee ACTION_PRESS', {
    event: 'Push Notification Action Clicked',
    properties,
  });
  Zixflow.track('Push Notification Action Clicked', properties).catch((error) => {
    console.log(`[PushHandlers] track(Action Clicked) failed: ${error}`);
  });

  handleDeeplink(actionDeeplink || getStringField(data, 'deeplink_url'));
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

/**
 * click_action is the classic Android "which screen" signal (paired with a matching
 * <intent-filter> on the OS-rendered path) — here we just map a couple of known tokens
 * to our own routes, taking priority over `deeplink_url` for the body tap when present.
 */
function resolveClickAction(clickAction?: string): boolean {
  if (!clickAction) return false;
  switch (clickAction) {
    case 'OPEN_SALE':
      navigate('sale');
      return true;
    case 'OPEN_DASHBOARD':
      navigate('dashboard');
      return true;
    default:
      console.log(`[PushHandlers] Unrecognized click_action: ${clickAction}`);
      return false;
  }
}

/** Handles a notifee event (foreground or background) for a tap or action press. */
function handleNotifeeEvent(type: EventType, detail: { notification?: Notification; pressAction?: { id: string } }) {
  const data = (detail.notification?.data ?? {}) as Record<string, unknown>;

  if (type === EventType.PRESS) {
    // Notification BODY tap (not an action button) — must always track "Opened".
    console.log('[PushHandlers] Notification BODY tapped (notifee PRESS)');
    trackOpened(data, 'notifee PRESS (body tap)');
    // click_action takes priority over deeplink_url when both are present.
    if (!resolveClickAction(getStringField(data, 'click_action'))) {
      handleDeeplink(getStringField(data, 'deeplink_url'));
    }
  } else if (type === EventType.ACTION_PRESS && detail.pressAction) {
    trackOpened(data, 'notifee ACTION_PRESS');
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

  /** Current push handling mode, read by the UI toggle. */
  isCustomHandlingEnabled,

  /** Sets the push handling mode from the UI toggle. */
  async setCustomHandlingEnabled(value: boolean): Promise<void> {
    await setCustomHandlingEnabled(value);
  },

  /** Call after `Zixflow.initialize()`. Sets up permissions, token, and listeners. */
  async initialize(): Promise<void> {
    cachedCustomHandlingEnabled = await isCustomHandlingEnabled();

    await notifee.requestPermission();
    if (Platform.OS === 'android') {
      await notifee.createChannel({
        id: ANDROID_CHANNEL_ID,
        name: ANDROID_CHANNEL_NAME,
        importance: AndroidImportance.HIGH,
      });
      // Selected when data.priority === 'normal' — no heads-up banner, just the shade.
      await notifee.createChannel({
        id: ANDROID_CHANNEL_ID_NORMAL,
        name: 'Zixflow Notifications (Normal)',
        importance: AndroidImportance.DEFAULT,
      });
    }

    if (Platform.OS === 'ios') {
      // iOS requires explicit APNs registration + permission via
      // `registerDeviceForRemoteMessages()` before `getToken()` will resolve.
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

      if (!cachedCustomHandlingEnabled) {
        console.log(
          '[PushHandlers] Custom handling OFF — Firebase/APNs handles this push entirely, app code does nothing',
        );
        return;
      }

      trackDelivered((message.data ?? {}) as Record<string, unknown>, 'onMessage (foreground)');
      if (!hasDisplayableContent(message)) {
        console.log(
          '[PushHandlers] Silent/data-only push (no notification content) — processing data, showing no UI',
        );
        return;
      }
      await showNotification(message);
    });

    // Notification tap that brought the app from background to foreground.
    messaging().onNotificationOpenedApp((message) => {
      logIncomingPush('OPENED (tapped from background)', message);
      console.log('[PushHandlers] Notification BODY tapped (app resumed from background)');
      trackOpened((message.data ?? {}) as Record<string, unknown>, 'onNotificationOpenedApp (body tap)');
      handleDeeplink(message.data?.deeplink_url as string | undefined);
    });

    // App launched by tapping a notification while fully terminated.
    const initialMessage = await messaging().getInitialNotification();
    if (initialMessage) {
      logIncomingPush('OPENED (launched from terminated)', initialMessage);
      console.log('[PushHandlers] Notification BODY tapped (app launched from terminated)');
      trackOpened((initialMessage.data ?? {}) as Record<string, unknown>, 'getInitialNotification (body tap)');
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

  if (!(await isCustomHandlingEnabled())) {
    console.log(
      '[PushHandlers] Custom handling OFF — Firebase/APNs handles this push entirely, app code does nothing',
    );
    return;
  }

  trackDelivered((message.data ?? {}) as Record<string, unknown>, 'firebaseBackgroundMessageHandler');

  if (!hasDisplayableContent(message)) {
    console.log(
      '[PushHandlers] Silent/data-only push (no notification content) — processing data, showing no UI',
    );
    return;
  }

  // A `notification` block delivered while backgrounded/terminated is already
  // auto-displayed by the OS (FCM/APNs bypass this handler's *display* concerns —
  // it only runs so the app can process data alongside it). Building our own
  // notifee notification here too would show a duplicate. Only build one ourselves
  // for data-only messages carrying our own custom title/body fields.
  if (message.notification) {
    console.log(
      '[PushHandlers] Notification-block push in background — solely handled by FCM/APNs, skipping local notification to avoid duplicate',
    );
    return;
  }

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
