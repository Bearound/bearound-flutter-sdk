# Physical validation status

Status: executed on 2026-10-07. Samsung Galaxy A16 5G SM-A166M, Android 16/API 36. Two independent QA app processes completed all 28 functional controls, 72 ABBA rounds and five separate codec probes each. The native dependency stayed published v3.14.0. No scanner, network or Flutter engine was initialized by the QA app.

The controlled experiment does not certify Android ANR behavior, battery life, frames or whole-app CPU. QA APK SHA-256: `0a396616282f0427e592d3aaaa25a2a59ac67fcb3b3dce351b6e35deb9929ca1`. This is an isolated `io.bearound.qa.bridge` app; the previously installed Car Media APK was not replaced.

## Results

At six beacons without a subscriber, 72,000 input reads became zero across both runs. Every public Handler queue-presence probe became false in the candidate. Median measured producer-plus-sink CPU per callback: 66.810 microseconds published, 0.075 candidate. Median paired-cycle CPU ratio indicates a 99.8877% reduction in this instrumented region. Median process-wide allocation delta per callback: 17,268.736 B to 32.768 B. Residual counters include scheduling/instrumentation and other process activity; they are not isolated guard allocation.

With a subscriber at six beacons, both variants delivered all 12,000 measured events with matching golden checksums and 72,000 input reads. Process allocation medians were equal at 18,153.472 B/callback. CPU remained a review concern: per-process paired changes were +1.7789% and +0.7628%; pooled paired median +1.2708%. One-beacon paired CPU was -0.6553%, 50-beacon +0.4763%. The earlier host +6.2% signal is smaller on the phone, but these data do not prove a subscribed-path improvement or an equivalence bound.

Both runs retained every round, equal warm-up and ABBA order. Five codec checks per process preserved exact golden values/types. No QA crash-buffer entries were captured during either run. ANR and whole-app performance remain separate acceptance gates; absence of a crash in this short synthetic test is not certification.

Evidence retained under `qa/sdk-performance-20261007/flutter-stream-experiment/physical-samsung/`: `run-1-retry/results.json`, `run-2/results.json`, APK metadata and exit-info captures, validated combined summary and HTML report. The initial `run-1` launcher failure occurred before installation: ADB split a date format containing a space. Its metadata is retained; the remote format separator was corrected before the successful retry. No SDK/app exception caused that controller failure.

## Required physical controls

- Record device model, OS/API, APK hashes, Flutter source hash and resolved native SDK version.
- Keep identical synthetic callback count and real Beacon metadata/RSSI fixtures across published and candidate. Run both subscriber modes, preserving warm-up and alternating order.
- Verify complete ordered payload delivery, cancellation before queued delivery, resubscription and later callbacks. Confirm the no-subscriber candidate does not read the input or queue deliveries.
- For Car Media, separately measure real BLE/location plus telemetry, process CPU, allocation, main-thread stalls and relevant ANR/crash exits. A bridge-only microbenchmark does not cover the whole pipeline.
- Record background and recovery scenarios in the wider SDK homologation matrix. Do not infer coverage for an iPhone, S7 or Moto G from this controlled Android bridge test.

The previous Samsung report is historical evidence for a different native candidate. It is not evidence for this Flutter guard.

## Private data-model experiment

F4-01 completed two independent processes per representation, 432 retained ABBA rounds.
Every measured encode/decode operation reconstructed the full input, with ordering,
nulls, omitted RSSI keys, changing metadata and current published field types preserved.
Separate controls cover empty frames and duplicate identity occurrences. These are
private QA models; neither the SDK public stream nor backend/network protocol changed.

Model 1 stores identity once and complete observation maps. At 6 beacons and 100
frames, 600 observations encoded as 272,943 B baseline versus 237,953 B prototype:
12.8195% smaller, but paired round-trip CPU rose 2.6342%. This did not meet the CPU
improvement objective.

Model 2 also stores field names once per batch and uses positional observation,
metadata and RSSI lists. Presence of the RSSI key and extra fields are preserved.
At 6 beacons and 100 frames, encoded bytes were 272,943 B versus 97,252 B (64.3691%
smaller). Paired CPU for grouping + codec encode + codec decode + reconstruction
fell 16.1270%; per-process reductions were 13.8621% and 19.6729%. Allocation is a
counter-signal: median process-wide bytes per operation increased 3.5052%, from
3,973,120 B to 4,112,384 B. This is not retained RAM or isolated serializer allocation.

Small inputs refuted a universal gain. Model 2 with 6 beacons in one frame used 32.7116%
fewer encoded bytes but 33.4568% more paired CPU. One beacon in one frame increased
encoded bytes 38.9899% and CPU 150.7499%. Recommend further work for batched history
or queues, including fewer constructor/reconstruction allocations, before integration.
Do not replace every live callback with this representation based on these results.

Model 2 QA APK SHA-256: `6a4f3386397ac6affdac79374bb2d6ce4f7412baf18808df13d485a7b6fa70a0`.
Its exact source and APK are retained with the local model report. Model 1 uses its
own APK; each representation was compared to its baseline within that same APK.
The codec is Flutter StandardMethodCodec on an ART worker thread, without Flutter
engine, Dart consumers, scanner or network. Codec byte counts differ from the
earlier synthetic JSON experiment; do not mix the 12.66% host JSON result with
the 64.37% physical codec result.

Evidence: `qa/sdk-performance-20261007/flutter-stream-experiment/physical-samsung/`
contains `model-run-1`, `model-run-2`, `packed-model-run-1`, `packed-model-run-2`,
`model-verified-summary.json`, `model-report.html`, source snapshot and model 2 APK.
The complete model example generated on the device is
`qa/sdk-performance-20261007/flutter-stream-experiment/compact-data-model.rows.prototype.json`.

All QA processes stayed alive throughout their measured runs. No process-level ANR
or crash exit was found in the retained QA exit captures. This remains a short
synthetic component test, not whole-app ANR certification. Car Media was not rebuilt
or replaced and no package was published.
