# 🐻 Bearound Flutter SDK

Official Flutter plugin for the Bearound native SDKs (Android/iOS) version 2.3.6.

## Features

- Native beacon scanning on Android and iOS
- Real-time beacon stream with metadata (battery, firmware, temperature)
- Sync lifecycle events (sync started/completed callbacks)
- Background detection events (beacons detected in background)
- Scanning state and error streams
- User properties support for enriched beacon events
- **Native permission handling** - iOS uses `requestAlwaysAuthorization()` directly (no blue GPS indicator)
- Business token authentication with automatic app ID detection
- Automatic Bluetooth metadata collection and periodic scanning

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  bearound_flutter_sdk: ^2.3.6
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

Required permissions:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="com.google.android.gms.permission.AD_ID" />
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
<key>NSUserTrackingUsageDescription</key>
<string>This app uses tracking permission for beacon detection.</string>
```

**Important for terminated app detection:**
- `fetch` mode allows iOS to wake the app when beacons are detected
- User must grant "Always" location permission (not "When In Use")
- User must enable "Background App Refresh" in device Settings

Minimum iOS version: 13.0.

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
    foregroundScanInterval: ForegroundScanInterval.seconds15,  // Default: 15s
    backgroundScanInterval: BackgroundScanInterval.seconds30,  // Default: 30s
    maxQueuedPayloads: MaxQueuedPayloads.medium,               // Default: 100
  );
  // Note: appId is automatically extracted from the app's package/bundle identifier
  // Bluetooth metadata and periodic scanning are automatic in v2.2.0

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

## API Summary

### Methods

- `configure({businessToken, foregroundScanInterval, backgroundScanInterval, maxQueuedPayloads})`
- `startScanning() / stopScanning() / isScanning()`
- `setUserProperties(UserProperties) / clearUserProperties()`

### Streams

- `beaconsStream` - Detected beacons with metadata
- `syncLifecycleStream` - Sync started/completed events
- `backgroundDetectionStream` - Background beacon detections
- `scanningStream` - Scanning state changes
- `errorStream` - SDK errors

### Configuration Enums

- **ForegroundScanInterval**: `seconds5` to `seconds60` (5-second increments)
- **BackgroundScanInterval**: `seconds15`, `seconds30`, `seconds60`, `seconds90`, `seconds120`
- **MaxQueuedPayloads**: `small` (50), `medium` (100), `large` (200), `xlarge` (500)

## Migration Guide

### From 2.1.0 to 2.2.0

**Simplified API:** Bluetooth metadata and periodic scanning are now automatic.

**Before (v2.1.0):**
```dart
await BearoundFlutterSdk.configure(
  businessToken: 'token',
  enableBluetoothScanning: true,  // ❌ Removed
  enablePeriodicScanning: true,   // ❌ Removed
);
```

**After (v2.2.0):**
```dart
await BearoundFlutterSdk.configure(
  businessToken: 'token',
  // ✅ Bluetooth metadata: always enabled
  // ✅ Periodic scanning: automatic (FG: enabled, BG: continuous)
);

// NEW: Listen to sync lifecycle events
BearoundFlutterSdk.syncLifecycleStream.listen((event) {
  if (event.isStarted) print('Sync started');
  if (event.isCompleted) print('Sync completed: ${event.success}');
});

// NEW: Listen to background detections
BearoundFlutterSdk.backgroundDetectionStream.listen((event) {
  print('${event.beaconCount} beacons detected in background');
});
```

**Native SDK Updates:**
- Android: `v2.3.6`
- iOS: `v2.3.6`

### From 2.0.1 to 2.1.0

**Breaking Change:** `syncInterval` parameter replaced with separate foreground/background intervals.

**Before (v2.0.1):**
```dart
await BearoundFlutterSdk.configure(
  businessToken: 'token',
  syncInterval: const Duration(seconds: 30),
);
```

**After (v2.1.0):**
```dart
await BearoundFlutterSdk.configure(
  businessToken: 'token',
  foregroundScanInterval: ForegroundScanInterval.seconds30,
  backgroundScanInterval: BackgroundScanInterval.seconds90,
  maxQueuedPayloads: MaxQueuedPayloads.large,
);
```

### From 1.x to 2.x

- `startScan(clientToken)` was replaced by `configure()` + `startScanning()`.
- Backup size, region events, and legacy sync success/error events were removed.
- Use `syncLifecycleStream` for sync events and `errorStream` for failures.
