# Native integration snippets for Zixflow React Native SDK
#
# This demo ships JavaScript/TypeScript source only. After generating a bare
# React Native project (see ../README.md), apply the snippets below.

## Android

### `android/build.gradle` (project level)

Ensure minimum SDK and repositories:

```gradle
buildscript {
    ext {
        minSdkVersion = 21
        compileSdkVersion = 34
        targetSdkVersion = 34
    }
    dependencies {
        classpath("com.android.tools.build:gradle")
        classpath("com.facebook.react:react-native-gradle-plugin")
        // FCM only:
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url 'https://s01.oss.sonatype.org/content/repositories/snapshots/' }
    }
}
```

### `android/app/build.gradle`

For FCM, apply Google Services at the bottom:

```gradle
apply plugin: "com.google.gms.google-services"
```

Place your `google-services.json` in `android/app/` (never commit real files).

### `android/gradle.properties` (location module)

```properties
zixflow_location_enabled=true
```

### `MainApplication.kt`

See `android/MainApplication.kt` in this folder. Zixflow auto-links via React Native;
no manual package registration is required for the core SDK.

## iOS

### Podfile — APNs (iOS-only push)

```ruby
target 'YourApp' do
  config = use_native_modules!
  use_react_native!(:path => config[:reactNativePath])

  pod 'zixflow-reactnative/apn', :path => '../node_modules/zixflow-reactnative'
end
```

### Podfile — FCM (cross-platform Firebase)

```ruby
use_frameworks! :linkage => :static

target 'YourApp' do
  config = use_native_modules!
  use_react_native!(:path => config[:reactNativePath])

  pod 'zixflow-reactnative/fcm', :path => '../node_modules/zixflow-reactnative'
end
```

### Podfile — location module (optional)

```ruby
pod 'zixflow-reactnative/location', :path => '../node_modules/zixflow-reactnative'
```

Then run:

```bash
cd ios && pod install
```

### AppDelegate (APNs)

See `ios/AppDelegate.swift.apn`. Enable Push Notifications and Background Modes
(Remote notifications) in Xcode.

### AppDelegate (FCM)

See `ios/AppDelegate.swift.fcm`. Add `GoogleService-Info.plist` to the Xcode
project (never commit real files).

### Rich push (optional)

Add a Notification Service Extension target and follow the iOS setup guide for
`NotificationService.swift` with `ZixflowMessagingPushAPN`.

## Push credentials

- Configure APNs certificates or FCM server key in the Zixflow dashboard.
- Identify users before sending targeted notifications.
- iOS Simulator cannot receive push; use a physical device.
