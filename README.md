# 🐻 Bearound Flutter SDK

Official Flutter plugin for the Bearound native SDKs (Android/iOS) version 3.3.1.

## Features

- Native beacon scanning on Android and iOS
- Real-time beacon stream with metadata (battery, firmware, temperature)
- Sync lifecycle events (sync started/completed callbacks)
- Background detection events (beacons detected in background)
- Optional Android foreground service (`connectedDevice`) for resilient background scanning
- Scanning state and error streams
- User properties support for enriched beacon events
- **Native permission handling** - iOS uses `requestAlwaysAuthorization()` directly (no blue GPS indicator)
- Business token authentication with automatic app ID detection
- Automatic Bluetooth metadata collection and periodic scanning

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  bearound_flutter_sdk: ^3.3.1
```

Run:

```bash
flutter pub get
```

## Platform Setup

### Android

Add JitPack to your root `settings.gradle` or `build.gradle`:

```gradle
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { url 'https://jitpack.io' }
    }
}
```

**You normally don't need to declare any permissions** — the SDK declares them all and the Android manifest merger injects them into your app automatically. The SDK uses the **`connectedDevice` foreground-service model** (reading data from Bluetooth devices), **not** location.

> ⚠️ If you redeclare `BLUETOOTH_SCAN` in your own manifest, you **must** keep the `neverForLocation` flag. If any declaration omits it, the flag is dropped from the merged manifest and Google treats the app as deriving location:
>
> ```xml
> <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
>     android:usesPermissionFlags="neverForLocation" tools:targetApi="s" />
> ```

For reference, the SDK declares:

```xml
<!-- Bluetooth -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" tools:targetApi="s" />

<!-- Location: legacy only — required for a BLE scan on API <= 30; not requested on API 31+ -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" android:maxSdkVersion="30" />

<!-- Foreground service: connectedDevice (BLE) on Android 14+ -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" />

<!-- Misc -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

Minimum Android SDK: 23.

### iOS

Add the following to `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>location</string>
    <string>processing</string>
    <string>bluetooth-central</string>
</array>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to detect nearby beacons.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to detect nearby beacons.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs location access to detect nearby beacons in background.</string>
```

**Important for terminated app detection:**
- `fetch` mode allows iOS to wake the app when beacons are detected
- User must grant "Always" location permission (not "When In Use")
- User must enable "Background App Refresh" in device Settings

> ℹ️ The iOS SDK uses a two-eyes model (CoreLocation + CoreBluetooth), so location **is** used on iOS by design. The `neverForLocation` strategy applies to Android only.

Minimum iOS version: 13.0.

## Foreground service & Google Play (Android)

The SDK can run an optional foreground service to keep scanning alive in the background on aggressive OEMs (Xiaomi/Huawei/Samsung). It uses the `connectedDevice` service type — reading data from external Bluetooth devices.

```dart
// Enable with a custom, location-free notification
await BearoundFlutterSdk.enableForegroundScanning(
  const ForegroundScanConfig(
    notificationTitle: 'Bearound',
    notificationText: 'Reading data from nearby Bluetooth devices',
  ),
);

// Optionally update the notification with live device data
BearoundFlutterSdk.beaconsStream.listen((beacons) {
  if (beacons.isEmpty) return;
  final temp = beacons.first.metadata?.temperature;
  BearoundFlutterSdk.setForegroundNotificationContent(
    NotificationContent(
      title: 'Bearound',
      text: 'Bluetooth devices: ${beacons.length} · ${temp ?? '--'}°C',
    ),
  );
});

// Stop the foreground service
await BearoundFlutterSdk.disableForegroundScanning();
```

> ⚠️ **Google Play requirement:** apps targeting Android 14+ that use the `connectedDevice` foreground service must declare it in Play Console and submit a **demonstration video**. Frame the feature as **reading data from external Bluetooth devices** (show the persistent notification + device data such as battery/temperature) — never as location or proximity, to stay consistent with `neverForLocation`.

## Quick Start

```dart
import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';

Future<void> setupSdk() async {
  final permissionsOk = await BearoundFlutterSdk.requestPermissions();
  if (!permissionsOk) {
    return;
  }

  await BearoundFlutterSdk.configure(
    businessToken: 'your-business-token-here',
    scanPrecision: ScanPrecision.high,           // high | medium | low (default: high)
    maxQueuedPayloads: MaxQueuedPayloads.medium, // small | medium | large | xlarge
  );
  // Note: appId is automatically extracted from the app's package/bundle identifier
  // Bluetooth metadata and periodic scanning are automatic

  // Listen to beacons
  BearoundFlutterSdk.beaconsStream.listen((beacons) {
    for (final beacon in beacons) {
      print('${beacon.major}.${beacon.minor} - RSSI ${beacon.rssi}');
    }
  });

  // Listen to sync lifecycle
  BearoundFlutterSdk.syncLifecycleStream.listen((event) {
    if (event.isStarted) {
      print('Sync started with ${event.beaconCount} beacons');
    } else if (event.isCompleted) {
      print('Sync completed: ${event.success ? "success" : "failed"}');
    }
  });

  // Listen to background detections
  BearoundFlutterSdk.backgroundDetectionStream.listen((event) {
    print('Background: ${event.beaconCount} beacons detected');
  });

  // Other streams
  BearoundFlutterSdk.scanningStream.listen((isScanning) {
    print('Scanning: $isScanning');
  });

  BearoundFlutterSdk.errorStream.listen((error) {
    print('SDK error: ${error.message}');
  });

  await BearoundFlutterSdk.startScanning();
}
```

## User Properties

```dart
await BearoundFlutterSdk.setUserProperties(
  const UserProperties(
    internalId: 'user-123',
    email: 'user@example.com',
    name: 'John Doe',
    customProperties: {'plan': 'premium'},
  ),
);
```

## Push Token

Forward the device push token (FCM on Android, APNs on iOS) to the native SDK so
the backend can target the device. The native SDK associates it with the stable
`deviceId` and sends it on the next sync.

```dart
// Android: obtain the FCM token (e.g. via firebase_messaging) and forward it.
final token = await FirebaseMessaging.instance.getToken();
if (token != null) {
  await BearoundFlutterSdk.setPushToken(token);
}
```

- **iOS:** the native SDK captures the APNs token automatically via an
  AppDelegate swizzle, so calling `setPushToken` is usually unnecessary. Call it
  only if you opted out (`BearoundAppDelegateProxyEnabled = NO` in `Info.plist`)
  and forward the token from
  `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
- **Android:** the native SDK does not yet expose a push-token setter, so
  `setPushToken` is a silent no-op there today (kept for API parity).

## API Summary

### Methods

- `configure({businessToken, scanPrecision, maxQueuedPayloads})`
- `startScanning() / stopScanning() / isScanning()`
- `enableForegroundScanning([ForegroundScanConfig]) / disableForegroundScanning() / isForegroundScanningEnabled()` — Android-only
- `setForegroundNotificationContent(NotificationContent)` — Android-only
- `setUserProperties(UserProperties) / clearUserProperties()`
- `setPushToken(String token)` — forward FCM/APNs token (iOS-only at the native layer)

### Streams

- `beaconsStream` - Detected beacons with metadata
- `syncLifecycleStream` - Sync started/completed events
- `backgroundDetectionStream` - Background beacon detections
- `scanningStream` - Scanning state changes
- `errorStream` - SDK errors

### Configuration Enums

- **ScanPrecision**: `high` (continuous scan, sync every 15s), `medium` (10s scan + 10s pause per 60s), `low` (10s scan + 50s pause per 60s)
- **MaxQueuedPayloads**: `small` (50), `medium` (100), `large` (200), `xlarge` (500)

## Migration Guide

### From 2.4.x to 3.3.x

- `foregroundScanInterval` / `backgroundScanInterval` were replaced by a single `scanPrecision` (`ScanPrecision.high/medium/low`).
- Native SDKs bumped to **3.3.1** (Android + iOS).
- Android now uses the `connectedDevice` foreground-service model with `BLUETOOTH_SCAN` (`neverForLocation`) — no background-location permission.

**Before:**
```dart
await BearoundFlutterSdk.configure(
  businessToken: 'token',
  foregroundScanInterval: ForegroundScanInterval.seconds30, // ❌ removed
  backgroundScanInterval: BackgroundScanInterval.seconds90, // ❌ removed
);
```

**After:**
```dart
await BearoundFlutterSdk.configure(
  businessToken: 'token',
  scanPrecision: ScanPrecision.high,
  maxQueuedPayloads: MaxQueuedPayloads.medium,
);
```

### From 2.1.0 to 2.2.0

**Simplified API:** Bluetooth metadata and periodic scanning are now automatic.

```dart
await BearoundFlutterSdk.configure(
  businessToken: 'token',
  // ✅ Bluetooth metadata: always enabled
  // ✅ Periodic scanning: automatic (FG: enabled, BG: continuous)
);

// Listen to sync lifecycle events
BearoundFlutterSdk.syncLifecycleStream.listen((event) {
  if (event.isStarted) print('Sync started');
  if (event.isCompleted) print('Sync completed: ${event.success}');
});

// Listen to background detections
BearoundFlutterSdk.backgroundDetectionStream.listen((event) {
  print('${event.beaconCount} beacons detected in background');
});
```

### From 1.x to 2.x

- `startScan(clientToken)` was replaced by `configure()` + `startScanning()`.
- Backup size, region events, and legacy sync success/error events were removed.
- Use `syncLifecycleStream` for sync events and `errorStream` for failures.
