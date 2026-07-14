plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // Optional Firebase: uncomment with a real google-services.json
    // id("com.google.gms.google-services")
}

android {
    namespace = "com.zixflow.demo"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.zixflow.demo"
        minSdk = 21
        targetSdk = 35
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

configurations.configureEach {
    resolutionStrategy {
        // Keep androidx.core on 1.15.x so AGP 8.7 / compileSdk 35 stay compatible
        // (transitive deps may otherwise pull 1.17+, which needs compileSdk 36 + AGP 8.9+)
        force("androidx.core:core:1.15.0")
        force("androidx.core:core-ktx:1.15.0")
    }
}

dependencies {
    implementation("com.zixflow.com.android:datapipelines:1.1.3")
    implementation("com.zixflow.com.android:messaging-push-fcm:1.1.3")
    implementation("com.zixflow.com.android:location:1.1.3")

    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("androidx.core:core-ktx:1.15.0")
}
