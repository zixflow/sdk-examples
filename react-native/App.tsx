import React, { useCallback, useEffect, useState } from 'react';
import {
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import {
  Zixflow,
  ZixflowPushPermissionStatus,
} from 'zixflow-reactnative';

import { ActionButton } from './src/components/ActionButton';
import {
  buildZixflowConfig,
  isApiKeyConfigured,
} from './src/config';
import {
  parseActionButtons,
  trackActionClick,
} from './src/pushActions';

const DEMO_USER_ID = 'user-123';
const DEMO_TOKEN_PLACEHOLDER = 'paste-fcm-or-apns-token-here';

// Exported helpers used when action-button payloads reach JS (iOS / local notifs).
export { parseActionButtons, trackActionClick };

export default function App() {
  const [log, setLog] = useState<string[]>([]);
  const [initialized, setInitialized] = useState(false);
  const [deviceTokenInput, setDeviceTokenInput] = useState('');

  const appendLog = useCallback((message: string) => {
    const stamp = new Date().toLocaleTimeString();
    setLog((prev) => [...prev.slice(-49), `[${stamp}] ${message}`]);
    console.log(`[ZixflowDemo] ${message}`);
  }, []);

  useEffect(() => {
    if (!isApiKeyConfigured()) {
      appendLog(
        'Missing API key. Copy .env.example and set ZIXFLOW_API_KEY in src/config.ts.',
      );
      return;
    }

    const config = buildZixflowConfig();

    void (async () => {
      try {
        await Zixflow.initialize(config);
        setInitialized(true);
        appendLog('Zixflow SDK initialized');
        appendLog(
          'Action buttons: iOS ZX_2BTN in AppDelegate; Android installs onNotificationComposed after init (PushActionButtonsInstaller).',
        );
      } catch (error) {
        const message =
          error instanceof Error ? error.message : String(error);
        appendLog(`Initialize failed: ${message}`);
      }
    })();
  }, [appendLog]);

  const run = useCallback(
    async (label: string, action: () => Promise<void>) => {
      if (!initialized) {
        appendLog(`Skipped ${label}: SDK not initialized`);
        return;
      }
      try {
        await action();
        appendLog(`${label} ok`);
      } catch (error) {
        const message =
          error instanceof Error ? error.message : String(error);
        appendLog(`${label} error: ${message}`);
      }
    },
    [appendLog, initialized],
  );

  const handleIdentify = () =>
    run('identify', async () => {
      await Zixflow.identify({
        userId: DEMO_USER_ID,
        traits: {
          email: 'user@example.com',
          firstName: 'John',
          lastName: 'Doe',
          plan: 'premium',
        },
      });
    });

  const handleTrack = () =>
    run('track', async () => {
      await Zixflow.track('button_clicked', {
        button_name: 'demo_track',
        screen: 'ZixflowRNDemo',
      });
    });

  const handleScreen = () =>
    run('screen', async () => {
      await Zixflow.screen('DemoHomeScreen', {
        source: 'feature_demo',
      });
    });

  const handleProfileAttributes = () =>
    run('setProfileAttributes', async () => {
      await Zixflow.setProfileAttributes({
        plan: 'premium',
        subscription_status: 'active',
        last_login: new Date().toISOString(),
        preferences: {
          newsletter: true,
          notifications: true,
        },
      });
    });

  const handleDeviceAttributes = () =>
    run('setDeviceAttributes', async () => {
      await Zixflow.setDeviceAttributes({
        app_version: '1.0.0',
        build_number: '1',
        theme: 'light',
        language_preference: 'en-US',
      });
    });

  const handleClearIdentify = () =>
    run('clearIdentify', async () => {
      await Zixflow.clearIdentify();
    });

  const fetchAndShowRegisteredToken = useCallback(async (): Promise<
    string | null
  > => {
    const token = await Zixflow.pushMessaging.getRegisteredDeviceToken();
    if (token) {
      setDeviceTokenInput(token);
      appendLog(`Registered token: ${truncate(token)}`);
      return token;
    }
    appendLog('No registered token yet');
    return null;
  }, [appendLog]);

  const handleRequestPushPermission = () =>
    run('showPromptForPushNotifications', async () => {
      const status =
        await Zixflow.pushMessaging.showPromptForPushNotifications({
          ios: { sound: true, badge: true },
        });
      appendLog(`Push permission: ${permissionLabel(status)}`);
      if (status === ZixflowPushPermissionStatus.Granted) {
        // SDK auto-registers FCM/APNs on init; refresh the field for visibility.
        try {
          await fetchAndShowRegisteredToken();
        } catch (error) {
          const message =
            error instanceof Error ? error.message : String(error);
          appendLog(
            `Token not ready yet (${message}). Tap Identify, wait a moment, then Get registered token.`,
          );
        }
      }
    });

  const handleGetRegisteredToken = () =>
    run('getRegisteredDeviceToken', async () => {
      await fetchAndShowRegisteredToken();
    });

  const handleRegisterDeviceToken = () =>
    run('registerDeviceToken', async () => {
      let token = deviceTokenInput.trim();
      if (!token || token === DEMO_TOKEN_PLACEHOLDER) {
        try {
          token =
            (await Zixflow.pushMessaging.getRegisteredDeviceToken()) ?? '';
        } catch {
          token = '';
        }
        if (token) {
          setDeviceTokenInput(token);
        }
      }
      if (!token || token === DEMO_TOKEN_PLACEHOLDER) {
        throw new Error(
          'No token available. Request permission first (and ensure google-services.json is installed), or paste a token.',
        );
      }
      await Zixflow.registerDeviceToken(token);
      appendLog(`Registered token with SDK: ${truncate(token)}`);
    });

  const handleDeleteDeviceToken = () =>
    run('deleteDeviceToken', async () => {
      await Zixflow.deleteDeviceToken();
    });

  const statusText = !isApiKeyConfigured()
    ? 'Set ZIXFLOW_API_KEY in src/config.ts'
    : initialized
      ? 'SDK initialized — tap buttons to send events'
      : 'Initializing SDK…';

  return (
    <ScrollView
      contentContainerStyle={styles.container}
      keyboardShouldPersistTaps="handled"
    >
      <Text style={styles.title}>Zixflow React Native SDK</Text>
      <Text style={styles.subtitle}>
        Feature demo for identify, track, screen, profile/device attributes,
        and push token APIs.
      </Text>

      <View style={styles.statusBox}>
        <Text style={styles.statusLabel}>Status</Text>
        <Text style={styles.statusText}>{statusText}</Text>
        {initialized ? (
          <Text style={styles.statusNote}>
            Action buttons: send a dashboard push with two buttons. iOS uses
            ZX_2BTN (AppDelegate). Android installs onNotificationComposed via
            PushActionButtonsInstaller after SDK init.
          </Text>
        ) : null}
      </View>

      <Section title="Core">
        <View style={styles.grid}>
          <ActionButton label="Identify" onPress={handleIdentify} />
          <ActionButton label="Track" onPress={handleTrack} />
          <ActionButton label="Screen" onPress={handleScreen} />
          <ActionButton
            label="Set profile attributes"
            onPress={handleProfileAttributes}
          />
          <ActionButton
            label="Set device attributes"
            onPress={handleDeviceAttributes}
          />
          <ActionButton
            label="Clear identify"
            onPress={handleClearIdentify}
            secondary
          />
        </View>
      </Section>

      <Section title="Push (native setup required)">
        <Text style={styles.hint}>
          Recommended order: 1) Identify 2) Request push permission 3) Get
          registered token. With Android `google-services.json` (client config)
          installed, the SDK auto-fetches FCM on init — you usually only need
          Identify + permission. Use Register only to re-send or paste a custom
          token. See README and native-snippets/.
        </Text>
        <Text style={styles.hint}>
          Action buttons: send a dashboard push with `action_buttons` (and
          `aps.category` = ZX_2BTN on iOS). Helpers live in `src/pushActions.ts`.
          This Android demo wires buttons natively after init
          (PushActionButtonsInstaller); see README / native-snippets.
        </Text>
        <View style={styles.grid}>
          <ActionButton
            label="Request push permission"
            onPress={handleRequestPushPermission}
          />
          <ActionButton
            label="Get registered token"
            onPress={handleGetRegisteredToken}
          />
          <ActionButton
            label="Register device token"
            onPress={handleRegisterDeviceToken}
          />
          <ActionButton
            label="Delete device token"
            onPress={handleDeleteDeviceToken}
            secondary
          />
        </View>
        <Text style={styles.fieldLabel}>
          Device token (auto-filled after Get / permission, or paste)
        </Text>
        <TextInput
          style={styles.input}
          value={deviceTokenInput}
          onChangeText={setDeviceTokenInput}
          autoCapitalize="none"
          autoCorrect={false}
          multiline
          placeholder={DEMO_TOKEN_PLACEHOLDER}
        />
      </Section>

      <Section title="Location notes">
        <Text style={styles.hint}>
          Location tracking is optional: add the location Podfile subspec (iOS)
          and zixflow_location_enabled=true (Android). Request OS permission in
          your app before calling location APIs.
        </Text>
      </Section>

      <Section title="Log">
        <View style={styles.logBox}>
          {log.length === 0 ? (
            <Text style={styles.logEmpty}>Actions will appear here…</Text>
          ) : (
            log.map((line, index) => (
              <Text key={`${line}-${index}`} style={styles.logLine}>
                {line}
              </Text>
            ))
          )}
        </View>
      </Section>
    </ScrollView>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title}</Text>
      {children}
    </View>
  );
}

function permissionLabel(status: ZixflowPushPermissionStatus): string {
  switch (status) {
    case ZixflowPushPermissionStatus.Granted:
      return 'Granted';
    case ZixflowPushPermissionStatus.Denied:
      return 'Denied';
    case ZixflowPushPermissionStatus.NotDetermined:
      return 'Not determined';
    default:
      return String(status);
  }
}

function truncate(value: string, max = 24): string {
  if (value.length <= max) {
    return value;
  }
  return `${value.slice(0, max)}…`;
}

const styles = StyleSheet.create({
  container: {
    padding: 20,
    paddingBottom: 40,
    backgroundColor: '#f8fafc',
    flexGrow: 1,
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
    color: '#0f172a',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 14,
    color: '#475569',
    lineHeight: 20,
    marginBottom: 16,
  },
  statusBox: {
    backgroundColor: '#ffffff',
    borderRadius: 10,
    padding: 14,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  statusLabel: {
    fontSize: 12,
    fontWeight: '600',
    color: '#64748b',
    textTransform: 'uppercase',
    marginBottom: 4,
  },
  statusText: {
    fontSize: 14,
    color: '#0f172a',
  },
  statusNote: {
    fontSize: 12,
    color: '#64748b',
    lineHeight: 17,
    marginTop: 8,
  },
  section: {
    backgroundColor: '#ffffff',
    borderRadius: 10,
    padding: 14,
    marginBottom: 14,
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#0f172a',
    marginBottom: 10,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    justifyContent: 'space-between',
  },
  hint: {
    fontSize: 13,
    color: '#64748b',
    lineHeight: 18,
    marginBottom: 10,
  },
  fieldLabel: {
    fontSize: 12,
    fontWeight: '600',
    color: '#64748b',
    marginTop: 8,
    marginBottom: 6,
  },
  input: {
    borderWidth: 1,
    borderColor: '#cbd5e1',
    borderRadius: 8,
    padding: 10,
    fontSize: 13,
    color: '#0f172a',
    backgroundColor: '#f8fafc',
    minHeight: 44,
  },
  logBox: {
    backgroundColor: '#0f172a',
    borderRadius: 8,
    padding: 12,
    minHeight: 160,
  },
  logEmpty: {
    color: '#94a3b8',
    fontSize: 13,
  },
  logLine: {
    color: '#e2e8f0',
    fontSize: 12,
    fontFamily: 'Menlo',
    marginBottom: 4,
  },
});
