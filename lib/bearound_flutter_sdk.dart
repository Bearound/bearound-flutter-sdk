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

/// SDK principal do Bearound para integração com o SDK nativo 3.0.0.
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

  /// Inicia o scan de beacons após `configure()`. No Android, aceita um
  /// [foregroundScanConfig] opcional para ativar o foreground service junto.
  /// No iOS, esse parâmetro é ignorado.
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
  /// O app é responsável por obter o token (ex.: `firebase_messaging`
  /// `getToken()` no Android) e chamar este método. No iOS o SDK nativo já
  /// captura o token APNs automaticamente via swizzle do AppDelegate; chame
  /// este método se você optou por desabilitar a captura automática
  /// (`BearoundAppDelegateProxyEnabled = NO`) e quiser encaminhá-lo manualmente.
  ///
  /// **iOS-only no nativo**: o SDK Android 3.0.0 ainda não expõe um setter de
  /// push token, então no Android esta chamada é um no-op silencioso (mantida
  /// para paridade de API).
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
    final result =
        await _channel.invokeMethod<String>('getCurrentScanPrecision');
    return result ?? '';
  }

  /// String de diagnóstico BLE. **iOS-only**; Android retorna `''`.
  static Future<String> getBleDiagnosticInfo() async {
    final result =
        await _channel.invokeMethod<String>('getBleDiagnosticInfo');
    return result ?? '';
  }

  /// Número de batches em fila aguardando retry. **iOS-only**; Android
  /// retorna `0`.
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
    final result =
        await _channel.invokeMethod<String>('getAuthorizationStatus');
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
  static Future<List<PersistedLogEntry>> getPersistedLog() async {
    final raw = await _channel.invokeMethod<String>('getPersistedLog') ?? '[]';
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) =>
            PersistedLogEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Versão "crua" do log persistido (lista de mapas), para consumidores que
  /// preferem renderizar JSON livre. Mantida por conveniência — prefira
  /// [getPersistedLog].
  static Future<List<Map<String, dynamic>>> getPersistedLogRaw() async {
    final raw = await _channel.invokeMethod<String>('getPersistedLog') ?? '[]';
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  /// Limpa o log persistido do SDK.
  static Future<void> clearPersistedLog() async {
    await _channel.invokeMethod('clearPersistedLog');
  }

  // ---------------------------------------------------------------------------
  // Foreground service scanning (Android-only)
  // ---------------------------------------------------------------------------

  /// Habilita o foreground service de scan no Android com notificação
  /// persistente. iOS: no-op (usa BGTaskScheduler / region monitoring).
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
    final result =
        await _channel.invokeMethod<bool>('isForegroundScanningEnabled');
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
  static Stream<BearoundError> get errorStream {
    _errorStream ??= _errorChannel.receiveBroadcastStream().map((event) {
      if (event is String) {
        return BearoundError(message: event);
      }
      final payload = _asMap(event);
      return BearoundError.fromJson(payload);
    });
    return _errorStream!;
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
    _bluetoothZoneStream ??=
        _bluetoothZoneChannel.receiveBroadcastStream().map((event) {
      return BluetoothZoneEvent.fromMap(_asMap(event));
    });
    return _bluetoothZoneStream!;
  }

  /// Stream de mudanças do duty-cycle do scanner Bluetooth (`idle` / `active`).
  /// **iOS-only** — no Android nunca emite.
  static Stream<BluetoothScanModeEvent> get bluetoothScanModeStream {
    _bluetoothScanModeStream ??=
        _bluetoothScanModeChannel.receiveBroadcastStream().map((event) {
      return BluetoothScanModeEvent.fromMap(_asMap(event));
    });
    return _bluetoothScanModeStream!;
  }

  /// Stream do estado do adaptador Bluetooth (poweredOn/off/unauthorized/...).
  /// Emite em ambas as plataformas — use para destravar o olho Bluetooth.
  static Stream<BluetoothState> get bluetoothStateStream {
    _bluetoothStateStream ??=
        _bluetoothStateChannel.receiveBroadcastStream().map((event) {
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
