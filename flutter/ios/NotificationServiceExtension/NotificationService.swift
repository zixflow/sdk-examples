//
//  NotificationService.swift
//  NotificationServiceExtension
//
//  Optional: rich push (images). Requires Firebase + push setup — see README.

import UserNotifications
import ZixflowMessagingPushFCM

class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        print("NotificationService didReceive called")

        MessagingPushFCM.initializeForExtension(
            withConfig: MessagingPushConfigBuilder(cdpApiKey: Env.cdpApiKey)
                .logLevel(.debug)
                .appGroupId("group.com.zixflow.demo")
                .build()
        )
        
        MessagingPush.shared.didReceive(request, withContentHandler: contentHandler)
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        MessagingPush.shared.serviceExtensionTimeWillExpire()
    }
    
}
