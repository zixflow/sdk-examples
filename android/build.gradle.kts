// Top-level build file
plugins {
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    // Firebase - applies since a real google-services.json is present.
    id("com.google.gms.google-services") version "4.4.2" apply false
}
