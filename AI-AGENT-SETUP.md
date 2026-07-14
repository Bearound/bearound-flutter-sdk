# Bearound Flutter — AI agent setup prompt

Hover the block below and click the **copy icon** in its top-right corner to copy
the prompt, then paste it into your AI coding agent (Claude Code, Cursor, Copilot, …)
with your app's repo open. The agent reads the [SDK README](./README.md) and wires
the full iOS/Android background integration.

```text
Integrate bearound_flutter_sdk into this Flutter app (iOS + Android). First READ the
SDK's README end to end — especially "Platform Setup" (Android + iOS), "Disable
UIScene (Flutter 3.41+) — required", "Background tasks (BGTaskScheduler) — required",
"Push notifications & background wakeup", "Silent-push wake-up (Android)", and
"Quick Start" — then do ALL of the following.

SCOPE: You do NOT have the SDK's example/ dir in your app repo, so never try to open
it. Wire the complete iOS AppDelegate from the SDK README (step 4); apply every change
to YOUR app's repo. The example is a demo, NOT a template: its Info.plist is a build-time stub, its build.gradle.kts
has a dev-only mavenLocal(), its Runner.entitlements is `development`, and its
main.dart hardcodes a demo businessToken. Do NOT copy those.

1. Install: add `bearound_flutter_sdk: ^3.4.5` under dependencies in pubspec.yaml and
   run `flutter pub get`. In android/app/build.gradle.kts set `minSdk = 23` (replace
   the `flutter.minSdkVersion` reference). iOS Podfile: UNCOMMENT and set
   `platform :ios, '13.0'` (fresh Podfiles ship it commented), and INSIDE
   `target 'Runner' do` add `use_frameworks!` — the AppDelegate in step 4 does
   `import BearoundSDK`, a transitive Swift pod that is only visible with dynamic-
   framework linkage, which a fresh Podfile omits (without it, step 8's iOS build fails
   with "no such module BearoundSDK"). Then `cd ios && pod install` (run `flutter pub
   get` FIRST so `.symlinks/plugins` exists). Also ensure the Runner APP target's
   IPHONEOS_DEPLOYMENT_TARGET >= 13.0. Add JitPack for the native Android SDK: if the
   app's android/settings.gradle(.kts) has a `dependencyResolutionManagement {
   repositories { … } }` block (newer Flutter template), add
   `maven { url = uri("https://jitpack.io") }` INSIDE that repositories block — do NOT
   use allprojects, it fails under RepositoriesMode.FAIL_ON_PROJECT_REPOS. Otherwise
   (older template, like example/) add it in the root android/build.gradle.kts under
   `allprojects { repositories { … } }`. Kotlin DSL uses
   `maven { url = uri("https://jitpack.io") }`; only in a Groovy build.gradle use
   `maven { url "https://jitpack.io" }` — never paste Groovy string-call syntax into a
   .kts file (compile error → the native SDK never resolves).

2. iOS Info.plist (ios/Runner/Info.plist): add the five UIBackgroundModes (fetch,
   location, processing, bluetooth-central, remote-notification), the two
   BGTaskSchedulerPermittedIdentifiers (io.bearound.sdk.sync, io.bearound.sdk.processing),
   and the NS…UsageDescription strings (NSBluetoothAlwaysUsageDescription,
   NSLocationWhenInUseUsageDescription, NSLocationAlwaysAndWhenInUseUsageDescription)
   — user-facing rationale, no jargon. Then run `plutil -lint ios/Runner/Info.plist`.

3. iOS UIScene — REQUIRED (README "Disable UIScene"): find `UIApplicationSceneManifest`
   in ios/Runner/Info.plist and rename it to `_UIApplicationSceneManifest` — keep the
   `_`, do NOT delete the block. If the key is NOT present, this is a fresh Flutter
   3.41+ project where the migrator injects it only at BUILD time: run
   `flutter build ios --no-codesign` ONCE so the key appears, THEN rename it; if it is
   still absent, add this top-level inert block manually:
   `<key>_UIApplicationSceneManifest</key><dict><key>UIApplicationSupportsMultipleScenes</key><false/></dict>`.
   A literal "rename" when no key exists is a no-op — step 8's build then injects the
   UNPREFIXED key, UIScene stays ENABLED, and state restoration, region relaunch and
   silent-push wakeup all silently die. Keep UIMainStoryboardFile /
   UILaunchStoryboardName as-is (removing them causes a black screen). If a
   SceneDelegate.swift exists it is now dead code — delete it and its project.pbxproj
   references.

4. iOS AppDelegate — wire the COMPLETE AppDelegate. The SDK README's iOS section
   ("Background tasks (BGTaskScheduler) — required") shows it IN FULL — it is
   example/ios/Runner/AppDelegate.swift verbatim, also fetchable at
   https://raw.githubusercontent.com/Bearound/bearound-flutter-sdk/main/example/ios/Runner/AppDelegate.swift
   — use it as-is, including
   `import BearoundSDK` and the patchFlutterProMotionCrash() call (invoked FIRST in
   didFinishLaunching — REQUIRED, because disabling UIScene in step 3 re-enters an
   iOS-26 ProMotion crash path that this workaround fixes; omitting it crashes the host
   on iPhone 15 Pro and newer). The file uses `class AppDelegate: FlutterAppDelegate`,
   calls GeneratedPluginRegistrant.register(with: self),
   BeAroundSDK.shared.registerBackgroundTasks() before super, and
   application.registerForRemoteNotifications(); overrides
   performFetchWithCompletionHandler and handleEventsForBackgroundURLSession; and
   overrides the DEPRECATED application(_:didReceiveRemoteNotification:) WITHOUT
   fetchCompletionHandler (the modern variant is not delivered on Flutter,
   flutter#155479), guarded on userInfo["bearound"] != nil ->
   performBackgroundBLERefreshAndSync. The bullet list describes that file — it is NOT
   a license to hand-write a subset. ONE conditional edit to the verbatim copy: keep
   registerBackgroundTasks, registerForRemoteNotifications, performFetch,
   handleEventsForBackgroundURLSession and the bearound-guarded silent-push override
   UNCONDITIONAL; BUT if YOUR app already registers a UNUserNotificationCenter delegate
   (firebase_messaging / flutter_local_notifications), do NOT set `center.delegate =
   self` or call `requestAuthorization` — leave the existing owner and add only the
   bearound-guarded silent-push override. Otherwise copy as-is.

5. iOS Push entitlement: write ios/Runner/Runner.entitlements with
   `aps-environment` = `production`, then set `CODE_SIGN_ENTITLEMENTS =
   Runner/Runner.entitlements` in ONLY the three XCBuildConfiguration blocks
   (Debug/Profile/Release) that carry `PRODUCT_BUNDLE_IDENTIFIER` for the Runner APP
   target — NOT the project-level blocks and NOT the RunnerTests blocks (their bundle
   ids end in `.RunnerTests`). Prefer editing via Xcode or the ruby `xcodeproj` gem
   over a blind text replace of project.pbxproj. Do NOT copy
   example/ios/Runner/Runner.entitlements (it is `development`). Match the backend APNs
   credential environment to the build under test (dev/sandbox ⇄ store/production).

6. Dart (Quick Start): in `main()` call `WidgetsFlutterBinding.ensureInitialized()`
   FIRST, then run the async setup (await before runApp, or from the root widget's
   initState) — never invoke SDK methods before the binding is ready. Call
   `await BearoundFlutterSdk.requestPermissions()`, then
   `await BearoundFlutterSdk.configure(businessToken: <see below>,
   scanPrecision: ScanPrecision.high, maxQueuedPayloads: MaxQueuedPayloads.medium)`,
   then `await BearoundFlutterSdk.startScanning()` with NO foregroundScanConfig —
   OPPORTUNISTIC is the default and wakes even app-killed via the PendingIntent, with
   no Play Store review video. Only pass `foregroundScanConfig: const
   ForegroundScanConfig()` if I confirm we will submit the Play Console foreground-
   service declaration + demo video; STOP and ask which mode before wiring it. Wire the
   OEM-reliability flow: if !isIgnoringBatteryOptimizations() show a rationale then
   openBatteryOptimizationSettings(); if isAutostartManageable() show a rationale then
   openManufacturerAutostartSettings(). businessToken: read from
   `const String.fromEnvironment('BEAROUND_TOKEN')` (passed as
   `--dart-define=BEAROUND_TOKEN=…`). NOTE this returns '' (compiles green) when the
   define is absent, and configure() only throws at RUNTIME — which step 8's build
   never reaches — so ASSERT the token is non-empty before calling configure(). If
   unset, STOP and get the real token; never hardcode a placeholder and never fall back
   to the example token `ee2ec9c46d2b2ad99bddcdd0afe224e6` (example/lib/main.dart
   hardcodes it; it authenticates as the wrong tenant). Push token: the SDK's
   AppDelegate swizzle already captures the RAW APNs token on iOS, so setPushToken is
   OPTIONAL — on a fresh Firebase-less app do NOT add Firebase. Only if Firebase is
   present (it intercepts the swizzle): add `firebase_messaging` to pubspec.yaml and run
   `flutter pub get`, then forward `FirebaseMessaging.instance.getToken()` on Android /
   `getAPNSToken()` (RAW APNs, NOT getToken()) on iOS via setPushToken. Do NOT invent a
   token.

7. Silent-push wake-up on Android — OPTIONAL: wire this ONLY if the backend wakes the
   device by silent push; skip the whole step otherwise. It applies solely when the app
   uses `firebase_messaging` — Firebase delivers the data push to YOUR background
   handler, not to the SDK, so you MUST forward it. In the handler registered via
   `FirebaseMessaging.onBackgroundMessage` (annotate it `@pragma('vm:entry-point')`),
   call `DartPluginRegistrant.ensureInitialized()` FIRST — the handler runs in a
   SEPARATE isolate where the plugin's method channel isn't registered, so without it
   the next call silently no-ops — THEN `await BearoundFlutterSdk.handleRemoteMessage(
   Map<String, String>.from(message.data))`. It returns `true` and fires the on-demand
   scan + sync for Bearound wake-ups (the payload carries the `bearound` marker) and
   `false` for any third-party push — pass those through to your own handling. iOS needs
   NOTHING here: the AppDelegate from step 4 already forwards the silent push down the
   same path. If the app does NOT use `firebase_messaging` there is nothing to wire — a
   backend push wake-up needs an FCM receiver, so the step is inapplicable. See
   README → "Silent-push wake-up (Android)".

8. Verify: run `flutter analyze` (0 errors), `flutter build apk --debug` (proves
   JitPack + native Android SDK resolve), and `flutter build ios --no-codesign`. Run the
   builds WITH `--dart-define=BEAROUND_TOKEN=<real token>` so the binary is actually
   authenticated — a tokenless build compiles green but fails at configure() on-device,
   and IS a FAILED verification. `flutter build ios --no-codesign` proves ONLY that pods
   resolve and the AppDelegate COMPILES; `--no-codesign` SKIPS signing, so it does NOT
   validate the entitlement, the Push capability, the provisioning profile, or any
   background/terminated wake — do NOT claim success from a green build. Then `plutil
   -lint` / `plutil -p` ios/Runner/Info.plist shows all five modes AND both BGTask ids.
   Assert the UIScene rename survived the FINAL build:
   `plutil -p ios/Runner/Info.plist | grep -q _UIApplicationSceneManifest` AND the
   unprefixed key is ABSENT (`! plutil -p ios/Runner/Info.plist | grep -qE
   '"UIApplicationSceneManifest"'`). If the unprefixed key reappeared, the migrator
   re-injected it — re-apply step 3's rename and rebuild. Treat a failed assert as a
   build FAILURE. A green build is NOT success: terminated wake still requires the human
   Xcode Push capability + on-device Always-location & Background App Refresh, then a
   PASSING 3-state field test with a real beacon. Only after the builds pass, hand me the
   3-state field-test checklist. Report any build failure instead of claiming success.

Guardrails — follow strictly:
- iOS: NEVER rely on the SDK's APNs push swizzle alone if Firebase is present —
  Firebase intercepts it and the token ends up NULL. Forward the RAW APNs token via
  setPushToken (NOT the FCM token on iOS).
- Android: default to the OPPORTUNISTIC scan (no foregroundScanConfig) — it wakes even
  app-killed via the PendingIntent and needs no Play review video. The connectedDevice
  foreground service is more resilient to aggressive OEM kills but REQUIRES a Google
  Play foreground-service declaration + demonstration video at review — do NOT wire it
  without my confirmation (STOP and ask which mode).
- The SDK must NEVER crash the host app.
- businessToken is REQUIRED and must be supplied by ME. If you do not have it, STOP and
  ask — do NOT reuse the example app's demo token (example/lib/main.dart hardcodes one;
  it authenticates as the wrong tenant and must never ship). Read it from
  `--dart-define=BEAROUND_TOKEN` or a config I provide, and assert it is non-empty
  before configure().
- STOP and hand me click-by-click steps for anything only a human can do: the Xcode
  Push Notifications capability signed with my provisioning profile (aps-environment
  development for Debug, production for Release), on-device grants (Always location +
  Background App Refresh), and the Google Play foreground-service declaration +
  demonstration video. Do not attempt those yourself.
```

Web-capable agents can fetch this prompt directly from its raw URL:
`https://raw.githubusercontent.com/Bearound/bearound-flutter-sdk/main/AI-AGENT-SETUP.md`
