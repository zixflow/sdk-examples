import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:zixflow/zixflow.dart';

import 'config.dart';
import 'push_handlers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // Optional: Firebase + push notifications (action buttons via local notifs)
  // ---------------------------------------------------------------------------
  // Set AppConfig.enablePush = true (or --dart-define=ENABLE_PUSH=true) after:
  //   1. Adding google-services.json / GoogleService-Info.plist (see README)
  //   2. Uncommenting the Google Services Gradle plugin + POST_NOTIFICATIONS
  //   3. Optionally running `flutterfire configure` for firebase_options.dart
  //
  // Demo stays runnable with enablePush == false (default).
  if (AppConfig.enablePush) {
    try {
      // Uses native google-services.json / GoogleService-Info.plist when present.
      // If you generated firebase_options.dart via FlutterFire CLI, you can instead:
      //   import 'firebase_options.dart';
      //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await Firebase.initializeApp();
      debugPrint('[ZixflowDemo] Firebase initialized');
    } catch (e, st) {
      debugPrint(
        '[ZixflowDemo] Firebase init failed — add Firebase config files '
        'or set enablePush=false. Error: $e\n$st',
      );
    }
  }

  final config = ZixflowConfig(
    apiKey: AppConfig.zixflowApiKey,
    logLevel: LogLevel.debug,
    locationConfig: AppConfig.enableLocation
        ? LocationConfig(trackingMode: LocationTrackingMode.manual)
        : null,
  );

  await Zixflow.initialize(config: config);

  if (AppConfig.enablePush && Firebase.apps.isNotEmpty) {
    await PushHandlers.initialize();
  }

  runApp(const ZixflowDemoApp());
}

class ZixflowDemoApp extends StatelessWidget {
  const ZixflowDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zixflow Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  String _status = 'Ready. Tap a button to call the SDK.';

  void _setStatus(String message) {
    setState(() => _status = message);
    debugPrint('[ZixflowDemo] $message');
  }

  void _identify() {
    Zixflow.instance.identify(
      userId: 'user@example.com',
      traits: {
        'email': 'user@example.com',
        'first_name': 'Demo',
        'last_name': 'User',
        'plan': 'premium',
      },
    );
    _setStatus('identify() → user@example.com');
  }

  void _track() {
    Zixflow.instance.track(
      name: 'button_clicked',
      properties: {
        'button_name': 'demo_track',
        'source': 'flutter_sdk_example',
      },
    );
    _setStatus('track() → button_clicked');
  }

  void _screen() {
    Zixflow.instance.screen(
      title: 'DemoHomePage',
      properties: {'category': 'sdk_examples'},
    );
    _setStatus('screen() → DemoHomePage');
  }

  void _setProfileAttributes() {
    Zixflow.instance.setProfileAttributes(
      attributes: {
        'subscription_status': 'active',
        'preferences': {'notifications': true},
      },
    );
    _setStatus('setProfileAttributes() sent');
  }

  void _setDeviceAttributes() {
    Zixflow.instance.setDeviceAttributes(
      attributes: {
        'app_theme': 'light',
        'demo_build': 'flutter_example',
      },
    );
    _setStatus('setDeviceAttributes() sent');
  }

  void _clearIdentify() {
    Zixflow.instance.clearIdentify();
    _setStatus('clearIdentify() — user cleared');
  }

  void _registerDeviceToken() {
    Zixflow.instance.registerDeviceToken(
      deviceToken: AppConfig.demoDeviceToken,
    );
    _setStatus(
      'registerDeviceToken() → ${AppConfig.demoDeviceToken} (demo token)',
    );
  }

  void _deleteDeviceToken() {
    Zixflow.instance.deleteDeviceToken();
    _setStatus('deleteDeviceToken() sent');
  }

  @override
  Widget build(BuildContext context) {
    final actions = <({String label, VoidCallback onPressed})>[
      (label: 'Identify', onPressed: _identify),
      (label: 'Track Event', onPressed: _track),
      (label: 'Screen View', onPressed: _screen),
      (label: 'Set Profile Attributes', onPressed: _setProfileAttributes),
      (label: 'Set Device Attributes', onPressed: _setDeviceAttributes),
      (label: 'Clear Identify', onPressed: _clearIdentify),
      (label: 'Register Device Token (demo)', onPressed: _registerDeviceToken),
      (label: 'Delete Device Token', onPressed: _deleteDeviceToken),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zixflow Flutter Demo'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _status,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (AppConfig.enablePush)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Push enabled (Firebase). Identify a user, then send a test '
                'push with action_buttons from the Zixflow dashboard.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: actions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final action = actions[index];
                return ElevatedButton(
                  onPressed: action.onPressed,
                  child: Text(action.label),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
