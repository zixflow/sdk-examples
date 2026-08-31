/**
 * Minimal in-app screen router — no navigation library dependency needed for
 * this demo app. Push handlers (which run outside the React component tree,
 * including notifee background event handlers) call `navigate()`; `App.tsx`
 * subscribes to render the corresponding screen.
 */
export type ScreenName = 'home' | 'sale' | 'dashboard';

type Listener = (screen: ScreenName) => void;

let currentScreen: ScreenName = 'home';
const listeners = new Set<Listener>();

export function navigate(screen: ScreenName): void {
  currentScreen = screen;
  listeners.forEach((listener) => listener(screen));
}

export function getCurrentScreen(): ScreenName {
  return currentScreen;
}

/** Subscribes to screen changes; returns an unsubscribe function. */
export function subscribe(listener: Listener): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

/**
 * Returns the in-app screen name for `deeplink` if it points at one of this
 * demo app's own screens (`zixflowdemo://sale`, `zixflowdemo://dashboard`),
 * or `null` if it should instead be treated as an external URL (opened via
 * `Linking.openURL`).
 */
export function resolveInAppRoute(deeplink?: string): ScreenName | null {
  if (!deeplink) return null;
  const match = /^zixflowdemo:\/\/(sale|dashboard)\b/i.exec(deeplink);
  if (!match) return null;
  return match[1].toLowerCase() as ScreenName;
}
