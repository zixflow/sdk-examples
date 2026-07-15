import { AppRegistry } from 'react-native';
import messaging from '@react-native-firebase/messaging';
import notifee from '@notifee/react-native';
import App from './App';
import { name as appName } from './app.json';
import {
  firebaseBackgroundMessageHandler,
  notifeeBackgroundEventHandler,
} from './src/pushHandlers';

// Must be registered at the top level, before AppRegistry.registerComponent,
// so these handlers work when the app is backgrounded or fully terminated.
messaging().setBackgroundMessageHandler(firebaseBackgroundMessageHandler);
notifee.onBackgroundEvent(notifeeBackgroundEventHandler);

AppRegistry.registerComponent(appName, () => App);
