package com.zixflow.demo

import android.util.Log

/**
 * Logs the exact outgoing payload being sent to the Zixflow SDK for a
 * Delivered/Opened/Clicked tracking call — use this to verify what's actually
 * being sent for each notification lifecycle event during testing. Shared by
 * [CustomFirebaseMessagingService], [MainActivity], and
 * [NotificationActionReceiver] so all three log identically.
 */
object PushTrackLogger {
    private const val TAG = "PushTrackLogger"

    fun logOutgoingTrack(kind: String, source: String, payload: Map<String, Any?>) {
        Log.i(TAG, "")
        Log.i(TAG, "----------------------------------------")
        Log.i(TAG, "\uD83D\uDCE4 OUTGOING TRACK [$kind] via $source")
        payload.forEach { (key, value) -> Log.i(TAG, "  $key = $value") }
        Log.i(TAG, "----------------------------------------")
        Log.i(TAG, "")
    }

    fun logSkipped(kind: String, source: String, reason: String) {
        Log.w(TAG, "Skipped $kind tracking ($source): $reason")
    }
}
