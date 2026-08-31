package com.zixflow.demo

import android.content.Context

/**
 * Push handling mode toggle, exposed in the UI (`MainActivity`) and read by
 * [CustomFirebaseMessagingService]. Persisted in SharedPreferences since the
 * FCM service can run in a fresh process (app killed) and must see whatever
 * the user last set.
 */
object PushSettings {
    private const val PREFS_NAME = "zixflow_demo_prefs"
    private const val KEY_CUSTOM_HANDLING_ENABLED = "custom_handling_enabled"

    /**
     * `true` (default) = today's existing custom handling: process data, track
     * Delivered, build a notification when there's displayable content.
     * `false` = "solely handled by FCM": this app's code does nothing at all for
     * incoming pushes — background/killed notification-block pushes still show
     * via the OS (unaffected either way), but data-only pushes and foreground
     * display are entirely skipped, exactly as if no push code had been written.
     */
    fun isCustomHandlingEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_CUSTOM_HANDLING_ENABLED, true)
    }

    fun setCustomHandlingEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_CUSTOM_HANDLING_ENABLED, enabled)
            .apply()
    }
}
