# Bugfix: eventos Android sem observador

Experimento fast autorizado, limitado ao callback Android da ponte Flutter. Decisões de `decisions.md` são entradas resolvidas. Preservar o trabalho de outros agentes; executor principal controla estado, QA e aparelho.

### REQ-001: Omitir trabalho sem assinante

Atual: WHEN não existe beacon sink THEN a ponte percorre beacons, monta mapas e agenda entrega sem destinatário.

Esperado: WHEN o beacon sink está ausente na entrada THEN a ponte SHALL retornar antes de ler beacons, mapear ou postar.

Preservado: WHEN o SDK detecta beacons THEN o SDK SHALL CONTINUE TO executar seu fluxo nativo.

- [ ] Lista instrumentada registra zero acessos e looper não tem entrega pendente.
- [ ] Listas vazias e tamanhos 1, 6 e 50 obedecem ao guard.
- [ ] Teste falha antes do guard e passa depois.

### REQ-002: Conservar entrega assinada

Atual: WHEN existe assinante THEN a ponte mapeia a lista e posta um evento por callback.

Esperado: WHEN existe assinante THEN a ponte SHALL preservar payload completo, ordem e quantidade de eventos publicados.

Preservado: WHEN entrega o evento THEN a ponte SHALL CONTINUE TO postar assincronamente no main handler.

- [ ] Entrega depende de drenar o looper.
- [ ] Baseline e candidato entregam mapas iguais, inclusive metadata, RSSI stats, sync e nulls opcionais.
- [ ] Lista vazia entrega `beacons=[]`; ausência de stats conserva omissão da chave.
- [ ] Callbacks assinados não têm throttle.

### REQ-003: Preservar consulta ao sink vivo

Atual: WHEN executa runnable THEN consulta o sink atual.

Esperado: WHEN assinatura muda após postagem THEN a ponte SHALL consultar o sink atual.

Preservado: WHEN cancela ou detach THEN a ponte SHALL CONTINUE TO limpar o sink.

- [ ] Cancelamento antes de drenar impede entrega ao sink antigo.
- [ ] Cancelar e reassinar antes de drenar entrega ao sink atual, como no publicado.
- [ ] Callback ocorrido sem sink não fica pendente; nova assinatura recebe callbacks seguintes normalmente.
- [ ] Guard não captura sink na lambda nem altera lifecycle.

### REQ-004: Baseline fixo com código real

Atual: WHEN faltam testes Android THEN não há controle executável do callback publicado.

Esperado: WHEN valida a mudança THEN o harness SHALL compilar callback publicado e candidato reais com native SDK 3.14.0.

Preservado: WHEN prepara o harness THEN a produção SHALL CONTINUE TO usar suas dependências e configuração Gradle.

- [ ] Baseline vem do commit fixo, com hash original registrado; geração muda classe e pontuação de comentários somente.
- [ ] Nenhuma cópia extensa do baseline fica versionada.
- [ ] Harness usa Gradle 8.13, AGP 8.11.1, Kotlin 2.1, Robolectric 4.13 e JUnit4.

### REQ-005: Comparar carga equivalente e delimitar resultado

Atual: WHEN metadata difere THEN a comparação física anterior não isola a otimização.

Esperado: WHEN mede a ponte THEN o executor SHALL igualar fixtures/callbacks e usar aquecimento/ABBA.

Preservado: WHEN publica resultados THEN o executor SHALL CONTINUE TO distinguir medição da ponte de consumo total do aplicativo.

- [ ] Tamanhos 1, 6 e 50 têm metadata/stats fixos e mesmas contagens em A/B.
- [ ] Registrar CPU da thread, tempo, alocações suportadas, leituras e entregas independentes.
- [ ] Relatório inclui hashes, dispersão e métricas indisponíveis; não extrapola para ANR ou bateria.

### REQ-006: Dicionários privados e comparação direta

Atual: WHEN usa schema2 THEN o probe repete strings/blocos nas observações.

Esperado: WHEN mede schema3 THEN o probe SHALL reconstruir golden integral e comparar schema2 no mesmo APK.

Preservado: WHEN executa QA privado THEN o sistema SHALL CONTINUE TO preservar SDK público, protocolo e Car Media.

- [ ] Golden tipado por operação preserva números/timestamps absolutos, nulls, omissões RSSI, extras, colisões, duplicatas e ordem.
- [ ] Onze casos, warm-up igual e três ABBA por processo retêm 264 rodadas em dois processos.
- [ ] CPU inclui packing/codec/reconstrução de ambos; bytes/alocação não inferem RAM retida.

## Assumptions

- Baseline é o tag Flutter `v3.14.0`, commit `4f61d32d47b96cd16de0464c3f04f4aaea5d8a50`; native permanece `v3.14.0` em ambos os lados.
- O executor confirmou baseline Dart de 36 testes direcionados, todos verdes.
- O deferimento por Samsung ausente era permitido em F3-01. F3/F4 já foram executadas no Samsung conectado; F5-01 é o follow-up privado obrigatório em dois processos.
- O harness host captura `EventSink` nativo; não mede codec Flutter, engine ou renderização Dart. O probe privado físico mede StandardMethodCodec em ART, sem engine ou Dart.

## Open questions

- Nenhuma decisão de produto aberta. O usuário delegou a arquitetura privada ao planner; F3/F4 resolveram disponibilidade do Samsung e medição em ART. Métricas indisponíveis continuam registradas explicitamente, conforme REQ-005.

## Unchanged behavior

- APIs públicas, canais e handlers listen/cancel/detach.
- Payload, ordem, cadência e entrega assíncrona para assinantes.
- Consulta ao sink atual na entrega de eventos já postados.
- Detecção nativa, metadata, RSSI, sync e native SDK 3.14.0.
- Gradle Android de produção, dependências de produção e versão do pacote.
- iOS, armazenamento diagnóstico, payload de rede e publicação.
- Car Media e o APK instalado pelo usuário; os modelos novos ficam somente no QA isolado.
