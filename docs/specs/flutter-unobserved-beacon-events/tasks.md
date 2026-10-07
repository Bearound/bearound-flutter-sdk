## Implementation Plan: Flutter unobserved beacon events
**Spec:** docs/specs/flutter-unobserved-beacon-events/
**Date:** 2026-10-07

### Reuse analysis
| What | Source | Action |
|---|---|---|
| Callback/payload | `android/src/main/kotlin/com/example/bearound_flutter_sdk/BearoundFlutterSdkPlugin.kt` | adapt guard; reuse subscribed code |
| Android runtime | `android/build.gradle` | reuse versions/dependency; avoid editing |
| Robolectric | `/Users/jotta/Documents/bearound/wt-android-sdk-idle-performance-20261006/sdk/src/test/java/io/bearound/sdk/BeaconManagerRadioRecoveryTest.kt` | adapt paused-looper fixture |
| Published callback | Git commit `4f61d32d47b96cd16de0464c3f04f4aaea5d8a50` | generate renamed class; normalize comments |

### Tasks

### Wave 1
- [x] F1-01: Guard and real bridge harness
  - req: REQ-001, REQ-002, REQ-003, REQ-004
  - layer: backend
  - deps: none
  - writes: `android/src/main/kotlin/com/example/bearound_flutter_sdk/BearoundFlutterSdkPlugin.kt`, `tools/bridge-benchmark/settings.gradle.kts`, `tools/bridge-benchmark/build.gradle.kts`, `tools/bridge-benchmark/.gitignore`, `tools/bridge-benchmark/README.md`, `tools/bridge-benchmark/run.sh`, `tools/bridge-benchmark/src/test/kotlin/com/example/bearound_flutter_sdk/BridgeFixture.kt`, `tools/bridge-benchmark/src/test/kotlin/com/example/bearound_flutter_sdk/BeaconBridgeRegressionTest.kt`, `tools/bridge-benchmark/src/test/kotlin/com/example/bearound_flutter_sdk/BridgeBenchmarkTest.kt`
  - reuse: `android/src/main/kotlin/com/example/bearound_flutter_sdk/BearoundFlutterSdkPlugin.kt`
  - design: "Component design", "Real-source harness", "Fixture interfaces", "Test strategy", "Benchmark protocol"
  - contracts: `BridgeFixture`, `EventSink`
  - tests: RED/GREEN zero reads; payload/order/async/cancel/resubscribe; baseline hashes
  - validate: `bash tools/bridge-benchmark/run.sh regression`; `bash tools/bridge-benchmark/run.sh compile`
  - cost: l
  - kind: required

### Wave 2
- [x] F2-01: Root equal-load benchmark and report
  - req: REQ-001, REQ-002, REQ-003, REQ-004, REQ-005
  - layer: backend
  - deps: F1-01
  - writes: `tools/bridge-benchmark/summarize.py`, `docs/specs/flutter-unobserved-beacon-events/benchmark-report.md`
  - reuse: `tools/bridge-benchmark/run.sh`, `tools/bridge-benchmark/src/test/kotlin/com/example/bearound_flutter_sdk/BridgeBenchmarkTest.kt`
  - design: "Benchmark protocol", "Report contract", "Error handling"
  - contracts: `BenchmarkResult`
  - tests: ABBA 1/6/50; equal callbacks/metadata/stats; independent reads/events/payload; unsupported metrics
  - validate: `bash tools/bridge-benchmark/run.sh benchmark "$BRIDGE_BENCHMARK_OUTPUT"`
  - cost: m
  - kind: required

### Wave 3
- [ ] F3-01: Root optional Android stream E2E
  - req: REQ-001, REQ-002, REQ-003, REQ-005
  - layer: e2e
  - deps: F2-01
  - writes: `tools/bridge-benchmark/e2e/physical-check.sh`, `docs/specs/flutter-unobserved-beacon-events/physical-validation.md`
  - reuse: `tools/bridge-benchmark/README.md`, `docs/specs/flutter-unobserved-beacon-events/benchmark-report.md`
  - design: "Test strategy", "Execution boundaries"
  - contracts: `PhysicalValidation`
  - tests: native Android stream E2E subscribed/unobserved/cancel/resubscribe; crash; documented hardware deferral
  - validate: `bash tools/bridge-benchmark/e2e/physical-check.sh --serial "$BRIDGE_DEVICE_SERIAL"`
  - cost: m
  - kind: optional
