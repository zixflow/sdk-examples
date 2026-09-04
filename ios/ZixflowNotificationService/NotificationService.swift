import UserNotifications

/// Notification Service Extension — the ONLY way iOS can attach a remote image to a
/// push notification (Case 7 in ios-push-test-cases-v2.md: `mutable_content: true` +
/// `data.image_url`). This is inherently "custom handled" code; there is no way to get
/// an image with zero app-side code on iOS.
///
/// It is also the only client-side hook that runs the instant a push arrives while the
/// device is LOCKED or the app is killed — so it doubles as the place to track
/// `Delivered` on the lock screen (see `trackDelivered`), which the app's own delegate
/// (`willPresent`/`didReceive`) can't do because those only fire in the foreground or on tap.
///
/// Wiring this into the app (Xcode does not let you script a new target safely from
/// text edits alone — see ios/README.md "Notification Service Extension" section):
/// 1. Xcode → File → New → Target… → Notification Service Extension.
/// 2. Name it `ZixflowNotificationService`, uncheck "Activate scheme" if prompted.
/// 3. Replace the two generated files with this `NotificationService.swift` and the
///    sibling `Info.plist` in this folder.
/// 4. Build once to confirm the extension target compiles and embeds.
///
/// Sends a push with `mutable-content: 1` (gorush: `"mutable_content": true`) and
/// `data.image_url` set to a reachable HTTPS image — the banner should show the image
/// after expanding, exactly like Case 7 in the test doc.
final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    // A real Template ID from the Zixflow dashboard (Push Notifications → Templates) —
    // swap in your own template's ID to try this against a template you control.
    private let exampleTemplateId = "469935"

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        bestAttemptContent = content

        // Runs even when the device is locked — the only place iOS lets us record Delivered on arrival.
        trackDelivered(userInfo: request.content.userInfo)

        // template_id — the dashboard-assigned ID of the template used to send this push.
        // Since a template's fields are known ahead of time (from the dashboard's template
        // editor), the extension can apply a fully custom treatment using every one of them,
        // instead of the generic image-only enrichment below. Registering more templates is
        // just adding more cases to this `if`.
        if let templateId = request.content.userInfo["template_id"] as? String,
           templateId == exampleTemplateId {
            applyTemplateExampleCustomization(to: content, userInfo: request.content.userInfo)
        }

        guard let imageURLString = request.content.userInfo["image_url"] as? String,
              let imageURL = URL(string: imageURLString) else {
            contentHandler(content)
            return
        }

        downloadImage(from: imageURL) { [weak self] attachment in
            guard let self else { return }
            if let attachment {
                content.attachments = [attachment]
            }
            self.contentHandler?(content)
        }
    }

    /// Called if we run out of the ~30s the OS budgets for this extension — must still
    /// deliver *something*, even without the image.
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    /// Example customization for one specific dashboard template (see [exampleTemplateId])
    /// — applies `data.badge` (one of that template's known fields) directly, since iOS's
    /// `aps.badge` is otherwise set server-side and most of the template's other fields
    /// (large_icon_url, sticky, action_buttons) have no client-side equivalent on iOS.
    private func applyTemplateExampleCustomization(to content: UNMutableNotificationContent, userInfo: [AnyHashable: Any]) {
        if let badgeString = userInfo["badge"] as? String, let badgeValue = Int(badgeString) {
            content.badge = NSNumber(value: badgeValue)
        }
    }

    /// Fires the `Delivered` metric via the Zixflow tracking HTTP API. The extension is a
    /// separate target that doesn't link the Zixflow SDK, so it posts directly — using a
    /// write-only key, never a service-account/admin credential. Set `NSEConfig` below.
    private func trackDelivered(userInfo: [AnyHashable: Any]) {
        let deliveryId = userInfo["Zixflow-Delivery-ID"] as? String ?? ""
        let deliveryToken = userInfo["Zixflow-Delivery-Token"] as? String ?? ""
        guard !deliveryId.isEmpty, !deliveryToken.isEmpty,
              !NSEConfig.writeKey.isEmpty,
              let url = URL(string: NSEConfig.trackEndpoint) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Basic \(NSEConfig.writeKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "event": "Push Notification Delivered",
            "properties": [
                "Zixflow-Delivery-ID": deliveryId,
                "Zixflow-Delivery-Token": deliveryToken,
            ],
        ])
        URLSession.shared.dataTask(with: req).resume()
    }

    private func downloadImage(from url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { location, _, error in
            guard let location, error == nil else {
                completion(nil)
                return
            }
            // Attachments must live in a file with an extension matching their UTI —
            // move the downloaded temp file into one before handing it to UNNotificationAttachment.
            let fileExtension = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
            let tmpFile = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)
            do {
                try FileManager.default.moveItem(at: location, to: tmpFile)
                let attachment = try UNNotificationAttachment(identifier: "image", url: tmpFile, options: nil)
                completion(attachment)
            } catch {
                completion(nil)
            }
        }
        task.resume()
    }
}

/// Fill these in to enable lock-screen Delivered tracking from the extension. Use a
/// write-only event-ingestion key — the extension must never carry admin credentials.
private enum NSEConfig {
    static let trackEndpoint = "https://events.zixflow.in/v1/track"
    static let writeKey = "" // e.g. base64("YOUR_WRITE_KEY:")
}
