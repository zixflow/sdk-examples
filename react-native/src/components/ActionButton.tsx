import React from 'react';
import {
  Pressable,
  StyleSheet,
  Text,
  View,
  type PressableProps,
} from 'react-native';

type ActionButtonProps = PressableProps & {
  label: string;
  secondary?: boolean;
};

export function ActionButton({
  label,
  secondary,
  style,
  ...rest
}: ActionButtonProps) {
  return (
    <Pressable
      accessibilityRole="button"
      style={({ pressed }) => [
        styles.button,
        secondary && styles.buttonSecondary,
        pressed && styles.buttonPressed,
        style,
      ]}
      {...rest}
    >
      <Text style={[styles.label, secondary && styles.labelSecondary]}>
        {label}
      </Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    backgroundColor: '#2563eb',
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 12,
    minWidth: '47%',
  },
  buttonSecondary: {
    backgroundColor: '#e2e8f0',
  },
  buttonPressed: {
    opacity: 0.85,
  },
  label: {
    color: '#ffffff',
    fontSize: 14,
    fontWeight: '600',
    textAlign: 'center',
  },
  labelSecondary: {
    color: '#0f172a',
  },
});
