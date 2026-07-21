import React from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { ActionButton } from './ActionButton';

type Props = {
  onBack: () => void;
};

/** Demo screen opened via the `zixflowdemo://sale` push notification deeplink. */
export function SaleScreen({ onBack }: Readonly<Props>) {
  return (
    <View style={styles.container}>
      <Text style={styles.emoji}>🔥</Text>
      <Text style={styles.title}>Flash Sale — 70% OFF!</Text>
      <Text style={styles.subtitle}>
        Opened via push notification deeplink (zixflowdemo://sale).
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
