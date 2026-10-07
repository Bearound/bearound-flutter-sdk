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


## Physical Android follow-up

Build the isolated debug app offline with the same Gradle launcher and pinned
published native SDK used by the host harness:

```bash
bash tools/bridge-benchmark/run.sh physical-build
```

The APK is `tools/bridge-benchmark/e2e/physical-app/build/outputs/apk/debug/physical-app-debug.apk`.
The application ID is `io.bearound.qa.bridge`. This plain Android activity does not
attach a Flutter engine, initialize the SDK, start scanning, use a network API,
or request runtime permissions. Dependency manifests may declare permissions.
The dependency startup provider is removed from the QA app manifest.

A device operator runs the bounded launcher with an explicit serial and absolute
output directory. Use `--skip-build` only after a successful current build:

```bash
bash tools/bridge-benchmark/e2e/physical-check.sh --serial SERIAL --output /absolute/qa-directory
```

The launcher records the APK SHA256, aggregate device OS information, package
exit information before and after the run, and crash records filtered to the QA
package. It launches with a unique `run_id` and retrieves private `files/results.json`
using `run-as`. The result is written only after success or a caught control error.
A 240-second result watchdog and individual command timeouts bound the run. The
launcher rejects mismatched source hashes, missing controls, incomplete ABBA
rounds, and invalid list, event, queue, thread, or CPU accounting controls. The
QA app remains installed after the run for inspection.

The app first checks complete payload equality for 1, 6, and 50 beacons, empty and
nullable payloads, asynchronous delivery, callback order, cancellation, live sink
lookup after resubscription, and rejected list access without a sink. The fixed
published source must demonstrate positive list access and queue presence without
a sink. `Handler.hasMessages(0)` independently observes queue presence inside each
producer batch. It does not count queued messages or infer a count from callbacks.

Six scenarios use deterministic 1/6/50 beacon lists with and without a sink. Each
variant and scenario receives 5,000 warmup callbacks. Three ABBA cycles produce
72 retained raw rounds of 1,000 callbacks each. Batches contain 25 callbacks and
yield the actual Android main looper so delivery runs before the next batch. Main
thread producer CPU is accumulated using `Debug.threadCpuTimeNanos`; consumer CPU
covers the instrumented bounded sink's delivery counting, payload checksum, and
thread check. Their sum is reported separately from elapsed real time, which
includes scheduling and yields. Probe costs are present in both variants.

ART allocated bytes and GC counts are process-wide observations, so they can
include UI work and other threads. Unsupported allocation counters produce null
and an explicit reason. The runner never forces GC. All raw rounds are retained
for paired analysis; no timing threshold is an acceptance criterion.

Five separate functional `StandardMethodCodec` success-envelope roundtrips cover
empty, nullable, and complete 1/6/50 payloads. Buffers are flipped before decoding;
exact equality proves integer, long, double, null, metadata, and RSSI-statistic
values survive serialization. Encoded bytes and one-shot CPU/wall probes are
recorded separately. These probes are not a codec throughput benchmark.

This is a synthetic actual Android bridge test. It does not establish Flutter
engine or Dart delivery costs, radio behavior, or whole Car Media ANR freedom.
The device operator must validate physical results; an APK build alone does not
validate on-device behavior.

### Private batch model probe

The same QA APK has a separate worker-thread mode for representation experiments:

```bash
adb -s SERIAL shell am force-stop io.bearound.qa.bridge
adb -s SERIAL shell am start -n io.bearound.qa.bridge/.MainActivity --es run_id MODEL_RUN --ez model_probe_only true --ez packed_rows true
```

Wait for private `files/model-results.json`, then retrieve it with
`adb -s SERIAL shell run-as io.bearound.qa.bridge cat files/model-results.json`.
Require matching `runId`, `status: success`, all six controls and 108 retained rounds.
Use a new process and run ID for each repeat. `packed_rows false` selects model 1
(identity plus observation maps); `true` selects model 2 (identity plus field tables
and positional rows). Neither changes the production callback or public protocol.

Both compare 1/6/50 beacons across 1/10/100 frames using equal warm-up and three ABBA
cycles. Baseline is full input frames through StandardMethodCodec. Prototype CPU
includes grouping, encoding, decoding and complete reconstruction. Every measured
operation checks exact typed golden equality outside the CPU interval; wall time
and process allocation include that check. Empty frames, duplicate occurrences,
changing metadata, nulls and omitted RSSI fields have explicit controls. Encoded
bytes are codec bytes, not JSON or network transfer sizes. Preserve all rounds and
small-input counterexamples; this component probe does not measure the whole app.

Use `--ez dictionary_rows true` with `model_probe_only` to compare schema 2 rows
directly against schema 3 arrays with batch-local dictionaries. This implies
`packed_rows true`. Both sides include packing, codec and reconstruction in CPU.
Schema 3 pools strings and complete metadata/RSSI rows, preserving every observation
and ordered frame reference. Reconstructed metadata/RSSI maps are fresh per observation.
Null, omitted keys, extra fields and hash collisions have preservation controls.

This mode retains 132 rounds: the nine existing cases plus repeated-block and
unique-block 6 x 100 cases. Run two fresh processes, require 13 successful controls,
`modelSchemaVersion: 3`, `baselineModelSchemaVersion: 2`, and matched ABBA counts.
`caseContexts.originalPayloadEncodedBytes` is measured outside timed loops for byte
reconciliation only. CPU is compared against schema 2 in the same run, not against
historical full-payload CPU. Dictionaries may add overhead when blocks are distinct.
