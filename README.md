# 🐻 Bearound Flutter SDK

Official Flutter plugin for the Bearound native SDKs — Android **3.4.5** · iOS **3.4.5**.

> [!TIP]
> **⚡ Set it up with an AI agent.** Don't wire the iOS/Android background integration by hand — hand [one prompt](./AI-AGENT-SETUP.md) to your AI coding agent (Claude Code, Cursor, Copilot) and let it pilot the whole install, pausing only for the few human-only steps. → [Set up with an AI agent](#set-up-with-an-ai-agent)

[![Agent setup prompt](https://img.shields.io/badge/Agent_setup_prompt-open_%26_copy-2563eb?style=for-the-badge)](./AI-AGENT-SETUP.md)

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
  bearound_flutter_sdk: ^3.4.5
```

Run:

```bash
flutter pub get
```

## Set up with an AI agent

Instead of wiring the intricate iOS/Android background setup by hand, hand it to an **AI coding agent** (Claude Code, Cursor, Copilot, …). This README is written to be **agent-readable** — the agent reads it and does the whole integration. There's one ready-made prompt to give it:

[![Agent setup prompt](https://img.shields.io/badge/Agent_setup_prompt-open_%26_copy-2563eb?style=for-the-badge)](./AI-AGENT-SETUP.md)

Open [`AI-AGENT-SETUP.md`](./AI-AGENT-SETUP.md) and click the **copy icon** on its code block — GitHub shows one on every code block, and it drops the prompt on your clipboard. Then paste it into your agent with your app's repo open. Web-capable agents can fetch its [raw URL](https://raw.githubusercontent.com/Bearound/bearound-flutter-sdk/main/AI-AGENT-SETUP.md) directly.

**The agent will pause for these human-only steps** — they need your Apple/Google accounts and a physical device, so no SDK or agent can do them:

- **Xcode → Push Notifications capability** on your app target, signed with **your** push-enabled App ID / provisioning profile — the `aps-environment` entitlement the SDK's silent-push wake vector depends on. See [Push notifications & background wakeup](#push-notifications--background-wakeup).
- **On device:** grant **Always** location and turn on **Background App Refresh**.
- **Google Play:** the `connectedDevice` foreground-service declaration + demonstration video required at review (only if you enable the foreground service). See [Scan modes](#scan-modes-android).

Prefer to wire it by hand? Everything the prompt references is spelled out in the sections below.

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

For reference, the manifest merge injects the following into your app (this is the
plugin's actual manifest — `android/src/main/AndroidManifest.xml`):

```xml
<!-- Bluetooth (Android 11 and below) -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />

<!-- Bluetooth (Android 12+) -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" tools:targetApi="s" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

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

<!-- Advertising ID -->
<uses-permission android:name="com.google.android.gms.permission.AD_ID" />

<!-- Hardware features -->
<uses-feature android:name="android.hardware.bluetooth" android:required="true" />
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />
```

#### What the manifest merge means for your Play Store listing

Know these **before** submitting to Google Play — they are discovered at review
time otherwise:

- **`AD_ID`** — your Play Console **Data Safety form** must declare that the app
  collects the Advertising ID. Apps in the **Families / Designed for Families**
  program are **not allowed** to carry this permission at all — if that's your
  case, talk to Bearound before integrating.
- **`uses-feature android.hardware.bluetooth_le required="true"`** — the Play
  Store **filters your app out of devices without BLE**. Usually desirable for a
  beacon product, but be aware your listing's device reach shrinks.
- **`FOREGROUND_SERVICE_CONNECTED_DEVICE`** — its presence in the merged
  manifest triggers a Play Console **foreground-service declaration + demo
  video** for apps targeting SDK 34+. The service itself only runs if you opt in
  via `foregroundScanConfig` / `enableForegroundScanning()`; if you stay on the
  opportunistic mode, remove the permission with `tools:node="remove"` (snippet
  in [Scan modes](#scan-modes-android)) and no declaration/video is needed.
- **`POST_NOTIFICATIONS`** — declared by the SDK, but on Android 13+ you still
  need the runtime grant for the foreground-service notification to be visible
  (`requestPermissions()` already asks for it).

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
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>io.bearound.sdk.sync</string>
    <string>io.bearound.sdk.processing</string>
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

#### Disable UIScene (Flutter 3.41+) — required

**Why this section exists.** The SDK's background stack was built and validated against a
native iOS app: suspended or even terminated, the app wakes on beacon-region entry or on a
silent push, scans for ~10s and syncs — that's the product. When the same SDK ran inside a
Flutter host, **everything worked in foreground and nothing woke in background** — same SDK
version, same `Info.plist` keys, same entitlements. We diffed the two apps line by line until
a single difference was left: the app life cycle. Flutter 3.41+ silently migrates apps to the
**UISceneDelegate** life cycle, and under UIScene two things kill every wakeup path:

- `launchOptions` arrives `nil` in `didFinishLaunching` (the `bluetoothCentrals` / `location`
  relaunch keys move to the SceneDelegate, which the native SDK doesn't see), and
- plugins/handlers are registered **after** `didFinishLaunching` returns, violating Apple's rule
  that launch handlers must exist before launch ends — so CoreBluetooth state restoration,
  region relaunch and silent push are silently dropped ([flutter#184267](https://github.com/flutter/flutter/issues/184267)).

In other words: iOS **does** relaunch the app to hand it a beacon event — but under UIScene the
app isn't listening yet, so the event evaporates. No error, no log, just "background detection
doesn't work".

The fix is to **induce Flutter back to the legacy AppDelegate life cycle** — the one every
native SDK (and Apple's own background contract) was designed around. The trick is the `_`
rename below: iOS ignores the unknown `_UIApplicationSceneManifest` key (Scene off, legacy cycle
on), while Flutter's migrator — which re-injects the block whenever the substring
`UIApplicationSceneManifest` disappears from the plist — still finds the substring and leaves
the project alone. One rename, both systems satisfied.

**Does it work?** Yes — validated on real devices, on the reference `example/` app and on a
production fleet app (car.media): with the app suspended *and* with it terminated, a beacon
region entry or a backend silent push wakes the process, the 10s BLE scan finds the beacons and
the sync lands in the ingest backend seconds later. Foreground behavior, UI and the rest of the
Flutter app are untouched — the legacy cycle is simply the stable, documented path iOS has
supported since day one.

Every integrating app must apply it:

1. In `ios/Runner/Info.plist`, **rename** `UIApplicationSceneManifest` to
   `_UIApplicationSceneManifest`. Keep the `_` prefix — do **not** delete the block: Flutter's
   migrator re-injects it on every build if the substring `UIApplicationSceneManifest`
   disappears; the `_` prefix keeps it inert (iOS ignores unknown keys) and the migrator skips.
   Keep `UIMainStoryboardFile` and `UILaunchStoryboardName` as-is (removing them causes a
   black screen).
2. In `ios/Runner/AppDelegate.swift`, use `class AppDelegate: FlutterAppDelegate` (**no**
   `FlutterImplicitEngineDelegate` / `didInitializeImplicitFlutterEngine`) and call
   `GeneratedPluginRegistrant.register(with: self)` inside `didFinishLaunching` — see the full
   AppDelegate in the next section.
3. If your project has a `SceneDelegate.swift`, it becomes dead code — you can delete it (and
   its `project.pbxproj` references).

The `example/` app ships this configuration and is the working reference.

#### Background tasks (BGTaskScheduler) — required

Without this wiring the SDK still works in foreground, but it **silently
degrades** in background: the SDK's BGTasks (periodic sync + processing) never
run and terminated-state uploads never finalize.

The SDK schedules two BGTasks — `io.bearound.sdk.sync` (app refresh) and
`io.bearound.sdk.processing` (longer execution). Both identifiers must be listed
in `BGTaskSchedulerPermittedIdentifiers` (snippet above), and the app must call
`registerBackgroundTasks()` **before the app finishes launching** — i.e. in your
`AppDelegate`, not from Dart. Wire it in `ios/Runner/AppDelegate.swift` (the
`example/` app is the working reference; this assumes UIScene is disabled per the
section above — under UIScene there is no legacy `didFinishLaunching` wiring):

This is the **complete** `AppDelegate` — it is `example/ios/Runner/AppDelegate.swift` verbatim (the working reference), and it covers **both** the BGTask wiring **and** the silent-push handlers described in the next section. Copy it whole; every method is load-bearing. In particular, `patchFlutterProMotionCrash()` is **required**: disabling UIScene (above) re-enters an iOS-26 ProMotion code path that crashes the host on iPhone 15 Pro and newer — this workaround neutralizes it.

```swift
import Flutter
import UIKit
import BearoundSDK
import ObjectiveC
import UserNotifications

// Flutter 3.44.x crashes on iOS 26 when it creates the ProMotion touch-rate
// VSync client (the task runner is nil in viewDidLoad). Swizzle it to a no-op
// (cost: no touch-rate correction on ProMotion screens). REQUIRED once UIScene is
// disabled — the legacy storyboard path (which creates the FlutterViewController)
// re-enters this crashing code path.
private func patchFlutterProMotionCrash() {
  guard #available(iOS 26, *) else { return }
  let sel = NSSelectorFromString("createTouchRateCorrectionVSyncClientIfNeeded")
  guard let method = class_getInstanceMethod(FlutterViewController.self, sel) else { return }
  let noop: @convention(block) (AnyObject) -> Void = { _ in }
  method_setImplementation(method, imp_implementationWithBlock(noop))
}

// UIScene disabled (see _UIApplicationSceneManifest in Info.plist): back to the
// legacy AppDelegate lifecycle so UIApplicationDelegate background events (silent
// push wakeup, region/BLE state restoration, background fetch) are delivered
// again — exactly like the native app. Classic plugin registration via
// GeneratedPluginRegistrant.register(with: self); no FlutterImplicitEngineDelegate.
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    patchFlutterProMotionCrash()
    GeneratedPluginRegistrant.register(with: self)

    // Register the SDK's BGTasks BEFORE the app finishes launching.
    BeAroundSDK.shared.registerBackgroundTasks()
    // Silent push: register with APNs so the backend can wake the app in the
    // background. (The SDK also auto-captures the token via swizzle; this is
    // idempotent and mirrors the native AppDelegate.)
    application.registerForRemoteNotifications()

    // App relaunched in the background by a region/Bluetooth event while the app
    // was KILLED (state restoration) — mirrors the native "App Reactivated" flow.
    if launchOptions?[.location] != nil {
      NSLog("[Runner] Relaunched by LOCATION (region entry)")
      Self.notifyAppRelaunched()
    }
    if launchOptions?[.bluetoothCentrals] != nil {
      NSLog("[Runner] Relaunched by BLUETOOTH (state restoration)")
      Self.notifyAppRelaunched()
    }

    // Notifications: authorization + delegate so banners show in the foreground
    // (willPresent). Bearound silent pushes are handled by the override below.
    // If another plugin (firebase_messaging / flutter_local_notifications) already
    // owns the notification-center delegate, do NOT set it here — inject the
    // willPresent / didReceiveRemoteNotification logic into that owner instead.
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      NSLog("[Runner] Notif auth granted=%d error=%@", granted ? 1 : 0, error?.localizedDescription ?? "nil")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Background relaunch notification — a visible signal that the app woke up.
  private static func notifyAppRelaunched() {
    let content = UNMutableNotificationContent()
    content.title = "App Reactivated"
    content.body = "BeAroundSDK detected a beacon region in the background"
    content.sound = .default
    UNUserNotificationCenter.current().add(
      UNNotificationRequest(
        identifier: "bearound.relaunch.\(Int(Date().timeIntervalSince1970))",
        content: content,
        trigger: nil
      )
    )
  }

  // Background fetch — iOS periodically wakes the app for a refresh.
  override func application(
    _ application: UIApplication,
    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    BeAroundSDK.shared.performBackgroundFetch { success in
      completionHandler(success ? .newData : .noData)
    }
  }

  // Background URLSession — iOS relaunches the app to deliver completed
  // beacon-upload transfers so terminated-state uploads are finalized.
  override func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    BeAroundSDK.shared.handleBackgroundURLSessionEvents(
      identifier: identifier,
      completionHandler: completionHandler
    )
  }

  // APNs token: the SDK auto-captures it via swizzle; kept only to log it.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    NSLog("[Runner] APNs token: %@", token)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[Runner] APNs register FAILED: %@", error.localizedDescription)
  }

  // Silent-push wakeup — the DEPRECATED variant (no fetchCompletionHandler).
  // FlutterAppDelegate does NOT implement the modern
  // application(_:didReceiveRemoteNotification:fetchCompletionHandler:) as a real
  // method (dynamic forwarding via kSelectorsHandledByPlugins), so iOS drops the
  // silent push and never wakes a suspended app (flutter#155479 / #52895). The
  // deprecated variant below is NOT in Flutter's hijack list, so it reaches the app
  // and wakes it. We call the SDK's background-scan flow directly (what the native
  // app gets via swizzle, which does not work on Flutter). Guard on
  // userInfo["bearound"] so other providers' pushes pass through untouched.
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any]
  ) {
    guard userInfo["bearound"] != nil else { return }
    NSLog("[Runner] Bearound silent push received (deprecated variant) — scan + sync")
    BeAroundSDK.shared.performBackgroundBLERefreshAndSync(
      bleScanDuration: 10.0, trigger: "silent_push"
    ) { ingestStarted in
      let info = BeAroundSDK.shared.lastBackgroundScanInfo
      let found = info?.beaconsFound ?? 0
      let pending = info?.pendingBatches ?? 0
      NSLog("[Runner] Silent push handled: beacons=%d ingest=%d pending=%d",
            found, ingestStarted ? 1 : 0, pending)
      DispatchQueue.main.async {
        BeAroundSDK.shared.delegate?.didCompletePushScan(
          beaconsFound: found, ingestStarted: ingestStarted, pendingBatches: pending
        )
      }
    }
  }

  // Show the banner even in the foreground (normal/alert push).
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }
}
```

> Without the `BGTaskSchedulerPermittedIdentifiers` entries,
> `registerBackgroundTasks()` cannot register the SDK's BGTasks and iOS will
> never grant them execution time.

#### Push notifications & background wakeup

The backend can trigger a background BLE scan via **silent push**, and iOS relaunches a closed
app when it enters a beacon region. On top of the required setup above (UIScene disabled +
legacy AppDelegate), this needs two extra steps in **your app target**. The complete
`AppDelegate` shown above already includes the silent-push handlers; the entitlement below is
the remaining piece.

**1. Push entitlement** — create `ios/Runner/Runner.entitlements`:

```xml
<key>aps-environment</key>
<string>production</string>
```

Reference it in the Runner build settings (all configs): `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;`

Ship `production` — that's what TestFlight/App Store builds (your real fleet) use. Dev-signed
builds (`flutter run`, Xcode run) are automatically re-signed with `development`, so the same
file covers both. What you MUST match is the **backend credential environment** to the build
you're testing: a `development`-signed build registers a **sandbox** APNs token, a store build
registers a **production** one. Cross them and APNs replies `200` but the device never gets the
push (`BadDeviceToken`) — the most common "push doesn't arrive" cause.

**2. AppDelegate** — the **complete `AppDelegate` shown above** already forwards the silent push to the SDK. Key points to understand:

- `application.registerForRemoteNotifications()` in `didFinishLaunching` (idempotent if another
  push SDK — e.g. Firebase — already registers)
- override the **deprecated** `application(_:didReceiveRemoteNotification:)` (without `fetchCompletionHandler`) and call `BeAroundSDK.shared.performBackgroundBLERefreshAndSync(...)` — the modern variant is not delivered on Flutter ([flutter#155479](https://github.com/flutter/flutter/issues/155479)). Guard on `userInfo["bearound"] != nil` so other providers' pushes pass through untouched.
- `requestAuthorization(...)` + set `UNUserNotificationCenter.current().delegate = self` — only
  if no other plugin (e.g. `firebase_messaging`) already owns the notification-center delegate;
  silent pushes don't need user-visible notification permission.

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

## Background reliability (Android)

Doze and OEM battery managers (Xiaomi/Huawei/Oppo/Vivo/OnePlus…) are the #1
cause of "it stopped detecting in background" on Android — they kill or freeze
the process regardless of scan mode. Since **3.4.5** the plugin exposes the
native helpers that mitigate both:

| Method | What it does |
|---|---|
| `isIgnoringBatteryOptimizations()` | `true` if the app is already exempt from battery optimization (Doze). |
| `openBatteryOptimizationSettings()` | Opens the battery-optimization Settings screen so the user can exempt the app. Uses the Settings screen — **not** the restricted `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission — so it has no Google Play review impact. Returns `true` if the screen opened. |
| `isAutostartManageable()` | `true` if the device is from an OEM with a known autostart/protected-apps screen (Xiaomi/Huawei/Oppo/Vivo/OnePlus/Letv). `false` on stock Android (Pixel). |
| `openManufacturerAutostartSettings()` | Opens the manufacturer's autostart/protected-apps screen when one exists. Returns `true` if the screen opened. |

Recommended flow — **check → explain → open Settings**. Never deep-link the user
to a Settings screen without telling them why first:

```dart
Future<void> ensureBackgroundReliability() async {
  // 1. Doze exemption.
  if (!await BearoundFlutterSdk.isIgnoringBatteryOptimizations()) {
    // Show your own rationale dialog first ("we need this to keep detecting
    // nearby devices in background"), then:
    await BearoundFlutterSdk.openBatteryOptimizationSettings();
  }

  // 2. OEM autostart / protected apps (Xiaomi, Huawei, ...).
  if (await BearoundFlutterSdk.isAutostartManageable()) {
    // Rationale dialog, then:
    await BearoundFlutterSdk.openManufacturerAutostartSettings();
  }
}
```

> **iOS:** all four methods are safe to call unconditionally — there is no
> equivalent restriction, so `isIgnoringBatteryOptimizations()` resolves `true`
> and the other three are no-ops resolving `false`.

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
      // `success` is a bool? (null on 'started' events) — compare explicitly.
      print('Sync completed: ${event.success == true ? "success" : "failed"}');
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

Forward the device push token to the native SDK so the backend can target the
device (silent-push wake-up). The native SDK associates it with the stable
`deviceId` and registers it with the backend — immediately if scanning is
already active, otherwise on the next sync.

**Call `setPushToken` explicitly on both platforms:**

- **Android** (plugin ≥ 3.4.1): pass the **FCM token**. The bridge forwards it
  to the native SDK (`BeAroundSDK.setPushToken`, available since native Android
  3.4.0).
- **iOS:** pass the **raw APNs token** — the backend delivers pushes through
  APNs, so the FCM token does **not** work here. The SDK does try to capture the
  APNs token automatically via an AppDelegate swizzle, but that capture **fails
  when Firebase is present** (Firebase intercepts the swizzle — the most common
  setup), and the token silently ends up NULL in the backend. Forwarding the raw
  token explicitly works in every setup, and the call is idempotent.

```dart
import 'dart:io' show Platform;

if (Platform.isAndroid) {
  // Android: FCM token (e.g. via firebase_messaging).
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) await BearoundFlutterSdk.setPushToken(token);
} else if (Platform.isIOS) {
  // iOS: RAW APNs token — NOT the FCM token.
  final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
  if (apnsToken != null) await BearoundFlutterSdk.setPushToken(apnsToken);
}
```

> If you opted out of the SDK's AppDelegate swizzle
> (`BearoundAppDelegateProxyEnabled = NO` in `Info.plist`), calling
> `setPushToken` on iOS is not just recommended — it's the only way the token
> reaches the backend.

## API Summary

Full cross-platform event/field parity matrix: [EVENT-PARITY.md](EVENT-PARITY.md).

### Methods

| Method | Platform | Notes |
|---|---|---|
| `configure({businessToken, scanPrecision, maxQueuedPayloads})` | Android + iOS | Required before `startScanning()`. Defaults: `ScanPrecision.high`, `MaxQueuedPayloads.medium`. |
| `startScanning({foregroundScanConfig})` | Android + iOS | `foregroundScanConfig` is Android-only (ignored on iOS). |
| `stopScanning()` | Android + iOS | |
| `isScanning()` | Android + iOS | |
| `requestPermissions()` | Android + iOS | iOS: native `requestAlwaysAuthorization()`; Android: runtime permissions via `permission_handler` (incl. notifications on 13+). |
| `checkPermissions()` | Android + iOS | |
| `requestLocationAuthorization({level})` | iOS | Unlocks the Location eye (terminated-app wake-up requires `always`). No-op on Android. |
| `isIgnoringBatteryOptimizations()` | Android | iOS always resolves `true` (no equivalent restriction). |
| `openBatteryOptimizationSettings()` | Android | iOS: no-op, resolves `false`. |
| `isAutostartManageable()` | Android | `false` on stock Android and iOS. |
| `openManufacturerAutostartSettings()` | Android | iOS/stock: no-op, resolves `false`. |
| `setUserProperties(UserProperties)` | Android + iOS | |
| `clearUserProperties()` | Android + iOS | |
| `setPushToken(String)` | Android + iOS | FCM token on Android, **raw APNs token** on iOS — see [Push Token](#push-token). |
| `getSdkVersion()` | Android + iOS | Android returns `BuildConfig.SDK_VERSION` (injected at build time); `''` only if the native layer is unavailable. |
| `getCurrentScanPrecision()` | Android + iOS | `''` before `configure()`. |
| `getBleDiagnosticInfo()` | iOS | Android returns `''`. |
| `getPendingBatchCount()` | Android + iOS | Batches queued for retry after API failures. |
| `isConfigured()` | Android + iOS | iOS: tracked by the bridge — may read `false` after an auto-restored background relaunch even while `isScanning()` is `true`. |
| `isLocationAvailable()` | Android + iOS | Device location services on/off. |
| `getAuthorizationStatus()` | Android + iOS | iOS: mirrors `CLAuthorizationStatus`. Android: derived from *location* permissions only — it does **not** reflect the BLE-scan gate on 12+; prefer `getBluetoothState()`. |
| `getBluetoothState()` | Android + iOS | `poweredOn/poweredOff/unauthorized/...` — on Android 12+, `unauthorized` means `BLUETOOTH_SCAN` (Nearby devices) is missing. |
| `getPersistedLog()` / `getPersistedLogRaw()` | iOS | Persisted detection log. Android returns `[]` (native SDK has no persisted log). |
| `clearPersistedLog()` | iOS | No-op on Android. |
| `enableForegroundScanning([ForegroundScanConfig])` | Android | iOS: no-op. |
| `disableForegroundScanning()` | Android | iOS: no-op. |
| `isForegroundScanningEnabled()` | Android | iOS always resolves `false`. |
| `setForegroundNotificationContent(NotificationContent)` | Android | iOS: no-op. |
| `setErrorReportingEnabled(bool)` | Android + iOS | Opt out of the Dart-layer error telemetry (default: on). Native crash capture is independent. |
| `setDebugNotificationsEnabled(bool)` | iOS | QA aid: visible local notification per silent-push scan (default: off — keep off in production). Silent no-op on Android. Also settable via `configure(debugNotifications:)`. |

### Streams

| Stream | Platform | Emits |
|---|---|---|
| `beaconsStream` | Android + iOS | `List<Beacon>` — detected beacons with metadata (battery, firmware, temperature). |
| `scanningStream` | Android + iOS | `bool` — scanning state changes. |
| `errorStream` | Android + iOS | `BearoundError` — SDK errors. Replays up to 16 errors emitted before the first listener (buffer arms on first `errorStream` access); subscribing before `startScanning()` is still recommended. |
| `syncLifecycleStream` | Android + iOS | `SyncLifecycleEvent` — sync `started`/`completed`. |
| `backgroundDetectionStream` | Android + iOS | `BackgroundDetectionEvent` — beacon count detected in background. |
| `beaconRegionStream` | Android + iOS | `BeaconRegionEvent` — beacon-region `enter`/`exit`. |
| `activeScanStream` | Android + iOS | `ActiveScanEvent` — active scan (ranging + BLE) on/off. |
| `bluetoothZoneStream` | iOS | `BluetoothZoneEvent` — Bluetooth-eye zone enter/exit (two-eyes model). Never emits on Android. |
| `bluetoothScanModeStream` | iOS | `BluetoothScanModeEvent` — BLE scanner duty cycle (`idle`/`active`). Never emits on Android. |
| `bluetoothStateStream` | Android + iOS | `BluetoothState` — Bluetooth adapter state (emits current state on subscribe). |

### Configuration Enums

- **ScanPrecision**: `high` (continuous scan, sync every 15s — plugin default), `medium` (10s scan + 10s pause per 60s), `low` (10s scan + 50s pause per 60s)
- **MaxQueuedPayloads**: `small` (50), `medium` (100 — default), `large` (200), `xlarge` (500)

## Troubleshooting

| Symptom | Check | Fix |
|---|---|---|
| No beacons detected (any platform) | Is it a **Bearound beacon**? The SDK only detects beacons advertising the proprietary **`0xBEAD` service data** — a generic iBeacon, or an iPhone simulating an iBeacon, is filtered out **by design** (Android scan filter accepts only `0xBEAD`). | Test with a real Bearound beacon. |
| No beacons detected | `await BearoundFlutterSdk.isConfigured()` returns `false`. | Call `configure()` (and await it) before `startScanning()`. |
| No beacons on **Android 12+** | `getBluetoothState()` returns `unauthorized` — "Nearby devices" (`BLUETOOTH_SCAN`) was denied. **Granting location does NOT unlock BLE scan on 12+.** | Request the Nearby devices permission (`requestPermissions()` does it) or send the user to app settings. |
| No beacons on **iOS** | `getBluetoothState()` ≠ `poweredOn`, or `getAuthorizationStatus()` is `denied`/`notDetermined`. | Turn Bluetooth on; call `requestPermissions()` (Location "Always" is required for terminated-app wake-up). |
| Detection stops in background (**Android**) | Battery optimization active or OEM battery killer (Xiaomi/Huawei/…): `isIgnoringBatteryOptimizations()` / `isAutostartManageable()`. | Follow the [Background reliability](#background-reliability-android) flow; for mission-critical presence use the [foreground-service mode](#mode-2--foreground-service-connecteddevice). |
| Detection stops in background (**iOS**) | Background App Refresh disabled, or `BGTaskSchedulerPermittedIdentifiers` missing from `Info.plist`. | Enable Background App Refresh in device Settings; add both BGTask identifiers + `registerBackgroundTasks()` ([iOS setup](#background-tasks-bgtaskscheduler--required)). |
| Errors never show up | `errorStream` accessed only **after** the error was emitted — the replay buffer (16 entries) only arms on the first access to the getter. | Access/subscribe to `errorStream` **before** calling `startScanning()`; errors emitted after the buffer armed are replayed to the first listener. |
| Push token NULL in the backend / silent push never arrives (iOS) | Firebase present → the SDK's automatic APNs capture fails (swizzle intercepted). | Always call `setPushToken` with the **raw APNs token** ([Push Token](#push-token)). |
| App not woken when terminated (iOS) | Force-quit apps are **never** woken by silent push (Apple rule); relaunch happens via **beacon-region wakeup** and requires Location "Always" + the legacy AppDelegate setup. | Follow [Push notifications & background wakeup](#push-notifications--background-wakeup); verify the `aps-environment` matches the APNs environment (sandbox vs production). |

## Error telemetry

The SDK ships lightweight, isolated crash telemetry so we can spot and fix
integration issues quickly. It works on two layers:

- **Native (Android/iOS):** the embedded native SDKs already capture native
  crashes via their own `ErrorReporter`s. Nothing to configure.
- **Dart (this plugin):** installed automatically on `configure()`, it chains
  `FlutterError.onError` and `PlatformDispatcher.onError` and reports **only**
  uncaught errors whose **first application frame** is in
  `package:bearound_flutter_sdk` — i.e. errors that *originate* in the plugin.
  Errors from your app or third-party packages are never touched, including
  errors thrown inside your own callbacks that merely pass through the SDK.

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
