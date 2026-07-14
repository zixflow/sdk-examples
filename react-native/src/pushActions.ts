import { Linking } from 'react-native';
import { MetricEvent, Zixflow } from 'zixflow-reactnative';

export type ActionButton = {
  name: string;
  deeplink: string;
};

export type PushActionPayload = Record<string, unknown> | null | undefined;

/**
 * Parse the Zixflow `action_buttons` JSON field from a push payload.
 * Returns up to 2 buttons (platform-consistent max).
 */
export function parseActionButtons(raw: unknown): ActionButton[] {
  if (raw == null || raw === '') {
    return [];
  }

  try {
    const decoded = typeof raw === 'string' ? JSON.parse(raw) : raw;
    if (!Array.isArray(decoded)) {
      return [];
    }

    return decoded
      .slice(0, 2)
      .map((button: { name?: string; deeplink?: string }) => ({
        name: button?.name ?? '',
        deeplink: button?.deeplink ?? '',
      }))
      .filter((button) => button.name.length > 0);
  } catch (error) {
    console.error('[ZixflowDemo] Error parsing action buttons:', error);
    return [];
  }
}

/**
 * Resolve 0-based action index from identifiers like `ACTION_0` / `ACTION_1`
 * or a numeric string.
 */
export function actionIndexFromId(actionId: string): number {
  const digits = actionId.replace(/\D/g, '');
  if (!digits) {
    return -1;
  }
  return parseInt(digits, 10);
}

export type TrackActionClickOptions = {
  /** Push data map (remoteMessage.data / notification userInfo). */
  data: PushActionPayload;
  /** Action identifier from the OS (e.g. `ACTION_0`) or numeric index string. */
  actionId: string;
  /**
   * Cached FCM/APNs token to use when `Zixflow-Delivery-Token` is missing
   * from the payload.
   */
  cachedToken?: string;
  /** When true (default), open the button deeplink via Linking. */
  openDeeplink?: boolean;
};

/**
 * Track Opened then "Push Notification Action Clicked" for an action-button tap.
 *
 * Call this when an action response reaches JS (e.g. after iOS category
 * handling or a custom local-notification library). On iOS, register `ZX_2BTN`
 * in AppDelegate so buttons appear; see native-snippets/ios/.
 *
 * Android: the RN bridge does not expose `setNotificationCallback` today —
 * use `native-snippets/android/PushActionButtons.kt` with a native callback
 * (see the Android example app) until the package passes it from JS.
 */
export async function trackActionClick(
  options: TrackActionClickOptions,
): Promise<void> {
  const { data, actionId, cachedToken = '', openDeeplink = true } = options;
  const payload = data ?? {};

  const deliveryId = String(
    payload['Zixflow-Delivery-ID'] ?? payload['ZIXFLOW-Delivery-ID'] ?? '',
  );
  const deliveryToken = String(
    payload['Zixflow-Delivery-Token'] ??
      payload['ZIXFLOW-Delivery-Token'] ??
      cachedToken ??
      '',
  );

  const actionIndex = actionIndexFromId(actionId);
  const buttons = parseActionButtons(payload['action_buttons']);
  const actionName =
    buttons[actionIndex]?.name ?? `Action ${actionIndex + 1}`;
  const actionDeeplink = buttons[actionIndex]?.deeplink ?? '';

  if (deliveryId && deliveryToken) {
    await Zixflow.trackMetric({
      deliveryID: deliveryId,
      deviceToken: deliveryToken,
      event: MetricEvent.Opened,
    });
  }

  await Zixflow.track('Push Notification Action Clicked', {
    'Zixflow-Delivery-ID': deliveryId,
    'Zixflow-Delivery-Token': deliveryToken,
    action_index: actionIndex,
    action_name: actionName,
    action_deeplink: actionDeeplink,
  });

  if (openDeeplink && actionDeeplink) {
    Linking.openURL(actionDeeplink).catch(() => {});
  }
}
