library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'src/core/permission_service.dart';
import 'src/models/active_scan_event.dart';
import 'src/models/authorization_status.dart';
import 'src/models/background_detection_event.dart';
import 'src/models/beacon.dart';
import 'src/models/beacon_region_event.dart';
import 'src/models/bearound_error.dart';
import 'src/models/bluetooth_events.dart';
import 'src/models/foreground_scan_config.dart';
import 'src/models/persisted_log_entry.dart';
import 'src/models/scan_interval_configuration.dart';
import 'src/models/sync_lifecycle_event.dart';
import 'src/models/user_properties.dart';

export 'src/models/active_scan_event.dart';
export 'src/models/authorization_status.dart';
export 'src/models/background_detection_event.dart';
export 'src/models/beacon.dart';
export 'src/models/beacon_discovery_source.dart';
export 'src/models/beacon_metadata.dart';
export 'src/models/beacon_region_event.dart';
export 'src/models/bearound_error.dart';
export 'src/models/bluetooth_events.dart';
export 'src/models/foreground_scan_config.dart';
export 'src/models/persisted_log_entry.dart';
export 'src/models/rssi_stats.dart';
export 'src/models/scan_interval_configuration.dart';
export 'src/models/sync_lifecycle_event.dart';
export 'src/models/user_properties.dart';

/// SDK principal do Bearound para integração com os SDKs nativos (Android/iOS —
/// versões pinadas em `android/build.gradle` e `ios/bearound_flutter_sdk.podspec`).
///
/// A interface Dart é o superconjunto das APIs nativas iOS e Android. Métodos
/// disponíveis apenas em uma plataforma são no-op silenciosos na outra, e
/// streams iOS-only (Bluetooth zone/scan mode) nunca emitem na plataforma
/// errada.
class BearoundFlutterSdk {
  BearoundFlutterSdk._();

  static const MethodChannel _channel = MethodChannel('bearound_flutter_sdk');

  // --- Event channels ---
  static const EventChannel _beaconsChannel = EventChannel(
    'bearound_flutter_sdk/beacons',
  );
  static const EventChannel _scanningChannel = EventChannel(
    'bearound_flutter_sdk/scanning',
  );
  static const EventChannel _errorChannel = EventChannel(
    'bearound_flutter_sdk/errors',
  );
  static const EventChannel _syncLifecycleChannel = EventChannel(
    'bearound_flutter_sdk/sync_lifecycle',
  );
  static const EventChannel _backgroundDetectionChannel = EventChannel(
    'bearound_flutter_sdk/background_detection',
  );
  static const EventChannel _beaconRegionChannel = EventChannel(
    'bearound_flutter_sdk/beacon_region',
  );
  static const EventChannel _activeScanChannel = EventChannel(
    'bearound_flutter_sdk/active_scan',
  );
  // v2.5 — Bluetooth "two eyes" (iOS-only) + adapter state (both platforms).
  static const EventChannel _bluetoothZoneChannel = EventChannel(
    'bearound_flutter_sdk/bluetooth_zone',
  );
  static const EventChannel _bluetoothScanModeChannel = EventChannel(
    'bearound_flutter_sdk/bluetooth_scan_mode',
  );
  static const EventChannel _bluetoothStateChannel = EventChannel(
    'bearound_flutter_sdk/bluetooth_state',
  );

  static Stream<List<Beacon>>? _beaconsStream;
  static Stream<bool>? _scanningStream;
  static Stream<BearoundError>? _errorStream;

  /// Ring buffer of errors emitted by the native SDK *before* any Dart listener
  /// attached to [errorStream]. Bounded to [_errorReplayBufferSize]; replayed
  /// once to the first listener, then cleared. See [errorStream].
  static final List<BearoundError> _bufferedErrors = <BearoundError>[];
  static const int _errorReplayBufferSize = 16;
  static bool _errorBufferSubscribed = false;
  static bool _errorBufferReplayed = false;
  static Stream<SyncLifecycleEvent>? _syncLifecycleStream;
  static Stream<BackgroundDetectionEvent>? _backgroundDetectionStream;
  static Stream<BeaconRegionEvent>? _beaconRegionStream;
  static Stream<ActiveScanEvent>? _activeScanStream;
  static Stream<BluetoothZoneEvent>? _bluetoothZoneStream;
  static Stream<BluetoothScanModeEvent>? _bluetoothScanModeStream;
  static Stream<BluetoothState>? _bluetoothStateStream;

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Solicita as permissões necessárias para operação do SDK.
  /// No iOS, chama `requestAlwaysAuthorization()` via código nativo.
  /// No Android, usa `permission_handler` para solicitar permissões.
  static Future<bool> requestPermissions() =>
      PermissionService.instance.requestPermissions();

  /// Verifica se as permissões necessárias foram concedidas.
  static Future<bool> checkPermissions() =>
      PermissionService.instance.checkPermissions();

  /// Solicita autorização de localização no nível pedido. **iOS-only** —
  /// destrava o "olho de Location" (wake-up de app encerrado com `always`).
  /// Android: no-op; use [requestPermissions] para permissões em runtime.
  static Future<void> requestLocationAuthorization({
    LocationAuthorizationLevel level = LocationAuthorizationLevel.always,
  }) async {
    await _channel.invokeMethod('requestLocationAuthorization', level.value);
  }

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Configura o SDK nativo antes de iniciar o scan.
  ///
  /// O [businessToken] é obrigatório para autenticação.
  ///
  /// O [scanPrecision] controla o duty cycle de scan BLE/CoreLocation. O
  /// default é `ScanPrecision.high` — alinhado ao SDK iOS nativo, que prioriza
  /// detecção contínua.
  ///
  /// O [maxQueuedPayloads] configura o tamanho da fila de retry para falhas de
  /// API (padrão: `medium` = 100 batches).
  static Future<void> configure({
    required String businessToken,
    ScanPrecision scanPrecision = ScanPrecision.high,
    MaxQueuedPayloads maxQueuedPayloads = MaxQueuedPayloads.medium,
  }) async {
    if (businessToken.trim().isEmpty) {
      throw ArgumentError.value(
        businessToken,
        'businessToken',
        'Business token cannot be empty',
      );
    }

    final args = <String, dynamic>{
      'businessToken': businessToken.trim(),
      'scanPrecision': scanPrecision.value,
      'maxQueuedPayloads': maxQueuedPayloads.value,
    };

    await _channel.invokeMethod('configure', args);
  }

  // ---------------------------------------------------------------------------
  // Scanning lifecycle
  // ---------------------------------------------------------------------------

  /// Inicia o scan de beacons após `configure()`.
  ///
  /// Android — dois modos (veja "Scan modes" no README):
  /// - **Oportunista (default):** chame sem [foregroundScanConfig]. Scan em
  ///   background via PendingIntent/AlarmManager, sem foreground service e sem
  ///   vídeo no Google Play. Latência imprevisível; pode não sobreviver a OEMs
  ///   agressivos (Xiaomi/Huawei).
  /// - **Foreground service:** passe [foregroundScanConfig] (ou chame depois
  ///   [enableForegroundScanning]). Scan contínuo que sobrevive ao app fechado;
  ///   exige a permissão `FOREGROUND_SERVICE_CONNECTED_DEVICE` + vídeo no Play.
  ///
  /// No iOS, [foregroundScanConfig] é ignorado (scan gerenciado pelo sistema).
  static Future<void> startScanning({
    ForegroundScanConfig? foregroundScanConfig,
  }) async {
    final args = foregroundScanConfig != null
        ? {'foregroundScanConfig': foregroundScanConfig.toJson()}
        : null;
    await _channel.invokeMethod('startScanning', args);
  }

  /// Para o scan de beacons.
  static Future<void> stopScanning() async {
    await _channel.invokeMethod('stopScanning');
  }

  /// Retorna se o SDK está escaneando.
  static Future<bool> isScanning() async {
    final result = await _channel.invokeMethod<bool>('isScanning');
    return result ?? false;
  }

  // ---------------------------------------------------------------------------
  // Background reliability (Android-only: Doze + OEM battery killers)
  // ---------------------------------------------------------------------------

  /// Se o app já está isento da otimização de bateria (Doze) do Android.
  /// Android-only; retorna `true` no iOS (não há essa restrição).
  static Future<bool> isIgnoringBatteryOptimizations() async {
    final result = await _channel.invokeMethod<bool>(
      'isIgnoringBatteryOptimizations',
    );
    return result ?? false;
  }

  /// Abre a tela de Settings de otimização de bateria para o usuário isentar o
  /// app — melhora a sobrevivência do scan em background sob Doze. Usa a tela de
  /// Settings (sem a permissão restrita `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`),
  /// então não dispara revisão do Google Play. Android-only; `false` (no-op) no
  /// iOS. Retorna `true` se conseguiu abrir a tela.
  static Future<bool> openBatteryOptimizationSettings() async {
    final result = await _channel.invokeMethod<bool>(
      'openBatteryOptimizationSettings',
    );
    return result ?? false;
  }

  /// Se o device é de um OEM com tela de autostart/apps-protegidos conhecida
  /// (Xiaomi/Huawei/Oppo/Vivo/OnePlus/Letv). Android-only; `false` no iOS e no
  /// Android stock (Pixel).
  static Future<bool> isAutostartManageable() async {
    final result = await _channel.invokeMethod<bool>('isAutostartManageable');
    return result ?? false;
  }

  /// Abre a tela de autostart/apps-protegidos do fabricante, quando existe —
  /// mitiga OEMs que matam o processo em background mesmo no Android 14+.
  /// Android-only; `false` em stock/OEM não mapeado ou no iOS.
  static Future<bool> openManufacturerAutostartSettings() async {
    final result = await _channel.invokeMethod<bool>(
      'openManufacturerAutostartSettings',
    );
    return result ?? false;
  }

  // ---------------------------------------------------------------------------
  // User properties
  // ---------------------------------------------------------------------------

  /// Define propriedades do usuário associadas aos eventos de beacon.
  static Future<void> setUserProperties(UserProperties properties) async {
    await _channel.invokeMethod('setUserProperties', properties.toJson());
  }

  /// Limpa as propriedades do usuário.
  static Future<void> clearUserProperties() async {
    await _channel.invokeMethod('clearUserProperties');
  }

  // ---------------------------------------------------------------------------
  // Push token
  // ---------------------------------------------------------------------------

  /// Encaminha o push token do dispositivo (FCM no Android, APNs no iOS) para o
  /// SDK nativo, que o associa ao `deviceId` e o envia no próximo sync.
  ///
  /// O app é responsável por obter o token e chamar este método:
  /// - **Android**: o FCM token (`firebase_messaging` `getToken()`).
  /// - **iOS**: o token **APNs cru** (`getAPNSToken()`), que é o que o backend
  ///   usa pra push (APNs); o FCM token NÃO serve. O SDK também tenta capturar
  ///   o APNs via swizzle do AppDelegate, mas isso falha quando o Firebase está
  ///   presente (ele intercepta o swizzle) — então prefira encaminhar manualmente.
  ///
  /// Encaminhado ao SDK nativo em ambas as plataformas — no Android desde o
  /// plugin 3.4.1 (setter disponível no SDK nativo Android ≥ 3.4.0).
  static Future<void> setPushToken(String token) async {
    await _channel.invokeMethod('setPushToken', {'token': token});
  }

  // ---------------------------------------------------------------------------
  // Diagnostic / state getters (parity with native public API)
  // ---------------------------------------------------------------------------

  /// Versão do SDK nativo. iOS retorna a versão; Android retorna `''` (o SDK
  /// Android não expõe um getter público de versão).
  static Future<String> getSdkVersion() async {
    final result = await _channel.invokeMethod<String>('getSdkVersion');
    return result ?? '';
  }

  /// Precisão de scan ativa (`'high' | 'medium' | 'low'`), ou `''` se ainda
  /// não configurada.
  static Future<String> getCurrentScanPrecision() async {
    final result = await _channel.invokeMethod<String>(
      'getCurrentScanPrecision',
    );
    return result ?? '';
  }

  /// String de diagnóstico BLE. **iOS-only**; Android retorna `''`.
  static Future<String> getBleDiagnosticInfo() async {
    final result = await _channel.invokeMethod<String>('getBleDiagnosticInfo');
    return result ?? '';
  }

  /// Número de batches em fila aguardando retry após falha de API. Funciona em
  /// **ambas** as plataformas (Android ≥ 3.4.x expõe `pendingBatchCount`).
  static Future<int> getPendingBatchCount() async {
    final result = await _channel.invokeMethod<num>('getPendingBatchCount');
    return result?.toInt() ?? 0;
  }

  /// Se `configure()` já foi chamado.
  static Future<bool> isConfigured() async {
    final result = await _channel.invokeMethod<bool>('isConfigured');
    return result ?? false;
  }

  /// Se os serviços de localização do dispositivo estão habilitados.
  static Future<bool> isLocationAvailable() async {
    final result = await _channel.invokeMethod<bool>('isLocationAvailable');
    return result ?? false;
  }

  /// Status atual da autorização de localização.
  static Future<AuthorizationStatus> getAuthorizationStatus() async {
    final result = await _channel.invokeMethod<String>(
      'getAuthorizationStatus',
    );
    return AuthorizationStatus.fromString(result);
  }

  /// Estado atual do adaptador Bluetooth. O olho Bluetooth funciona enquanto
  /// for `poweredOn`, independente da autorização de localização.
  static Future<BluetoothState> getBluetoothState() async {
    final result = await _channel.invokeMethod<String>('getBluetoothState');
    return BluetoothState.fromString(result);
  }

  // NOTE: push/notifications são app-level agora. O SDK nativo removeu a API
  // de notificações da biblioteca, então o bridge também não a expõe mais.

  // ---------------------------------------------------------------------------
  // Persistent log
  // ---------------------------------------------------------------------------

  /// Log de detecção persistido pelo SDK (sobrevive ao fechamento do app).
  /// Retorna entradas tipadas via [PersistedLogEntry].
  ///
  /// **iOS-only por ora**: o SDK nativo Android não expõe log persistido, então
  /// o Android retorna sempre lista vazia (`[]`).
  static Future<List<PersistedLogEntry>> getPersistedLog() async {
    final raw = await _channel.invokeMethod<String>('getPersistedLog') ?? '[]';
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => PersistedLogEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Versão "crua" do log persistido (lista de mapas), para consumidores que
  /// preferem renderizar JSON livre. Mantida por conveniência — prefira
  /// [getPersistedLog]. **iOS-only por ora** (Android retorna `[]`).
  static Future<List<Map<String, dynamic>>> getPersistedLogRaw() async {
    final raw = await _channel.invokeMethod<String>('getPersistedLog') ?? '[]';
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  /// Limpa o log persistido do SDK. **iOS-only por ora** (no-op no Android).
  static Future<void> clearPersistedLog() async {
    await _channel.invokeMethod('clearPersistedLog');
  }

  // ---------------------------------------------------------------------------
  // Foreground service scanning (Android-only)
  // ---------------------------------------------------------------------------

  /// Habilita o foreground service (`connectedDevice`) de scan no Android, com
  /// notificação persistente — scan contínuo que sobrevive ao app fechado e a
  /// OEMs agressivos. Exige a permissão `FOREGROUND_SERVICE_CONNECTED_DEVICE` e,
  /// no Google Play, um vídeo de demonstração. Para não exigir nada disso, use
  /// só [startScanning] (modo oportunista). iOS: no-op (BGTaskScheduler / region).
  static Future<void> enableForegroundScanning([
    ForegroundScanConfig config = const ForegroundScanConfig(),
  ]) async {
    await _channel.invokeMethod('enableForegroundScanning', config.toJson());
  }

  /// Desliga o foreground service de scan. iOS: no-op.
  static Future<void> disableForegroundScanning() async {
    await _channel.invokeMethod('disableForegroundScanning');
  }

  /// Se o foreground service está ativo. iOS resolve sempre `false`.
  static Future<bool> isForegroundScanningEnabled() async {
    final result = await _channel.invokeMethod<bool>(
      'isForegroundScanningEnabled',
    );
    return result ?? false;
  }

  /// Atualiza o conteúdo contextual da notificação do foreground service.
  /// Android-only.
  static Future<void> setForegroundNotificationContent(
    NotificationContent content,
  ) async {
    await _channel.invokeMethod(
      'setForegroundNotificationContent',
      content.toJson(),
    );
  }

  // ---------------------------------------------------------------------------
  // Event streams
  // ---------------------------------------------------------------------------

  /// Stream com a lista de beacons atualizada pelo SDK.
  static Stream<List<Beacon>> get beaconsStream {
    _beaconsStream ??= _beaconsChannel.receiveBroadcastStream().map((event) {
      final beaconsRaw = event is List ? event : _asMap(event)['beacons'];
      if (beaconsRaw is List) {
        return beaconsRaw
            .whereType<Map>()
            .map((item) => Beacon.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
      return <Beacon>[];
    });
    return _beaconsStream!;
  }

  /// Stream indicando alterações no estado de scanning.
  static Stream<bool> get scanningStream {
    _scanningStream ??= _scanningChannel.receiveBroadcastStream().map((event) {
      if (event is bool) {
        return event;
      }
      final payload = _asMap(event);
      return payload['isScanning'] as bool? ?? false;
    });
    return _scanningStream!;
  }

  /// Stream de erros reportados pelo SDK nativo.
  ///
  /// **Replay dos últimos erros:** o SDK nativo pode emitir um erro (ex.: falha
  /// de configuração/permissão logo após `startScanning`) *antes* de o app
  /// registrar o primeiro `listen()`. Sem replay esse erro se perderia para
  /// sempre. Para evitar isso, o wrapper Dart assina o canal nativo assim que
  /// [errorStream] é acessado pela primeira vez e bufferiza até
  /// [_errorReplayBufferSize] erros; o **primeiro** listener recebe esse buffer
  /// reemitido (em ordem) antes dos eventos ao vivo. Depois disso o buffer é
  /// esvaziado e os listeners subsequentes só recebem eventos novos.
  static Stream<BearoundError> get errorStream {
    _ensureErrorBufferSubscribed();

    Stream<BearoundError> withReplay() async* {
      // Replay the pre-listen buffer to the first listener only, then clear it.
      if (!_errorBufferReplayed && _bufferedErrors.isNotEmpty) {
        _errorBufferReplayed = true;
        final replayed = List<BearoundError>.from(_bufferedErrors);
        _bufferedErrors.clear();
        for (final error in replayed) {
          yield error;
        }
      } else {
        _errorBufferReplayed = true;
      }
      yield* _rawErrorStream();
    }

    _errorStream ??= withReplay().asBroadcastStream();
    return _errorStream!;
  }

  /// Native error channel mapped to [BearoundError], without any buffering.
  static Stream<BearoundError> _rawErrorStream() {
    return _errorChannel.receiveBroadcastStream().map((event) {
      if (event is String) {
        return BearoundError(message: event);
      }
      final payload = _asMap(event);
      return BearoundError.fromJson(payload);
    });
  }

  /// Eagerly subscribes to the native error channel so errors emitted before the
  /// app's first [errorStream] listener are captured into [_bufferedErrors].
  /// Idempotent.
  static void _ensureErrorBufferSubscribed() {
    if (_errorBufferSubscribed) return;
    _errorBufferSubscribed = true;
    _rawErrorStream().listen((error) {
      // Once the first real listener has consumed (and cleared) the buffer, stop
      // accumulating — live delivery takes over from there.
      if (_errorBufferReplayed) return;
      _bufferedErrors.add(error);
      if (_bufferedErrors.length > _errorReplayBufferSize) {
        _bufferedErrors.removeAt(0);
      }
    });
  }

  /// Stream do ciclo de sincronização (`started` / `completed`).
  static Stream<SyncLifecycleEvent> get syncLifecycleStream {
    _syncLifecycleStream ??= _syncLifecycleChannel.receiveBroadcastStream().map(
      (event) {
        final payload = _asMap(event);
        return SyncLifecycleEvent.fromJson(payload);
      },
    );
    return _syncLifecycleStream!;
  }

  /// Stream de detecções em background.
  static Stream<BackgroundDetectionEvent> get backgroundDetectionStream {
    _backgroundDetectionStream ??= _backgroundDetectionChannel
        .receiveBroadcastStream()
        .map((event) {
          final payload = _asMap(event);
          return BackgroundDetectionEvent.fromJson(payload);
        });
    return _backgroundDetectionStream!;
  }

  /// Stream de transições de região de beacon (`enter` / `exit`).
  static Stream<BeaconRegionEvent> get beaconRegionStream {
    _beaconRegionStream ??= _beaconRegionChannel.receiveBroadcastStream().map((
      event,
    ) {
      return BeaconRegionEvent.fromMap(_asMap(event));
    });
    return _beaconRegionStream!;
  }

  /// Stream do estado de scan ativo.
  static Stream<ActiveScanEvent> get activeScanStream {
    _activeScanStream ??= _activeScanChannel.receiveBroadcastStream().map((
      event,
    ) {
      return ActiveScanEvent.fromMap(_asMap(event));
    });
    return _activeScanStream!;
  }

  /// Stream de entradas/saídas da zona Bluetooth (CBCentralManager).
  /// **iOS-only** — no Android nunca emite.
  static Stream<BluetoothZoneEvent> get bluetoothZoneStream {
    _bluetoothZoneStream ??= _bluetoothZoneChannel.receiveBroadcastStream().map(
      (event) {
        return BluetoothZoneEvent.fromMap(_asMap(event));
      },
    );
    return _bluetoothZoneStream!;
  }

  /// Stream de mudanças do duty-cycle do scanner Bluetooth (`idle` / `active`).
  /// **iOS-only** — no Android nunca emite.
  static Stream<BluetoothScanModeEvent> get bluetoothScanModeStream {
    _bluetoothScanModeStream ??= _bluetoothScanModeChannel
        .receiveBroadcastStream()
        .map((event) {
          return BluetoothScanModeEvent.fromMap(_asMap(event));
        });
    return _bluetoothScanModeStream!;
  }

  /// Stream do estado do adaptador Bluetooth (poweredOn/off/unauthorized/...).
  /// Emite em ambas as plataformas — use para destravar o olho Bluetooth.
  static Stream<BluetoothState> get bluetoothStateStream {
    _bluetoothStateStream ??= _bluetoothStateChannel
        .receiveBroadcastStream()
        .map((event) {
          if (event is String) {
            return BluetoothState.fromString(event);
          }
          final payload = _asMap(event);
          return BluetoothState.fromString(payload['state'] as String?);
        });
    return _bluetoothStateStream!;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _asMap(Object? event) {
    if (event is Map) {
      return Map<String, dynamic>.from(event);
    }
    return <String, dynamic>{};
  }
}
