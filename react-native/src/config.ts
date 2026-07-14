import {
  ZixflowConfig,
  ZixflowLogLevel,
  PushClickBehaviorAndroid,
} from 'zixflow-reactnative';

/**
 * Set your API key here after copying from .env.example.
 * Do not commit real keys to version control.
 */
export const ZIXFLOW_API_KEY = '';

export function isApiKeyConfigured(): boolean {
  return Boolean(ZIXFLOW_API_KEY);
}

export function buildZixflowConfig(): ZixflowConfig {
  return {
    apiKey: ZIXFLOW_API_KEY,
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
