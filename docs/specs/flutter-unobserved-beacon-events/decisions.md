# Decisions

- First experiment: Android Flutter beacon bridge only. Incremental diagnostic storage and network payload changes are out of scope for this comparison.
- Preserve public APIs and all subscribed payloads. Add a guard before mapping/posting when no beacon sink exists. Do not remove the asynchronous post or throttle subscribed callbacks.
- Keep native SDK pinned to the published v3.14.0 so the previous native PR cannot confound this test. No package publication or version bump.
- Test actual published and candidate callback implementations in one reproducible Robolectric harness. Generate the published comparison class from the fixed Git tag by renaming only its class; record source hashes. No simplified surrogate mapper.
- Fixed synthetic models include metadata and RSSI statistics. Use equal callback counts and list sizes 1, 6, and 50. Warm both implementations, then alternate ABBA rounds. Collect thread CPU, wall time and allocation bytes when available; record unsupported metrics explicitly. Drain the queue consistently and bound event batches.
- Independently count input beacon reads, event deliveries and payload equivalence. No subscriber must perform zero beacon reads and leave no pending delivery. With a subscriber every event remains ordered and complete. Cover empty lists, optional nulls, cancellation before delivery and new subscription after cancellation.
- Report host benchmark scope and no implied whole-app CPU, ANR or battery guarantee. Physical test follows when Samsung reconnects; this is a separately recorded hardware-dependent check, not a condition for completing the controlled experiment.
- Root owns engine state, QA results/report and every device operation. One implementation worker owns production guard, native tests and isolated benchmark harness. No concurrent writers.

## Extension: private dictionary model

- owner: planner. Schema3 privado usa arrays de beacon rows e referências de frames, um dicionário de strings por batch (UUID, proximity e firmware) e dicionários de rows completos de metadata e RSSI stats. Cada ocorrência mantém uma observação completa; dados novos criam entradas distintas. Sem médias, deltas, arredondamento ou chaves produzidas por serialização JSON.
- owner: planner. Identidade, strings e rows são deduplicados por igualdade estrutural tipada, incluindo extras. Hashes iguais não autorizam união de valores diferentes. Null, omissão de RSSI, valores/tipos numéricos, timestamps absolutos, duplicatas e ordem permanecem verificáveis no golden.
- owner: planner. Baseline é o schema2 de rows já existente, emparelhado diretamente com schema3 no mesmo APK. Medições históricas de schema1/schema2 não entram na razão deste experimento. Ambos incluem packing, codec e reconstrução na CPU.
- owner: planner. Conservar os nove casos atuais de metadata variável (1/6/50 beacons por 1/10/100 frames) e acrescentar repeated-blocks e unique-blocks, ambos 6 por 100. Warm-up igual, três ciclos ABBA por caso, 132 rodadas por processo e dois processos independentes. Preservar todas as rodadas.
- owner: planner. Igualdade golden é obrigatória a cada operação. Controles extras cobrem nulls, omissão/presença de RSSI, campos adicionais, colisões de chaves, mudança de entradas do dicionário e duplicatas. Unique-blocks e entradas pequenas podem refutar um ganho geral; não há ganho mínimo presumido.
- Root implementa o probe e o modo de intent, constrói o APK, controla ADB, valida os resultados, escreve relatórios e commits. Planner altera apenas este spec. Alocação é contador do processo, sem alegação de RAM retida. Car Media, SDK publicado, protocolo e dependência nativa permanecem inalterados.

## Out of scope
Diagnostic-store migration, iOS bridge, BLE scan scheduling, telemetry format, server contracts, third-party permissions and release publication.
