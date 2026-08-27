import Foundation

/// Push handling mode toggle, exposed in the UI (`ContentView`) and read by
/// `AppDelegate`. Persisted in UserDefaults since it must survive relaunch.
enum PushSettings {
    private static let key = "zixflow_demo_custom_handling_enabled"

    /// `true` (default) = today's existing custom handling: process data, track
    /// Delivered, present a banner/build a notification when there's alert
    /// content. `false` = "solely handled by APNs": this app's code does nothing
    /// at all for incoming pushes — background/killed alert pushes still show
    /// via the OS (unaffected either way), but silent pushes and foreground
    /// presentation are entirely skipped, exactly as if no push code had been
    /// written.
    static var isCustomHandlingEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: key) == nil { return true }
            return UserDefaults.standard.bool(forKey: key)
        }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
