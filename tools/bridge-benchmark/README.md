# Android beacon bridge harness

This isolated Android library compiles the actual production plugin and a generated
published comparison class. It uses published native SDK `v3.14.0` for both callbacks,
the real Flutter embedding jar, and JUnit 4 with Robolectric 4.13 on API 34. It does
not attach a Flutter engine or start the native SDK.

Run from the repository root:

```bash
bash tools/bridge-benchmark/run.sh regression
bash tools/bridge-benchmark/run.sh compile
bash tools/bridge-benchmark/run.sh benchmark /absolute/path/bridge-results.json
```

The runner reuses the existing Gradle 8.13 launcher in the sibling native worktree.
It validates Java 17 and Gradle 8.13, uses the cached dependencies offline, selects
exactly `BeaconBridgeRegressionTest` or `BridgeBenchmarkTest`, and bounds Gradle
execution with a 240-second watchdog. No wrapper binary is copied here.

Runtime overrides: `BRIDGE_GRADLE_LAUNCHER`, `BRIDGE_JAVA_HOME`, `BRIDGE_ANDROID_SDK`,
`BRIDGE_FLUTTER_HOME`, and `BRIDGE_ROBOLECTRIC_DIR`. Defaults use the installed Homebrew
Java/Flutter, local Android SDK and cached Robolectric Android 14 instrumented jar.
These variables do not modify global runtime settings or production dependencies.

The generator validates tag `v3.14.0` against commit
`4f61d32d47b96cd16de0464c3f04f4aaea5d8a50` and verifies the original published source
SHA-256 `7d4fbbc13e6dc0ae1eced82576d50e9da18a798618d2320ef1f3ee0e0d94d270`.
Only the class name and preexisting U+2014 punctuation in line comments change.
A check compares runtime source after removing those comments and reverting the
class rename. Generated source and `source-hashes.properties` stay under ignored
`build/`. Hash keys are `publishedOriginal`, `publishedGenerated`, `candidate`,
`publishedCommit` and `nativeCoordinate`. Native dependency resolution and its
runtime version are checked independently.

The regression suite compares exact maps and asynchronous delivery from both actual
plugins, including complete metadata/RSSI stats, nulls, empty input, event order,
cancellation and live-sink resubscription. Candidate-only controls reject every
list access and queued delivery when there is no sink. Red/green evidence can be
saved under ignored `build/proofs/` without changing production source for the red run.

The benchmark uses deterministic 1/6/50-beacon models and both sink modes, 5,000 warmup
callbacks per variant/scenario, then three ABBA cycles with 1,000 callbacks per round.
It drains batches of 25 equally and counts actual messages for each plugin's Handler
before draining. Capture sinks retain only counts/checksums. Subscribed payload checksums
are compared with explicit expected maps; read, queue and delivery controls have no
timing threshold. All 72 rounds remain in schema-1 JSON, with exact fixture values,
source hashes, thread/providers, observed GC, CPU/wall time and allocated bytes.
Unsupported metrics are null with a reason. Host metric snapshots use reflection on
public Java 17 MXBean interfaces because Android's compile bootclasspath omits those
desktop APIs. No forced GC is used.

Measured timing includes list counters, actual queue probes, metric snapshots, checksum and drain
overhead on the measured thread. It excludes setup, IO, Flutter codec/engine, JNI,
Dart and BLE. Host measurements cannot establish whole-app CPU, ANR or battery gains.
