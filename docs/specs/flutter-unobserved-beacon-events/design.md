Budget exceeded: preserving the completed design and complete schema3 contracts raises prose above the fast limit.

# Design: eventos Android sem observador

## Component design

Recomendação: adicionar somente o guard `if (beaconsEventSink == null) return` antes do mapeamento em `onBeaconsUpdated`, linhas 436–439. Por quê: o custo sem destinatário está confirmado no código, e o caminho assinado pode permanecer literalmente igual. Alternativa considerada: throttle de eventos assinados, descartada porque altera quantidade e latência observáveis.

REQ-001 a REQ-003: conservar `mapBeacon`, `mapMetadata`, o payload e `mainHandler.post { beaconsEventSink?.success(payload) }`. Não capturar sink em variável para uso na entrega, remover postagem, coalescer, acrescentar locks ou modificar outros canais. O guard decide apenas se o callback entra no caminho diagnóstico da ponte; não altera native SDK.

O sink atual é atribuído por onListen, limpo por onCancel e detach. Evento postado enquanto havia assinante segue consultando o sink vivo: cancelamento impede entrega ao anterior; reassinatura antes da execução conserva entrega ao novo sink. Callback recebido sem sink passa a ser descartado imediatamente, sem replay quando surge um assinante.

## Channel contracts

Não há endpoint HTTP, método de rede ou status code neste ajuste. REQ-002 e REQ-003 preservam o contrato `bearound_flutter_sdk/beacons`, `EventChannel`, stream com argumento de listen/cancel existente, e retorno de sucesso `Map<String, Any?>`:

```text
{ "beacons": [BeaconMap, ...] }
```

| Campo de BeaconMap | Forma preservada |
|---|---|
| uuid | String de UUID nativo |
| major, minor, rssi | Valores inteiros nativos |
| proximity | `toApiString()` existente |
| accuracy | Valor nativo |
| timestamp | `Date.time` |
| metadata | null ou mapa com firmwareVersion, batteryLevel, movements, temperature, txPower, rssiFromBLE, isConnectable |
| txPower, rssiRaw | Valores opcionais, com chave presente |
| alreadySynced, isStale | Booleanos nativos |
| syncedAt | null ou `Date.time` |
| rssiSamples | Chave omitida sem stats; caso contrário count, min, max, avg, stdDev, firstSeen, lastSeen |

Sem assinante não há resposta nem erro novo. Com assinante, lista vazia permanece evento válido com array vazio. Validar formas e valores com fixtures do AAR real, sem recriar modelos nativos ou mudar regras de validação. Outros canais e erros públicos permanecem intactos.

## Real-source harness

REQ-004: criar projeto Android library isolado em `tools/bridge-benchmark`, usando o source-set Kotlin real de `android/src/main/kotlin`. Não incluir nem editar o projeto Gradle Android de produção, que usa JUnit Platform. O harness configura Gradle 8.13, AGP 8.11.1, Kotlin 2.1.0, compileSdk 36, target JVM 11, JUnit4.13.2 e Robolectric4.13; `unitTests` usam JUnit4 e main looper pausado.

Reutilizar Gradle/dependências em cache e o precedente Robolectric nativo de `discovery.md`. Incluir Flutter embedding real em `/opt/homebrew/share/flutter/bin/cache/artifacts/engine/android-arm64/flutter.jar` para compilação e execução do fixture. Resolver exatamente `com.github.Bearound:bearound-android-sdk:v3.14.0`, sem substituição pelo worktree de otimização nativa. Runner valida versões e aceita runtime/cache explícitos quando necessário; não cria wrappers binários ou muda runtime global.

Uma tarefa Gradle gera `build/generated/published/.../PublishedBearoundFlutterSdkPlugin.kt` antes da compilação. Ler fonte por `git show` do commit fixo `4f61d32d47b96cd16de0464c3f04f4aaea5d8a50`, verificando que `v3.14.0` resolve a ele. Registrar bytes e SHA-256 originais antes de transformar. O executor confirmou hash original `7d4fbbc13e6dc0ae1eced82576d50e9da18a798618d2320ef1f3ee0e0d94d270` igual ao cache publicado pub.dev.

Renomear apenas a classe para coexistir com o candidato. Normalizar U+2014 preexistente exclusivamente em comentários para cumprir a regra de pontuação; validar que nenhuma string ou expressão foi alterada. Esse ajuste de comentários qualifica o detalhe de geração das decisões, mantendo código de runtime igual. Registrar também hash transformado e hash do candidato. Diretórios `build` e `.gradle` são ignorados; não versionar baseline extenso ou artefatos gerados.

## Fixture interfaces

`BridgeFixture.kt` instancia classes reais, chama `onBeaconsUpdated` e instala sink de captura através do campo privado por reflexão apenas no teste. Essa instalação representa a atribuição simples existente de listen/cancel, sem inicializar scan ou Flutter engine. Nenhuma seam pública de produção é necessária.

| Fixture | Contrato |
|---|---|
| FixedBeaconLists | Modelos Beacon/BeaconMetadata/RssiStats reais; tamanhos 1, 6 e 50; valores e datas determinísticos, metadata/stats completos e variante nullable. |
| CountingBeaconList | Conta acessos aos elementos independentemente das entregas; variante que falha se tamanho/elementos forem consultados prova retorno precoce. |
| CapturingEventSink | Conta success e retém mapas para controles de igualdade; errors/endOfStream inesperados falham regressão. |
| BoundedBenchmarkSink | Mesmo comportamento para A/B, contador/checksum e descarte depois de consumo; não retém eventos sem limite. |
| Paused main looper | Demonstra postagem assíncrona, inspeciona pendências, drena batches iguais e isola casos. |

Comparar mapas de ambos os plugins e assertivas explícitas dos valores esperados. Isso evita aceitar dois mappers igualmente incorretos. A fixture exercita o callback Android real com EventSink real de captura, sem medir codec, JNI/Flutter engine, BLE ou Dart.

## Benchmark protocol

REQ-005: A é publicado gerado, B é candidato. Construir fixtures antes da medição; usar mesmas listas, callback counts e sink para ambos. Executar modos sem assinante e com assinante, tamanhos 1/6/50, aquecimento por implementação/cenário e pelo menos três ciclos ABBA em um processo. Registrar número de callbacks, tamanho e composição exatos por caso.

Limitar batches e drenar a fila consistentemente em ambos os lados, inclusive sem assinante. A região medida contém callback real e drenagem, excluindo construção de fixtures, IO e inicialização do Robolectric. Contar leituras reais da lista instrumentada, entregas no EventSink e mensagens efetivamente pendentes antes de drenar; não calcular pendências pelo número de callbacks ou por inspeção da fonte. Os mesmos probes são usados em A/B; declarar o overhead de instrumentação como limite do timing.

Coletar tempo monotônico de parede, CPU da thread medida e bytes alocados quando o JVM oferece suporte. Registrar thread e provider; confirmar se drenagem roda na thread medida. Métrica não suportada fica null com motivo, nunca zero. Não usar `System.gc()` entre A e B nem confundir heap usado com bytes alocados. Registrar GC observado quando disponível e dispersão entre rodadas, evitando conclusões baseadas em uma execução.

Controles independentes: sem assinante candidato tem zero leituras/pendências/entregas; baseline demonstra leituras e trabalho pendente. Com assinante ambos entregam todos os eventos em ordem com mapas equivalentes. Esses controles podem refutar um ganho que veio de callback perdido ou lista menor. Um resultado de timing inconclusivo não invalida o mecanismo provado; não impor ganho mínimo inventado.

Contrato JSON fixo para o relatório do executor:

```json
{
  "schema": 1,
  "environment": {},
  "inputConfig": {},
  "sourceHashes": {},
  "measurements": [
    {
      "listSize": 6,
      "subscribed": false,
      "variant": "published",
      "round": 1,
      "callbackCount": 1000,
      "beaconReads": 6000,
      "deliveries": 0,
      "queuedDeliveryCount": 1000,
      "threadCpuNs": null,
      "wallNs": null,
      "allocatedBytes": null
    }
  ]
}
```

Valores acima apenas ilustram a forma; o harness registra contadores e métricas reais. `variant` aceita published/candidate; `round` ordena as execuções ABBA de cada cenário. environment identifica JVM, OS, runtime e motivos de métricas indisponíveis. inputConfig registra tamanhos, modos, callbacks, aquecimento, batch bound e ciclos. sourceHashes registra publicado original/gerado e candidato, com coordenada nativa validada no environment. Preservar todas as rodadas em JSON; o relatório apresenta medianas e dispersão sem descartar dados brutos.

## Error handling

Guard de produção não introduz erros ou fallback novo. No harness, hash/commit divergente, versão nativa diferente, geração inválida, fonte/Flutter jar ausente, teste ou controle de equivalência falho abortam com saída diferente de zero. CPU/alocação indisponível permite continuar com limitação explícita. Não substituir a fonte real por mapper simplificado para contornar falha de runtime.

Runner físico ausente pode ser deferido com evidência de disponibilidade ADB; falha funcional em aparelho conectado deve ser reportada e investigada pelo executor, não convertida em deferimento de hardware.

## Test strategy

### Physical Android follow-up

The reconnected Samsung enables F3-01. Add an isolated QA application under
`tools/bridge-benchmark/e2e/physical-app`, depending on the existing harness library,
so both real production classes and the fixed published native SDK run on ART in
the same APK. Do not change Car Media, initialize scanning, request permissions or
publish a package. Use the existing AGP, Kotlin and Flutter embedding dependencies.

Keep fixed complete 1/6/50-beacon input, warm-up, bounded batches and ABBA ordering.
Yield the main looper between batches. Install test sinks with Java reflection on
the plugin's own fields; do not reflect into Android hidden APIs. Count input reads,
ordered deliveries and public Handler queue presence independently. Record producer
and consumer thread CPU separately, elapsed wall time and process allocation/GC
counters when available. Process counters are not isolated thread allocation.

Verify complete golden maps, null/empty shapes, asynchronous delivery, cancellation,
resubscription and callbacks received while unobserved. A separate real Flutter
codec round-trip check verifies all serialized fields and types. This covers the
callback and codec on the device, not a Flutter engine, Dart consumer, BLE/location,
network, frame performance or whole-app ANR certification. Preserve every measured
round and source/APK hashes. The root executes all ADB operations and updates evidence.

### Private compact-model probe

The user's request also authorizes an isolated representation experiment after F3.
Do not replace a published SDK or network contract. Store uuid/major/minor once per
beacon, keep every other field in every observation, and retain ordered frame
references. No averaging, numeric deltas or rounding. Reconstruct identical field
types, nulls, omitted keys, observations and order, including changing metadata.

Reuse the proven physical fixture golden maps and Flutter StandardMethodCodec.
Run an additional intent mode on a worker thread in the isolated QA app. Compare
baseline batch codec round-trip against pack + codec round-trip + unpack, counting
all grouping/reconstruction CPU. Test 1/6/50 beacons across 1/10/100 frames, equal
warm-up and ABBA rounds. Preserve all data and separately record encode/decode CPU,
wall time, process allocation and encoded bytes. A single-frame overhead case is a
required counterexample. Root owns this sequential follow-up. Report phone codec
bytes separately from the existing host JSON counts and whole-app performance.

The first identity-only model showed a byte reduction without a CPU improvement.
Compare a second private representation: one field-name table per batch and positional
observation/metadata/RSSI value lists. Preserve explicit RSSI-key presence, nulls and
additional fields; retain version and ordered frame references. Its encoder must build
rows directly from each input record, without first building the identity-only map.
All row reconstruction and grouping CPU remains included in the measured paths.

### Private dictionary-model probe

REQ-005 e REQ-006: estender somente o probe privado já executado por F4-01. Recomendação: schema3 com arrays e dicionários locais ao batch. Por quê: strings e blocos completos podem repetir entre observações sem permitir descartar observações. Alternativa considerada: referenciar estados anteriores ou aplicar deltas, descartada porque acrescenta dependência temporal e dificulta provar conservação integral. Nenhum canal, endpoint, status code ou contrato público muda; Car Media não é reconstruído nem substituído.

#### Dictionary data contract

O envelope versionado `schemaVersion=3` conserva as tabelas de campos já usadas pelo schema2, uma vez por batch. O conteúdo usa as keys privadas abaixo:

| Elemento | Forma e reconstrução |
|---|---|
| `strings` | Array local ao batch com strings UUID, proximity e firmwareVersion; referências são índices Int não negativos. A mesma string pode ser compartilhada entre papéis; null permanece null. |
| `metadata` | Array de rows completos `[firmwareVersionRef, batteryLevel, movements, temperature, txPower, rssiFromBLE, isConnectable, extraFields]`. Null metadata usa null na observação; não cria uma row incompleta. |
| `rssiSamples` | Array de rows completos `[count, min, max, avg, stdDev, firstSeen, lastSeen, extraFields]`; todas as medidas e timestamps mantêm valores e tipos originais. |
| `beacons` | Array de `[uuidRef, major, minor, observations]`; identidade completa é `(uuid, major, minor)`, com igualdade tipada. |
| Observation rows | Array de `[rssi, proximityRef, accuracy, timestamp, metadataRef, txPower, alreadySynced, syncedAt, isStale, rssiRaw, rssiSamplesPresent, rssiSamplesRef, extraFields]`. Cada ocorrência ganha sua row, mesmo se inteiramente igual a outra. |
| `frames` | Array de frames; cada frame é um array ordenado de `[beaconIndex, observationIndex]`. Frame vazio fica `[]`; referências duplicadas de identidade conservam ocorrências e posição. |
| Extra fields | Mapas de campos adicionais de observação, metadata e stats permanecem integrais no slot próprio; valores null e tipos aninhados são conservados. |

Construir rows diretamente do input, reutilizando as listas de campos de `PhysicalModelProbe.kt`. Dicionários usam a igualdade dos valores completos e tipados, incluindo extras; não usar `toString`, JSON serializado ou chave por concatenação. O índice de busca deve resolver colisões por igualdade, e suas chaves não podem apontar para dados mutáveis alterados depois da inserção. Mudança em qualquer campo, tipo ou extra cria uma entrada distinta. Não deduplicar observações, converter números, arredondar, gerar médias ou transformar timestamps em deltas.

Restaurar o mapa original depois do codec, com mapas metadata/stats novos por observação para impedir aliases mutáveis entre resultados. `rssiSamplesPresent=false` omite a chave; `true` com referência null restaura a chave com valor null; `true` com índice restaura a row completa. Null metadata, txPower, rssiRaw e syncedAt permanecem null. Slots de firmware/proximity usam índices somente quando o valor é String, conservando null sem coerção. Formas de row, versão e limites de índices são validados antes do uso; referência inválida ou campo obrigatório ausente aborta o QA, sem descarte parcial.

`PhysicalModelProbe(context, packedRows=false, dictionaryRows=false)` preserva os modos existentes. `MainActivity` aceita `--ez dictionary_rows true`, que implica `packed_rows=true`, no modo privado `model_probe_only`; usa o worker e a gravação atômica existentes.

#### Direct paired protocol

A é packing schema2 + StandardMethodCodec + reconstrução schema2; B é packing schema3 + o mesmo codec + reconstrução schema3. Executar ambos no mesmo worker thread e APK. O baseline não pode ser o batch original sem packing, nem resultado de uma execução histórica. Construir input fora da região CPU e usar os mesmos objetos golden e contagem de operações em A/B.

Conservar os nove casos atuais de `frames`: tamanhos 1/6/50 e 1/10/100 frames, inclusive metadata variável, timestamps absolutos e ordem alternada. `fixtureProfile=changingMetadata` identifica esses casos. Acrescentar `repeatedBlocks` e `uniqueBlocks`, ambos 6 beacons por 100 frames. No primeiro, blocos completos de metadata/RSSI se repetem; no segundo, metadata já variável e stats com firstSeen/lastSeen/count variáveis tornam os blocos distintos por observação. Não exigir firmware artificialmente variável. O perfil distingue casos com tamanhos iguais. A/B recebem exatamente a mesma composição dentro de cada cenário; nenhum valor é simplificado para favorecer o dicionário.

Usar `operations=maxOf(1,1000/(size*count))` e `warmup=maxOf(20,operations/10)`, como no probe atual. Aquecer A/B igualmente; executar três ciclos `[A,B,B,A]` por caso. Onze casos por doze rodadas geram 132 rodadas por processo; dois processos novos e independentes geram 264 rodadas. Não fazer GC forçado entre variantes. Root controla a instalação e os processos por ADB.

`encodeCpuNs` inclui packing e encode de cada representação; `decodeCpuNs` inclui decode e reconstrução; `roundTripCpuNs` é a soma. Golden é comparado após a região CPU a cada operação, inclusive warm-up. Wall time e deltas de `art.gc.bytes-allocated`/GC incluem validação e atividade concorrente do processo; não representam alocação isolada nem RAM retida. Registrar métrica indisponível como null, nunca zero.

#### Dictionary test and report contract

REQ-006: antes das medições, exercitar ambos os modelos com frames vazios, identidade duplicada, ordem invertida, campos null, RSSI omitido e RSSI presente-null. Acrescentar extras em observação/metadata/stats, strings de hash colidente, identidades distintas que colidiriam numa concatenação ingênua e rows iguais nos campos conhecidos mas diferentes nos extras. Confirmar entradas distintas para metadata/stats/strings que mudam e reconstrução tipada integral em todos os controles. Igualdade de mapas verifica tipos/valores; listas verificam sequência e duplicatas. Falha de qualquer controle ou operação impede `status=success`.

REQ-005: conservar `variant=baseline|prototype`, `operations`, `encodedBytes`, `encodeCpuNs`, `decodeCpuNs`, `roundTripCpuNs`, `wallNs`, `processAllocatedBytes`, `gcCount` e `goldenEqual` por rodada. Resultado identifica `modelSchemaVersion=3` e `baselineModelSchemaVersion=2`, além de `fixtureProfile`, tamanho, frames, observações, ciclo/ordem, warm-up, source/APK hashes, ambiente e controles. `originalPayloadEncodedBytes` é calculado por caso fora do timing, somente para reconciliar tamanho; não mede CPU contra o payload original. Preservar exemplos dos dois modelos e todas as rodadas. O validador exige exatamente dois processos, 132 rodadas em cada, pares com cargas iguais, ordem ABBA, versões corretas e golden verdadeiro.

O relatório privado compara apenas pares novos schema2/schema3 e mostra bytes, CPU, alocação, dispersão e diferenças por processo/cenário. Repeated-blocks mede a oportunidade de compartilhamento; unique-blocks e entradas pequenas são contraprovas obrigatórias. Concluir separadamente sobre tamanho codificado e custo de CPU/alocação, sem pressupor melhora universal. Medições F4 são contexto histórico, não denominador. CPU aqui não cobre scanner, engine Flutter, Dart, rede, frames, bateria ou certificação de ANR. A validação física de F5 e seus limites são acrescentados a `physical-validation.md` pelo root.

REQ-001 a REQ-004: `BeaconBridgeRegressionTest` usa ambos os plugins reais e looper pausado. Casos: sem sink com lista que denuncia leitura e sem mensagem pendente; listas vazias; 1/6/50 com metadata/stats; nulls e chave stats omitida; async antes/depois da drenagem; entrega ordenada de callbacks consecutivos; cancelamento antes da entrega; reassinatura antes de drenar; callbacks sem sink entre assinaturas e próximo callback entregue. A comparação com publicado cobre payload e lifecycle; assertiva zero leitura é exclusiva do candidato.

Preparar harness/testes primeiro. Rodar contra source-set candidato ainda intocado e guardar RED real de REQ-001, confirmando que regressões assinadas passam. Adicionar guard e rodar GREEN, seguido da compilação Kotlin real. Não reescrever a expectativa para esconder a diferença. Baseline Dart informado pelo executor: 36 testes de API/modelo passaram; a alteração é somente Kotlin.

REQ-004 e REQ-005: `BridgeBenchmarkTest` executa protocolo e valida controles de carga e equivalência. Não criar assertions de timing instável. `run.sh regression`, `run.sh benchmark <absolute-json-output>` e `run.sh compile` selecionam, respectivamente, `BeaconBridgeRegressionTest`, `BridgeBenchmarkTest` e compilação do source-set Kotlin real. Resultado explícito não depende de varrer diretório de testes.

REQ-001 a REQ-003: uma única tarefa E2E opcional na última wave confirma stream no host Android físico, quando Samsung reconectar, com e sem assinatura, cancelamento/reassinatura, payload completo e ausência de crash. Playwright não se aplica. Executor controla artefatos e mantém native 3.14 em ambos. Documentar aparelho, artefatos e limites; não extrapolar host benchmark para CPU total, ANR ou bateria. Hardware ausente permite registrar deferimento sem bloquear F2-01.

## Report contract

REQ-005: `benchmark-report.md` abre com resultado medido e veredito do mecanismo. Comparar A/B em tabela por modo e tamanho, incluindo razão, CPU/wall/alocação suportadas, contagens, dispersão e métricas ausentes. Nomear plugins/commits e providers; reconciliar o ganho localizado com a ausência de medição física pareada. A segunda evidência é o controle assinado que poderia revelar perda de eventos ou payload, junto às leituras independentes.

Método e caminhos dos JSONs entram ao final. Informar explicitamente que EventSink nativo não mede codec/engine/renderização Dart e que o A16 ausente limita cobertura física. Não prometer redução de ANR, bateria ou CPU do aplicativo.

## File-structure plan

| Arquivo | Ação/owner |
|---|---|
| `android/src/main/kotlin/com/example/bearound_flutter_sdk/BearoundFlutterSdkPlugin.kt` | F1-01: guard antes de map/post, preservando caminho assinado. |
| `tools/bridge-benchmark/settings.gradle.kts`, `build.gradle.kts` | F1-01: projeto isolado, pinned runtime/deps, source-sets reais, geração e hashes. |
| `tools/bridge-benchmark/.gitignore`, `README.md`, `run.sh` | F1-01: outputs ignorados, comandos e runner reproduzível. |
| `tools/bridge-benchmark/src/test/kotlin/com/example/bearound_flutter_sdk/BridgeFixture.kt` | F1-01: modelos reais, contadores, sink e looper. |
| `tools/bridge-benchmark/src/test/kotlin/com/example/bearound_flutter_sdk/BeaconBridgeRegressionTest.kt` | F1-01: regressão real e RED/GREEN. |
| `tools/bridge-benchmark/src/test/kotlin/com/example/bearound_flutter_sdk/BridgeBenchmarkTest.kt` | F1-01: protocolo equal-load e emissão JSON. |
| `tools/bridge-benchmark/summarize.py` | F2-01, executor principal: validar schema/cargas e preparar tabelas sem excluir rodadas. |
| `docs/specs/flutter-unobserved-beacon-events/benchmark-report.md` | F2-01, executor principal: resultados e limites. |
| `tools/bridge-benchmark/e2e/physical-check.sh` | F3-01 opcional, executor principal: procedimento/captura Android reproduzível. |
| `docs/specs/flutter-unobserved-beacon-events/physical-validation.md` | F3-01 opcional, executor principal: execução ou deferimento documentado. |
| `tools/bridge-benchmark/e2e/physical-app/src/main/kotlin/io/bearound/qa/bridge/PhysicalModelProbe.kt` | F5-01, root: rows/dicionários schema3, baseline schema2 direto, controles e 132 rodadas por processo. |
| `tools/bridge-benchmark/e2e/physical-app/src/main/kotlin/io/bearound/qa/bridge/MainActivity.kt` | F5-01, root: selecionar novo modo privado por intent, mantendo os modos anteriores. |
| `tools/bridge-benchmark/README.md` | F5-01, root: construção e operação reproduzível da comparação direta. |
| `docs/specs/flutter-unobserved-beacon-events/physical-validation.md` | F5-01, root: nova evidência pareada e limites, preservando histórico F3/F4. |

O source-set gerado fica em `tools/bridge-benchmark/build/generated/published`, fora do git. JSONs brutos e evidência de execução ficam em diretório QA escolhido explicitamente pelo executor; referência no relatório, fora dos fingerprints do engine. Nenhuma escrita em Android build.gradle, iOS, modelos nativos, versão ou state/ledger pela implementação F1-01.

## Execution boundaries

Três waves sequenciais: um worker entrega guard/harness/regressões; executor consome o harness para benchmark/report; executor faz ou defere a verificação física opcional. F2-01 depende de F1-01 validado. F3-01 não segura o experimento controlado aberto quando hardware falta. Todas as REQs são obrigatoriamente provadas por F1-01/F2-01; hardware acrescenta cobertura.

F1-01 a F4-01 já estão concluídas e conservam seus registros. A extensão acrescenta somente F5-01, obrigatório e sequencial após F4-01. Root possui os quatro arquivos git listados para F5 e toda operação de aparelho. Fora do git, root adapta o controller QA existente `physical_model_run.py` e cria `dictionary_model_report.py`; JSONs, APK e relatórios ficam no diretório QA existente. Esses artefatos não entram no write-set git nem são editados pelo planner. O novo experimento não autoriza integração em produção, migração, dependências, publicação ou alteração em Car Media.
