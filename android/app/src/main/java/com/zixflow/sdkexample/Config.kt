package com.zixflow.sdkexample

/**
 * Replace YOUR_API_KEY with a key from Zixflow → Settings → Developers → API Keys.
 * Do not commit real keys.
 */
object Config {
    const val apiKey: String = "YOUR_API_KEY"

    /** When true, registers FCM push and location modules at init. */
    const val enableOptionalModules: Boolean = true
}
