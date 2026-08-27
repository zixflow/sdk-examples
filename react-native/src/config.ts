import {
  ZixflowConfig,
  ZixflowLogLevel,
  PushClickBehaviorAndroid,
} from 'zixflow-reactnative';

/**
 * Set your API key here after copying from .env.example.
 * Do not commit real keys to version control.
 *
 * TEMPORARY: set to the Data Pipelines (event-ingress) dev workspace write key
 * for local end-to-end push notification testing.
 *   Workspace ID: 68be4f797a6494676161e98b
 *   Write key:    yKFQ9h4gqa5kM3Hf2hUyKeOk1lMjBADE
 * Revert to 'YOUR_API_KEY' before committing.
 */
export const ZIXFLOW_API_KEY = 'yKFQ9h4gqa5kM3Hf2hUyKeOk1lMjBADE';

/**
 * Dev environment API host for event-ingress. Prod default (unset) is
 * api-events.zixflow.com/v1 — override here to route through the dev
 * Data Pipelines deployment instead.
 */
export const ZIXFLOW_API_HOST = 'dev-events.zixflow.in/v1';

export function isApiKeyConfigured(): boolean {
  return Boolean(ZIXFLOW_API_KEY);
}

export function buildZixflowConfig(): ZixflowConfig {
  return {
    apiKey: ZIXFLOW_API_KEY,
    apiHost: ZIXFLOW_API_HOST,
    logLevel: ZixflowLogLevel.Debug,
    autoTrackDeviceAttributes: true,
    trackApplicationLifecycleEvents: true,
    // Registers ModuleMessagingPushFCM on Android. Action buttons are attached
    // in native code (PushActionButtonsInstaller) because the RN bridge does
    // not expose setNotificationCallback from JS.
    push: {
      android: {
        pushClickBehavior: PushClickBehaviorAndroid.ActivityPreventRestart,
      },
    },
  };
}
