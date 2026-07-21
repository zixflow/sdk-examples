import React from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { ActionButton } from './ActionButton';

type Props = {
  onBack: () => void;
};

/** Demo screen opened via the `zixflowdemo://dashboard` push notification deeplink. */
export function DashboardScreen({ onBack }: Readonly<Props>) {
  return (
    <View style={styles.container}>
      <Text style={styles.emoji}>📊</Text>
      <Text style={styles.title}>Your Dashboard</Text>
      <Text style={styles.subtitle}>
        Opened via push notification deeplink (zixflowdemo://dashboard).
      </Text>
      <ActionButton label="Back" onPress={onBack} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
    gap: 12,
  },
  emoji: {
    fontSize: 48,
  },
  title: {
    fontSize: 22,
    fontWeight: '700',
    textAlign: 'center',
  },
  subtitle: {
    textAlign: 'center',
    marginBottom: 12,
  },
});
