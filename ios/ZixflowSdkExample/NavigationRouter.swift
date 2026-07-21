import Foundation
import SwiftUI

/// In-app screen router for push notification deeplinks — mirrors the pattern used in the
/// Flutter (`navigation.dart`), React Native (`navigation.ts`), and native Android
/// (`DeeplinkRouter.kt`) sample apps: `zixflowdemo://sale` and `zixflowdemo://dashboard` are
/// resolved to in-app screens; anything else is left for the caller to open externally
/// (e.g. via `UIApplication.shared.open`).
final class NavigationRouter: ObservableObject {
    static let shared = NavigationRouter()

    enum Screen: Identifiable {
        case sale
        case dashboard

        var id: Self { self }
    }

    @Published var activeScreen: Screen?

    private init() {}

    /// Attempts to resolve `deeplink` to an in-app screen and, if it matches, presents it.
    /// Returns `true` if handled in-app; `false` if the caller should fall back to opening
    /// the URL externally (e.g. a real `https://` URL or an unrecognized scheme/host).
    @discardableResult
    func open(deeplink: String?) -> Bool {
        guard let deeplink, !deeplink.isEmpty,
              let url = URL(string: deeplink),
              url.scheme?.lowercased() == "zixflowdemo"
        else {
            return false
        }

        switch url.host?.lowercased() {
        case "sale":
            activeScreen = .sale
            return true
        case "dashboard":
            activeScreen = .dashboard
            return true
        default:
            return false
        }
    }
}
