plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // Firebase — applies automatically since google-services.json is present.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.zixflow.demo"
    compileSdk = 36

    defaultConfig {
        // Must match android_client_info.package_name in google-services.json
        // (the real Firebase-registered package) or FCM token registration fails.
        applicationId = "com.company.zixflow"
        minSdk = 21
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // Using the locally published SDK build (version "local") which includes the
    // BUG-A12 fix (Zixflow-Delivery-ID/Token casing). Switch back to a published
    // version (e.g. "1.1.3") once the fix ships in a real release.
    implementation("com.zixflow.com.android:datapipelines:local")
    implementation("com.zixflow.com.android:messaging-push-fcm:local")
    implementation("com.zixflow.com.android:location:local")

    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("androidx.core:core-ktx:1.15.0")
}
