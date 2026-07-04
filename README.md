# 🐻 Bearound Flutter SDK

Official Flutter plugin for the Bearound native SDKs (Android/iOS) version 3.4.2.

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
  bearound_flutter_sdk: ^3.4.3
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
    <string>remote-notification</string>
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

#### Push notifications & background wakeup

The backend can trigger a background BLE scan via **silent push**, and iOS relaunches a closed
app when it enters a beacon region. On **Flutter 3.41+** this requires three extra steps in
**your app target** — the `example/` app is the working reference; copy from `example/ios/Runner/`.

**1. Push entitlement** — create `ios/Runner/Runner.entitlements`:

```xml
<key>aps-environment</key>
<string>development</string> <!-- or "production" -->
```

Reference it in the Runner build settings (all configs): `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;`

**2. Disable the UIScene** — in `ios/Runner/Info.plist`, **rename** `UIApplicationSceneManifest`
to `_UIApplicationSceneManifest` (keep the `_` prefix — do **not** delete the block, Flutter's
migrator re-injects it every build). This drops the app back to the legacy AppDelegate life cycle,
which is what makes silent-push and beacon wakeup work. Keep `UIMainStoryboardFile` and
`UILaunchStoryboardName` as-is (removing them causes a black screen).

**3. AppDelegate** — legacy mode + forward the silent push to the SDK. Full file:
[`example/ios/Runner/AppDelegate.swift`](example/ios/Runner/AppDelegate.swift). Key points:

- `class AppDelegate: FlutterAppDelegate` (**no** `FlutterImplicitEngineDelegate`) + `GeneratedPluginRegistrant.register(with: self)`
- override the **deprecated** `application(_:didReceiveRemoteNotification:)` (without `fetchCompletionHandler`) and call `BeAroundSDK.shared.performBackgroundBLERefreshAndSync(...)` — the modern variant is not delivered on Flutter ([flutter#155479](https://github.com/flutter/flutter/issues/155479))
- `requestAuthorization(...)` + set `UNUserNotificationCenter.current().delegate = self`

> **iOS rules that are NOT bugs:**
> - **Silent push never wakes a force-quit app** (Apple rule) — a closed app is relaunched by
>   **beacon/region wakeup**, and only then processes the backend's silent pushes.
> - **Environment must match:** `development` entitlement ⇄ APNs **sandbox**; `production` ⇄ APNs
>   **production**. Wrong environment → APNs returns `sent` but the device never gets it (`BadDeviceToken`).
> - Requires **Background App Refresh** ON on the device.

Minimum iOS version: 13.0.

## Scan modes (Android)

> On **iOS** scanning is always system-managed (region monitoring + `BGTaskScheduler`). These modes are **Android-only**.

The SDK ships **two background-scan strategies**, and **you pick per app** — right at `startScanning()`, with no native changes. Both already exist in the native SDK; you're just choosing which one to turn on.

### At a glance — what you gain

| | 🪶 Opportunistic *(default)* | 🛡️ Foreground service |
|---|---|---|
| **Best for** | casual presence, battery-first apps | real-time footfall, mission-critical presence |
| **You gain** | zero setup · **no Play video** · lowest battery | reliable detection that **survives app-kill & aggressive OEMs** |
| **You accept** | unpredictable latency · misses in deep background | persistent notification + Play demo video |

### Quick pick

- Can't (or won't) submit a Play demo video, and occasional detection is fine → **🪶 Opportunistic**
- Need real-time presence that survives the app being killed on Xiaomi/Huawei/Samsung → **🛡️ Foreground service**
- In between → Foreground service if you can submit the video; otherwise Opportunistic

### Mode 1 — Opportunistic (no foreground service) · *default*

**What you gain:** no `FOREGROUND_SERVICE_CONNECTED_DEVICE` permission, **no Play demonstration video**, and the lowest battery footprint.

```dart
await BearoundFlutterSdk.startScanning();
```

The OS delivers beacons through a `PendingIntent` scan (`BluetoothScanReceiver`), re-armed by `AlarmManager` (`ScanWatchdogReceiver`) — it keeps working with the app **killed**, but the system decides *when* (opportunistic, throttled).

To fully drop the Play video, also remove the FGS permission the native SDK injects via manifest merge:

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE"
    tools:node="remove" />
```

### Mode 2 — Foreground service (`connectedDevice`)

**What you gain:** continuous, low-latency detection that **survives app-kill and aggressive OEMs** (Xiaomi/Huawei/Samsung) — the reliable path for footfall/presence analytics.

```dart
// By default the notification shows the host app's own name (localized by the
// device) + a generic, localized subtitle ("Atualizando conteúdo" / "Updating
// content") — nothing about Bluetooth or reading data. Just enable it:
await BearoundFlutterSdk.startScanning(
  foregroundScanConfig: const ForegroundScanConfig(),
);

// Want a custom title/subtitle instead? Pass them explicitly:
// await BearoundFlutterSdk.startScanning(
//   foregroundScanConfig: const ForegroundScanConfig(
//     notificationTitle: 'My App', notificationText: 'Bluetooth active',
//   ),
// );

await BearoundFlutterSdk.disableForegroundScanning(); // stop the service
```

> ⚠️ **Google Play:** the `connectedDevice` foreground service requires a Play Console declaration + **demonstration video**. In the **video/declaration**, frame the feature as *reading data from external Bluetooth devices* — never as location or proximity (stays consistent with `neverForLocation`). The persistent notification itself just shows the app name, which is enough to satisfy the perceptibility requirement.

### Trade-off

| | 🪶 Opportunistic | 🛡️ Foreground service |
|---|---|---|
| App in foreground | continuous | continuous |
| App in background | opportunistic, throttled | continuous |
| App killed / swiped away | relaunched by OS (PendingIntent) | process kept alive |
| Aggressive OEM (Xiaomi/Huawei) | ❌ killed | ✅ survives |
| Detection latency | unpredictable (s → min) | low (per `ScanPrecision`) |
| Presence accuracy | low / medium | **high** |
| Battery | lower | higher |
| Persistent notification | none | yes (mandatory) |
| Extra permission | none | `FOREGROUND_SERVICE_CONNECTED_DEVICE` |
| **Google Play video** | ❌ not required | ✅ required |

### Scan windows (detection cadence)

`ScanPrecision` governs the duty cycle **while the scan is active** (foreground or FGS):

| Strategy | Typical detection window | Predictable? | Battery |
|---|---|---|---|
| FGS + `ScanPrecision.high` | ~1–5 s, continuous | yes | high |
| FGS + `ScanPrecision.medium` | ~10–20 s (10 s scan + 10 s pause ×3 / 60 s) | yes | medium |
| FGS + `ScanPrecision.low` | ~60 s (10 s scan + 50 s pause / 60 s) | yes | low |
| Opportunistic (no FGS) | seconds → several minutes (OS-decided) | no | low |
| WorkManager (client-side, external) | ≥ 15 min (WorkManager minimum) | yes | very low |

> Windows are approximate, derived from the `ScanPrecision` duty cycle. In **opportunistic** mode `ScanPrecision` only governs cadence while the app is in the foreground; in the background the OS throttles the `PendingIntent` scan.

### Advanced: WorkManager (client-side)

The SDK does **not** bundle WorkManager. For a predictable low-frequency sweep without a foreground service, schedule your own `PeriodicWorkRequest` (minimum interval **15 min**) that calls `startScanning()` for a short window and then `stopScanning()`. This trades latency for battery and avoids the Play video — presence lags by up to the chosen period.

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
- `setErrorReportingEnabled(bool)` — opt out of Dart-layer error telemetry (default: on)

### Streams

- `beaconsStream` - Detected beacons with metadata
- `syncLifecycleStream` - Sync started/completed events
- `backgroundDetectionStream` - Background beacon detections
- `scanningStream` - Scanning state changes
- `errorStream` - SDK errors

### Configuration Enums

- **ScanPrecision**: `high` (continuous scan, sync every 15s), `medium` (10s scan + 10s pause per 60s), `low` (10s scan + 50s pause per 60s)
- **MaxQueuedPayloads**: `small` (50), `medium` (100), `large` (200), `xlarge` (500)

## Error telemetry

The SDK ships lightweight, isolated crash telemetry so we can spot and fix
integration issues quickly. It works on two layers:

- **Native (Android/iOS):** the embedded native SDKs already capture native
  crashes via their own `ErrorReporter`s. Nothing to configure.
- **Dart (this plugin):** installed automatically on `configure()`, it chains
  `FlutterError.onError` and `PlatformDispatcher.onError` and reports **only**
  uncaught errors whose stack trace contains a `package:bearound_flutter_sdk`
  frame. Errors from your app or third-party packages are never touched.

It is designed to be invisible and safe:

- **Never breaks your app.** The global handlers are always chained — the
  previous `FlutterError.onError` is kept and still invoked, and
  `PlatformDispatcher.onError` returns `false` so the platform still sees the
  error. Nothing is swallowed or hijacked.
- **Fire-and-forget** delivery to `POST https://ingest.bearound.io/sdk-errors`
  with short (5 s) timeouts, an in-memory rate limit (20/h) and 5-minute dedupe.
  Uses `dart:io HttpClient` — no extra dependency.
- **Minimal payload:** error type/message/stack (capped at 8000 chars), a
  permission snapshot (Bluetooth/location/notifications, read without
  prompting), the platform, and a UTC timestamp. No PII.

Opt out at any time (default is on):

```dart
BearoundFlutterSdk.setErrorReportingEnabled(false);
```

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
