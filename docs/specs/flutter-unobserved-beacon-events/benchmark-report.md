# 99,94% menos alocação sem assinante no caso de 6 beacons; ganho localizado confirmado

O guard elimina leituras e mensagens sem consumidor na ponte Android do Flutter. A performance com assinante ainda exige validação física: o benchmark encontrou CPU maior em parte das comparações. Não há homologação de ANR, bateria ou CPU total do Car Media nesta etapa.

## Reconciliação e participantes

A comparação anterior no Samsung recebeu aproximadamente 3 vezes mais metadata em um dos lados. Esta comparação usa exatamente a mesma carga sintética em cada versão: 12.000 callbacks por cenário/versão, após aquecimento. Os resultados da ponte não são comparáveis diretamente ao percentual de CPU do processo medido no Samsung.

| Implementação | Código | SDK nativo |
|---|---|---|
| Publicada, PublishedBearoundFlutterSdkPlugin gerada | Flutter v3.14.0, 4f61d32d47b96cd16de0464c3f04f4aaea5d8a50 | com.github.Bearound:bearound-android-sdk:v3.14.0 |
| Candidata, BearoundFlutterSdkPlugin real | b1d345b12e627aff3f071fbd3df53559781df8ab; uma saída antecipada antes de map/post | Mesma coordenada 3.14.0 |

## Contagens que independem do timing

| Beacons por callback | Modo | Callbacks por versão | Leituras publicada → candidata | Mensagens publicada → candidata | Entregas publicada → candidata |
|---:|---|---:|---:|---:|---:|
| 1 | sem assinante | 12000 | 12000 → 0 | 12000 → 0 | 0 → 0 |
| 1 | com assinante | 12000 | 12000 → 12000 | 12000 → 12000 | 12000 → 12000 |
| 6 | sem assinante | 12000 | 72000 → 0 | 12000 → 0 | 0 → 0 |
| 6 | com assinante | 12000 | 72000 → 72000 | 12000 → 12000 | 12000 → 12000 |
| 50 | sem assinante | 12000 | 600000 → 0 | 12000 → 0 | 0 → 0 |
| 50 | com assinante | 12000 | 600000 → 600000 | 12000 → 12000 | 12000 → 12000 |

No cenário sem assinante de 6 beacons, 72.000 leituras e 12.000 mensagens desnecessárias caíram para zero. Com assinante, ambos entregaram 12.000 eventos nesse cenário. Os checksums coincidem e os testes comparam payloads completos com valores esperados, incluindo metadata, RSSI stats, nulls e ordem.

## Medianas por callback da região instrumentada

Valores agregados dos dois processos. CPU/tempo em microssegundos, alocação em bytes. O overhead dos probes permanece nos números. Não somar ou interpretar esses valores como consumo do aplicativo.

| Beacons | Modo | CPU publicada → candidata (µs) | Tempo publicado → candidata (µs) | Alocação publicada → candidata (B) |
|---:|---|---:|---:|---:|
| 1 | sem assinante | 10.021 → 0.248 | 14.311 → 0.287 | 3459.632 → 10.048 |
| 1 | com assinante | 7.865 → 7.497 | 10.014 → 12.912 | 3507.328 → 3507.328 |
| 6 | sem assinante | 12.917 → 0.089 | 23.651 → 0.082 | 16822.208 → 9.568 |
| 6 | com assinante | 11.428 → 11.646 | 15.684 → 15.473 | 17085.568 → 17085.636 |
| 50 | sem assinante | 55.579 → 0.057 | 88.361 → 0.054 | 134541.568 → 9.568 |
| 50 | com assinante | 83.636 → 87.371 | 101.860 → 148.311 | 136941.088 → 136941.088 |

Os cerca de 10 bytes residuais sem assinante incluem a instrumentação do benchmark. Esta medida não afirma que o guard isolado aloca 10 bytes.

## Controle que poderia contradizer o ganho

Com assinante, a alocação permaneceu praticamente igual, mas o timing não provou ausência de regressão. No caso de 6 beacons, a CPU mediana foi maior nas duas execuções. A segunda execução foi motivada por esse resultado; nenhuma rodada foi excluída.

| Beacons com assinante | CPU B/A, execução 1 | CPU B/A, execução 2 | CPU B/A, mediana dos ciclos pareados |
|---:|---:|---:|---:|
| 1 | +13.2% | -6.6% | +5.4% |
| 6 | +7.3% | +10.7% | +6.2% |
| 50 | -1.3% | +1.2% | +3.5% |

A coluna pareada calcula a razão entre as duas rodadas B e as duas A de cada ciclo ABBA, depois toma a mediana dos seis ciclos. É diferente da razão entre medianas agregadas de processos distintos. A dispersão e todos os ciclos permanecem nos JSONs; o HTML apresenta os pontos de CPU para 6 beacons com e sem assinante.

## Implementado e validado

- Produção: somente `if (beaconsEventSink == null) return`, antes da construção do payload. Caminho assinado, formato e versão mantidos.
- Native regressions: RED 8/10 antes do guard, falhas exatamente nos dois controles sem assinante; GREEN 10/10 depois. Inclui vazio/1/6/50, entrega assíncrona, valores completos, ordem, cancelamento e reassinatura.
- Benchmark: dois testes de benchmark verdes em processos independentes, 144 rodadas, 144.000 callbacks medidos e 120.000 callbacks de aquecimento.
- Compilação Kotlin do callback real e fixtures: passou. Flutter baseline: 36 testes direcionados passaram, análise estática sem apontamentos, fonte Dart inalterada.
- Testes físicos desta candidata: não executados; Samsung ausente do ADB. F3-01 permanece opcional e não marcado.
- Perfil fast: suíte completa e revisão independente não executadas. Nenhum pacote publicado.

## Limites e recomendação

Recomendação: manter a candidata em rascunho e validar no Samsung antes de aprovar a release. Por quê: o mecanismo sem assinante foi demonstrado, mas o timing do caminho assinado apresentou possível custo adicional. Alternativa considerada: publicar com base apenas na redução de alocação, descartada porque esse resultado não cobre a performance com consumidor nem ANR do host.

A medição exclui rádio BLE, GPS, ingestão/HTTP, Flutter codec/engine/JNI, renderização Dart, frames, Doze, bateria e processo encerrado. Não implementamos armazenamento incremental de diagnóstico nem nova estrutura de payload de rede. Modelos e RSSI são sintéticos fixos; não é uma medição de tráfego real.

## Método e evidência

Java 17.0.19, OpenJDK aarch64, macOS 26.5.2, Robolectric 4.13/API34, Gradle8.13, AGP8.11.1/Kotlin2.1. O EventSink é uma fronteira de captura nativa; sem Flutter engine. A drenagem ocorreu na mesma thread medida. CPU e bytes alocados vieram dos MXBeans públicos do Java17, com reflexão nos probes; nenhuma métrica ficou indisponível.

Duas execuções independentes, três ciclos ABBA por modo/tamanho em cada processo. Cada implementação/cenário recebeu 5.000 callbacks de aquecimento por processo. Cada rodada mediu 1.000 callbacks em batches limitados a 25. Construção de fixtures e IO fora da região; contadores, inspeção real da fila, checksum e probes dentro. Capturamos GC e mantivemos todas as rodadas. Tabelas de contagens excluem aquecimento e regressões.

Baseline gerado diretamente do commit publicado fixo, somente classe renomeada e pontuação de comentários normalizada. Hash original conferido contra o cache pub.dev. Nenhuma cópia extensa do baseline foi versionada.

| Evidência | SHA-256 |
|---|---|
| publishedOriginal | 7d4fbbc13e6dc0ae1eced82576d50e9da18a798618d2320ef1f3ee0e0d94d270 |
| publishedGenerated | 9251ba46288ad16870206206c51151d8b5b031fc9c465b47832c66922e3875c4 |
| candidate | 2602a1c7b05e73074707565a8a8468b37607a9a4d8b23d084a643f4d5af136f8 |
| JSON combinado das 144 rodadas | a1a8d6c03da782b62ebf36bb2a556cb3c35a93842ff5d9664bc3e448fe187c35 |

Artefatos locais: `/Users/jotta/Documents/bearound/qa/sdk-performance-20261007/flutter-stream-experiment/`. `benchmark-first-run-raw.json` e `benchmark-replication-raw.json` preservam saídas originais; `benchmark-raw.json` reúne as rodadas com identificação de processo. `verified-summary.json` contém min/max, medianas, ciclos, contagens e GC. `native-regression-red.xml`/`native-regression-green.xml` guardam a reprodução. `report.html` é o relatório estático, conferido por parsing e links; não houve renderização no browser.

Reprodução:

```bash
bash tools/bridge-benchmark/run.sh regression
bash tools/bridge-benchmark/run.sh compile
bash tools/bridge-benchmark/run.sh benchmark /absolute/path/run.json
python3 tools/bridge-benchmark/summarize.py /absolute/path/run.json --output /absolute/path/summary.json
```

Runtime e launcher externos podem ser configurados pelos parâmetros documentados em `tools/bridge-benchmark/README.md`. O projeto Gradle do harness é isolado da configuração Android publicada.
