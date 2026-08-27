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

    /// Resolves the custom `click_action` token (our own Zixflow scheme — iOS has no
    /// native client-visible `click_action` field at all; this exists purely for parity
    /// with the Android/Flutter/RN samples' custom-handled routing). Takes priority over
    /// `deeplink_url` when both are present. Returns `true` if handled.
    @discardableResult
    func openClickAction(_ clickAction: String?) -> Bool {
        switch clickAction {
        case "OPEN_SALE":
            activeScreen = .sale
            return true
        case "OPEN_DASHBOARD":
            activeScreen = .dashboard
            return true
        default:
            if let clickAction, !clickAction.isEmpty {
                print("[PushHandlers] Unrecognized click_action: \(clickAction)")
            }
            return false
        }
    }
}
