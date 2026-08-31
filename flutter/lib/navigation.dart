import 'package:flutter/material.dart';

/// Global navigator key so push notification handlers (which run outside the
/// widget tree — including the background isolate used for FCM background
/// messages) can trigger in-app navigation when a Zixflow deeplink matches
/// one of this app's own screens.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Route name for the demo "Flash Sale" screen, reachable via the
/// `zixflowdemo://sale` deeplink.
const String saleRoute = '/sale';

/// Route name for the demo "Dashboard" screen, reachable via the
/// `zixflowdemo://dashboard` deeplink.
const String dashboardRoute = '/dashboard';

/// Returns the named in-app route for [deeplink] if it points at one of this
/// demo app's own screens (`zixflowdemo://sale`, `zixflowdemo://dashboard`),
/// or `null` if it should instead be treated as an external URL (opened via
/// `url_launcher`).
String? resolveInAppRoute(String? deeplink) {
  if (deeplink == null || deeplink.isEmpty) return null;
  final uri = Uri.tryParse(deeplink);
  if (uri == null || uri.scheme != 'zixflowdemo') return null;

  switch (uri.host) {
    case 'sale':
      return saleRoute;
    case 'dashboard':
      return dashboardRoute;
    default:
      return null;
  }
}
