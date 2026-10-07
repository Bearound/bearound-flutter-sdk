# Physical validation status

Status: not executed. The Samsung was absent from the ADB device inventory during preparation of the controlled comparison. A request to reconnect it with USB debugging authorized was already sent to the user.

The controlled experiment does not certify Android ANR behavior, battery life, frames or whole-app CPU. The physical task remains unchecked until evidence exists. No physical APK was installed as part of this stage.

## Required physical controls

- Record device model, OS/API, APK hashes, Flutter source hash and resolved native SDK version.
- Keep identical synthetic callback count and real Beacon metadata/RSSI fixtures across published and candidate. Run both subscriber modes, preserving warm-up and alternating order.
- Verify complete ordered payload delivery, cancellation before queued delivery, resubscription and later callbacks. Confirm the no-subscriber candidate does not read the input or queue deliveries.
- For Car Media, separately measure real BLE/location plus telemetry, process CPU, allocation, main-thread stalls and relevant ANR/crash exits. A bridge-only microbenchmark does not cover the whole pipeline.
- Record background and recovery scenarios in the wider SDK homologation matrix. Do not infer coverage for an iPhone, S7 or Moto G from this controlled Android bridge test.

The previous Samsung report is historical evidence for a different native candidate. It is not evidence for this Flutter guard.
