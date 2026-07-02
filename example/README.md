# Bearound Flutter SDK — example app

Reference integration of `bearound_flutter_sdk` ("BeAroundScan"). It exercises the
full public API — every method and stream — and is the working reference for the
iOS background/push setup described in the [root README](../README.md).

## Run it

```bash
cd example
flutter pub get
flutter run          # pick a PHYSICAL device — BLE does not work on emulators/simulators
```

iOS: open `ios/Runner.xcworkspace` once in Xcode to set your signing team.
Push-related flows additionally require the `aps-environment` entitlement to
match the APNs environment you send from (the checked-in
`Runner.entitlements` uses `development` = APNs **sandbox**).

## Where the business token lives

`lib/main.dart`:

```dart
static const _businessToken = 'ee2ec9c46d2b2ad99bddcdd0afe224e6';
```

This is a **public test token, hardcoded on purpose** so anyone can clone and
detect the Bearound test fleet immediately. Replace it with your own business
token to send data to your workspace.

On launch the app requests permissions, calls `configure()` and
`startScanning()` automatically (`_bootstrap()` in `lib/main.dart`).

## What each part of the UI demonstrates

| UI element | SDK API demonstrated |
|---|---|
| App bar status + antenna icon | `scanningStream`, `isScanning()` |
| **Permissões** card (Localização / Bluetooth / Notificações) | `requestPermissions()`, `getBluetoothState()`, `bluetoothStateStream` — note the "any eye is enough" rule: scanning proceeds with Location **or** Bluetooth |
| **Informações do Scan** card | Active `ScanPrecision` / `MaxQueuedPayloads` passed to `configure()` |
| **Informações do Sync** card (last sync, count, duration, result) | `syncLifecycleStream` (`started`/`completed`, `success == true` handling) |
| **Debug Geofence** card (in/out of zone, recent events) | `beaconRegionStream` (enter/exit), `activeScanStream` (ranging on/off) |
| **👁 👁 Abrir Dois Olhos** modal | iOS two-eyes model: Location eye (`beaconRegionStream`, CoreLocation/iBeacon) vs Bluetooth eye (`bluetoothZoneStream`, `bluetoothScanModeStream`, CoreBluetooth) side by side, with per-eye counters and `discoverySources` per beacon |
| **Log** modal (list icon) | `getPersistedLog()` / `clearPersistedLog()` — detection history that survives app termination (iOS; empty on Android) |
| **Controle** card | `startScanning()` / `stopScanning()`; the **Foreground service** switch (Android) toggles `enableForegroundScanning()` (persistent notification, survives app-kill, requires Play video) vs the opportunistic mode; the chips re-`configure()` precision and retry-queue size live |
| Beacon cards | `beaconsStream`: major/minor, RSSI (+ averaged samples), proximity, metadata (battery mV, temperature, movements, firmware, txPower), `discoverySources`, `alreadySynced`/`isStale` flags |
| Error banner | `errorStream` (subscribed in `initState`, **before** `startScanning()`) |

## Testing background / terminated / silent push (physical device)

The iOS-specific wiring lives in `ios/Runner/AppDelegate.swift` — it is heavily
commented and mirrors the native `BeAroundScan` demo app: `registerBackgroundTasks()`,
legacy AppDelegate life cycle (the `_UIApplicationSceneManifest` rename in
`Info.plist`), background fetch, background URLSession hand-off, and the
deprecated `didReceiveRemoteNotification` override that works around
[flutter#155479](https://github.com/flutter/flutter/issues/155479).

**Background (both platforms)**
1. Start scanning, background the app (home), move a Bearound beacon in/out of range.
2. Reopen: the *Debug Geofence* card shows the enter/exit events with timestamps.
3. Android: with the *Foreground service* switch ON, detection continues with a
   persistent notification even after swiping the app away; OFF = opportunistic
   PendingIntent scans (OS-throttled).

**Terminated app relaunch (iOS)**
1. Grant Location **Always** and enable Background App Refresh.
2. Swipe-kill the app, leave beacon range (or power the beacon off) for a few
   minutes, then re-enter range.
3. iOS relaunches the app in background; the AppDelegate detects the
   `location`/`bluetoothCentrals` launch keys and posts the local notification
   **"App Reativado"**.

**Silent push → scan (iOS)**
1. With the app in background (suspended — *not* force-quit: Apple never wakes a
   force-quit app via silent push), have the backend send a Bearound silent push
   (`content-available: 1` + `bearound` key) to the device's APNs token.
2. The AppDelegate forwards it to `performBackgroundBLERefreshAndSync`; on
   completion the plugin posts the local notification **"Push → Scan ✅"** with
   the beacon/sync counts.
3. The APNs token is printed on launch (`[Runner] APNs token: ...`) — filter
   Console.app/Xcode logs by `[Runner]` to grab it. The push must be sent to the
   **sandbox** APNs environment when running a development build.
4. Region, sync and background-detection events are recorded by the native SDK
   in the persisted detection log — open the **Log** modal after reopening the
   app to verify what happened while it was closed.
