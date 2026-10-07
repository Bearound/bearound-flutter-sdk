# Decisions

- First experiment: Android Flutter beacon bridge only. Incremental diagnostic storage and network payload changes are out of scope for this comparison.
- Preserve public APIs and all subscribed payloads. Add a guard before mapping/posting when no beacon sink exists. Do not remove the asynchronous post or throttle subscribed callbacks.
- Keep native SDK pinned to the published v3.14.0 so the previous native PR cannot confound this test. No package publication or version bump.
- Test actual published and candidate callback implementations in one reproducible Robolectric harness. Generate the published comparison class from the fixed Git tag by renaming only its class; record source hashes. No simplified surrogate mapper.
- Fixed synthetic models include metadata and RSSI statistics. Use equal callback counts and list sizes 1, 6, and 50. Warm both implementations, then alternate ABBA rounds. Collect thread CPU, wall time and allocation bytes when available; record unsupported metrics explicitly. Drain the queue consistently and bound event batches.
- Independently count input beacon reads, event deliveries and payload equivalence. No subscriber must perform zero beacon reads and leave no pending delivery. With a subscriber every event remains ordered and complete. Cover empty lists, optional nulls, cancellation before delivery and new subscription after cancellation.
- Report host benchmark scope and no implied whole-app CPU, ANR or battery guarantee. Physical test follows when Samsung reconnects; this is a separately recorded hardware-dependent check, not a condition for completing the controlled experiment.
- Root owns engine state, QA results/report and every device operation. One implementation worker owns production guard, native tests and isolated benchmark harness. No concurrent writers.

## Out of scope
Diagnostic-store migration, iOS bridge, BLE scan scheduling, telemetry format, server contracts, third-party permissions and release publication.
