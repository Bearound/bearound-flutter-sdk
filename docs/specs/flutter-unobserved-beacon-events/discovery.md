# Discovery

Published baseline: Flutter SDK tag v3.14.0, commit 4f61d32d47b96cd16de0464c3f04f4aaea5d8a50. Isolated branch fix/skip-unobserved-beacon-events. Parent checkout has unrelated dirty work; preserve it.

## Confirmed source
- android/src/main/kotlin/com/example/bearound_flutter_sdk/BearoundFlutterSdkPlugin.kt:436-439: onBeaconsUpdated maps all beacons and posts a mainHandler runnable even when beaconsEventSink is null.
- Same file:42, 101-104: nullable sink assigned on listen, cleared on cancel. Detach clears all sinks. Keep the live sink lookup during delivery.
- Same file:493-539: mapping carries metadata, RSSI statistics, sync flags, optional fields. Keep the payload, order and subscribed event count exactly.
- android/build.gradle: native dependency com.github.Bearound:bearound-android-sdk:v3.14.0. Do not change the native version or production dependencies. Existing Flutter Android unit test configuration has no native test source and uses JUnit Platform.
- test/bearound_flutter_sdk_test.dart and test/src/models/beacon_test.dart: existing Dart contract coverage.
- /Users/jotta/Documents/bearound/wt-android-sdk-idle-performance-20261006/sdk/src/test/java/io/bearound/sdk/BeaconManagerRadioRecoveryTest.kt: existing Robolectric 4.13, JUnit4, paused Looper and real Beacon fixtures. Reuse this test-runtime precedent in an isolated tools harness.
- /Users/jotta/Documents/bearound/wt-android-sdk-idle-performance-20261006/gradle/wrapper/: cached Gradle8.13. Kotlin2.1.0, AGP8.11.1, JUnit4.13.2, Robolectric4.13 and published native3.14.0 AAR are cached.
- Flutter embedding: /opt/homebrew/share/flutter/bin/cache/artifacts/engine/android-arm64/flutter.jar.

No local AGENTS/AGENT/CLAUDE instruction files exist in this Flutter checkout. No Android bridge tests exist. A small reproducible native harness is warranted to execute the actual callback with Android runtime and preserve published Gradle configuration.

## Measurement limitation
Old native physical ABBA had about 3x different metadata input. Its observed CPU difference cannot isolate an SDK improvement. The new experiment must use identical generated lists/callback counts and an independent subscribed regression control. Physical Samsung is currently absent from ADB; root asked user to reconnect and must not claim physical ANR/battery gains from host timing.
