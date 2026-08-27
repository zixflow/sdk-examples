import UserNotifications

/// Notification Service Extension — the ONLY way iOS can attach a remote image to a
/// push notification (Case 7 in ios-push-test-cases-v2.md: `mutable_content: true` +
/// `data.image_url`). This is inherently "custom handled" code; there is no way to get
/// an image with zero app-side code on iOS.
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

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        bestAttemptContent = content

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
