# 🐻 Bearound Flutter SDK

Official Flutter plugin for the Bearound native SDKs (Android/iOS) version 2.0.0.

## Features

- Native beacon scanning on Android and iOS.
- Real-time beacon stream with metadata (battery, firmware, temperature).
- Sync status updates (next sync countdown + ranging state).
- Scanning state and error streams.
- User properties support for enriched beacon events.
- Permission helper for location/Bluetooth setup.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  bearound_flutter_sdk: ^2.0.0
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
    <string>bluetooth-central</string>
    <string>location</string>
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
    syncInterval: const Duration(seconds: 30),
    enableBluetoothScanning: true,
    enablePeriodicScanning: true,
  );

  // appId is optional; defaults to the bundle identifier / package name.

  BearoundFlutterSdk.beaconsStream.listen((beacons) {
    for (final beacon in beacons) {
      print('${beacon.major}.${beacon.minor} - RSSI ${beacon.rssi}');
    }
  });

  BearoundFlutterSdk.syncStream.listen((status) {
    print('Next sync in ${status.secondsUntilNextSync}s');
  });

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

- `configure({appId, syncInterval, enableBluetoothScanning, enablePeriodicScanning})`
- `startScanning() / stopScanning() / isScanning()`
- `setBluetoothScanning(bool enabled)`
- `setUserProperties(UserProperties) / clearUserProperties()`
- Streams: `beaconsStream`, `syncStream`, `scanningStream`, `errorStream`

## Migration from 1.x

- `startScan(clientToken)` was replaced by `configure()` + `startScanning()`.
- Backup size, region events, and legacy sync success/error events were removed.
- Use `syncStream` for countdown/ranging status and `errorStream` for failures.
