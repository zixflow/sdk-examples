package com.zixflow.demo

import android.content.Context
import android.content.Intent
import android.net.Uri

/**
 * Routes a Zixflow push deeplink to one of this demo app's own screens when
 * it matches the app's custom `zixflowdemo://` scheme (`zixflowdemo://sale`,
 * `zixflowdemo://dashboard`), or falls back to an external `ACTION_VIEW`
 * intent (browser / other app) for anything else — e.g. real `https://` URLs.
 *
 * Used from both [MainActivity] (body-tap deeplink) and
 * [NotificationActionReceiver] (action-button deeplink) so both interaction
 * paths get the same in-app-vs-external routing behavior.
 */
object DeeplinkRouter {
    private const val SCHEME = "zixflowdemo"

    fun open(context: Context, deeplink: String?) {
        if (deeplink.isNullOrEmpty()) return

        val uri = try {
            Uri.parse(deeplink)
        } catch (_: Exception) {
            return
        }

        val inAppIntent = if (uri.scheme == SCHEME) {
            when (uri.host) {
                "sale" -> Intent(context, SaleActivity::class.java)
                "dashboard" -> Intent(context, DashboardActivity::class.java)
                else -> null
            }
        } else {
            null
        }

        val intent = (inAppIntent ?: Intent(Intent.ACTION_VIEW, uri)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            context.startActivity(intent)
        } catch (_: Exception) {
            // No app can handle this URI (e.g. unsupported scheme) — ignore.
        }
    }

    /**
     * Resolves the custom `data.click_action` token (our own Zixflow scheme, not
     * FCM's native `android.notification.click_action` field) to one of this demo's
     * screens. Returns true if handled — caller should skip `deeplink_url` in that case.
     */
    fun openClickAction(context: Context, clickAction: String?): Boolean {
        val intent = when (clickAction) {
            "OPEN_SALE" -> Intent(context, SaleActivity::class.java)
            "OPEN_DASHBOARD" -> Intent(context, DashboardActivity::class.java)
            else -> null
        } ?: return false

        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        return true
    }
}
