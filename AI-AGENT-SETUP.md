# Bearound Flutter — AI agent setup prompt

Hover the block below and click the **copy icon** in its top-right corner to copy
the prompt, then paste it into your AI coding agent (Claude Code, Cursor, Copilot, …)
with your app's repo open. The agent reads the [SDK README](./README.md) and wires
the full iOS/Android background integration.

```text
Integrate bearound_flutter_sdk into this Flutter app (iOS + Android). First READ
the SDK's README end to end — especially "Platform Setup" (Android + iOS),
"Disable UIScene (Flutter 3.41+) — required", "Background tasks (BGTaskScheduler)
— required", "Push notifications & background wakeup", and "Quick Start" — then do
ALL of the following, matching the README's proven-working `example/` app EXACTLY:

1. Install: add `bearound_flutter_sdk: ^3.4.5` under dependencies in pubspec.yaml
   and run `flutter pub get`. On Android, add the JitPack repository
   (`maven { url 'https://jitpack.io' }`) to dependencyResolutionManagement in the
   root `settings.gradle` (or `build.gradle`). Targets: Android minSdk 23, iOS 13.

2. iOS Info.plist (ios/Runner/Info.plist): add the five UIBackgroundModes (fetch,
   location, processing, bluetooth-central, remote-notification), the two
   BGTaskSchedulerPermittedIdentifiers (io.bearound.sdk.sync,
   io.bearound.sdk.processing), and the NS…UsageDescription strings
   (NSBluetoothAlwaysUsageDescription, NSLocationWhenInUseUsageDescription,
   NSLocationAlwaysAndWhenInUseUsageDescription) — write a user-facing rationale
   that matches what THIS app actually does (no internal jargon like "beacon").
   Then run `plutil -lint ios/Runner/Info.plist` and confirm it prints OK.

3. iOS UIScene — REQUIRED (README "Disable UIScene"): in Info.plist RENAME
   `UIApplicationSceneManifest` to `_UIApplicationSceneManifest` — keep the `_`
   prefix, do NOT delete the block (Flutter's migrator re-injects it whenever the
   substring disappears; the `_` keeps it inert while iOS ignores the unknown key).
   Keep UIMainStoryboardFile and UILaunchStoryboardName as-is (removing them causes
   a black screen). In ios/Runner/AppDelegate.swift use
   `class AppDelegate: FlutterAppDelegate` (NO FlutterImplicitEngineDelegate /
   didInitializeImplicitFlutterEngine) and call
   GeneratedPluginRegistrant.register(with: self) inside didFinishLaunching. If a
   SceneDelegate.swift exists it is now dead code — delete it and its
   project.pbxproj references.

4. iOS AppDelegate wiring (README "Background tasks" + "Push notifications" — copy
   the full file from example/ios/Runner/AppDelegate.swift): in didFinishLaunching
   call BeAroundSDK.shared.registerBackgroundTasks() BEFORE super and
   application.registerForRemoteNotifications(). Override
   performFetchWithCompletionHandler -> BeAroundSDK.shared.performBackgroundFetch
   and handleEventsForBackgroundURLSession ->
   BeAroundSDK.shared.handleBackgroundURLSessionEvents. Override the DEPRECATED
   application(_:didReceiveRemoteNotification:) WITHOUT fetchCompletionHandler (the
   modern variant is not delivered on Flutter — flutter#155479) and, guarded on
   userInfo["bearound"] != nil, call
   BeAroundSDK.shared.performBackgroundBLERefreshAndSync(...).

5. iOS Push entitlement: create ios/Runner/Runner.entitlements with `aps-environment`
   = `production`, and set CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements in
   the Runner build settings for ALL configurations (dev-signed builds are auto
   re-signed to `development`, so one file covers both).

6. Dart (Quick Start): call `await BearoundFlutterSdk.requestPermissions()`, then
   `await BearoundFlutterSdk.configure(businessToken: <ASK ME FOR IT>,
   scanPrecision: ScanPrecision.high, maxQueuedPayloads: MaxQueuedPayloads.medium)`,
   then `await BearoundFlutterSdk.startScanning()`. For reliable background
   detection on Android, enable the foreground service by passing
   `foregroundScanConfig: const ForegroundScanConfig()` to startScanning() (see
   "Scan modes"). Forward the push token with BearoundFlutterSdk.setPushToken —
   FCM token on Android, RAW APNs token on iOS.

7. Verify: `plutil -lint ios/Runner/Info.plist` prints OK and
   `plutil -p ios/Runner/Info.plist` shows all five background modes AND both
   BGTaskSchedulerPermittedIdentifiers; then give me the 3-state field-test
   checklist (foreground / background / terminated).

Guardrails — follow strictly:
- iOS: NEVER rely on the SDK's APNs push swizzle alone — Firebase intercepts it and
  the token ends up NULL in the backend. Forward the RAW APNs token explicitly via
  setPushToken (NOT the FCM token on iOS).
- Android: the opportunistic default is throttled by the OS and killed by aggressive
  OEMs (Xiaomi/Huawei/Samsung); for reliable background detection use the
  connectedDevice foreground service — and know it requires a Google Play
  foreground-service declaration + demonstration video at review.
- The SDK must NEVER crash the host app.
- Ask me for my businessToken; do not invent one.
- STOP and hand me click-by-click steps for anything only a human can do: the Xcode
  Push Notifications capability signed with my push-enabled App ID / provisioning
  profile, on-device permission grants (Always location + Background App Refresh),
  and the Google Play foreground-service declaration + demonstration video. Do not
  attempt those yourself.
```

Web-capable agents can fetch this prompt directly from its raw URL:
`https://raw.githubusercontent.com/Bearound/bearound-flutter-sdk/main/AI-AGENT-SETUP.md`
