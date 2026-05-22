library;

import 'dart:async';

import 'package:flutter/services.dart';

import 'src/core/permission_service.dart';
import 'src/models/background_detection_event.dart';
import 'src/models/beacon.dart';
import 'src/models/bearound_error.dart';
import 'src/models/location_capture_result.dart';
import 'src/models/scan_interval_configuration.dart';
import 'src/models/sync_lifecycle_event.dart';
import 'src/models/user_properties.dart';

export 'src/models/background_detection_event.dart';
export 'src/models/beacon.dart';
export 'src/models/beacon_metadata.dart';
export 'src/models/bearound_error.dart';
export 'src/models/location_capture_result.dart';
export 'src/models/scan_interval_configuration.dart';
export 'src/models/sync_lifecycle_event.dart';
export 'src/models/user_properties.dart';

/// SDK principal do Bearound para integração com o SDK nativo 2.2.0.
class BearoundFlutterSdk {
  BearoundFlutterSdk._();

  static const MethodChannel _channel = MethodChannel('bearound_flutter_sdk');
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
  static const EventChannel _locationCaptureChannel = EventChannel(
    'bearound_flutter_sdk/location_capture',
  );

  static Stream<List<Beacon>>? _beaconsStream;
  static Stream<bool>? _scanningStream;
  static Stream<BearoundError>? _errorStream;
  static Stream<SyncLifecycleEvent>? _syncLifecycleStream;
  static Stream<BackgroundDetectionEvent>? _backgroundDetectionStream;
  static Stream<BeaconRegionEvent>? _beaconRegionStream;
  static Stream<ActiveScanEvent>? _activeScanStream;
  static Stream<LocationCaptureResult>? _locationCaptureStream;

  /// Solicita as permissões necessárias para operação do SDK.
  /// No iOS, chama requestAlwaysAuthorization() via código nativo.
  /// No Android, usa permission_handler para solicitar permissões.
  static Future<bool> requestPermissions() =>
      PermissionService.instance.requestPermissions();

  /// Verifica se as permissões necessárias foram concedidas.
  /// No iOS, verifica via código nativo.
  /// No Android, usa permission_handler.
  static Future<bool> checkPermissions() =>
      PermissionService.instance.checkPermissions();

  /// Configura o SDK nativo antes de iniciar o scan.
  ///
  /// O [businessToken] é obrigatório para autenticação.
  /// O [scanPrecision] controla o duty cycle de scan BLE/CoreLocation (padrão: medium).
  /// O [maxQueuedPayloads] configura o tamanho da fila de retry para falhas de API (padrão: medium/100).
  static Future<void> configure({
    required String businessToken,
    ScanPrecision scanPrecision = ScanPrecision.medium,
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

  /// Inicia o scan de beacons após `configure()`.
  static Future<void> startScanning() async {
    await _channel.invokeMethod('startScanning');
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

  /// Define propriedades do usuário associadas aos eventos de beacon.
  static Future<void> setUserProperties(UserProperties properties) async {
    await _channel.invokeMethod('setUserProperties', properties.toJson());
  }

  /// Limpa as propriedades do usuário.
  static Future<void> clearUserProperties() async {
    await _channel.invokeMethod('clearUserProperties');
  }

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

  /// Stream de eventos de ciclo de vida de sincronização (v2.2.0).
  ///
  /// Notifica quando uma operação de sincronização inicia ou completa.
  /// Útil para mostrar indicadores de progresso ou notificações ao usuário.
  static Stream<SyncLifecycleEvent> get syncLifecycleStream {
    _syncLifecycleStream ??= _syncLifecycleChannel.receiveBroadcastStream().map(
      (event) {
        final payload = _asMap(event);
        return SyncLifecycleEvent.fromJson(payload);
      },
    );
    return _syncLifecycleStream!;
  }

  /// Stream de eventos de detecção em background (v2.2.0).
  ///
  /// Notifica quando beacons são detectados enquanto o app está em background.
  /// Útil para mostrar notificações ou registrar eventos de proximidade.
  static Stream<BackgroundDetectionEvent> get backgroundDetectionStream {
    _backgroundDetectionStream ??= _backgroundDetectionChannel
        .receiveBroadcastStream()
        .map((event) {
          final payload = _asMap(event);
          return BackgroundDetectionEvent.fromJson(payload);
        });
    return _backgroundDetectionStream!;
  }

  /// Stream de transições de região de beacon (v2.4.0).
  ///
  /// Dispara quando o SDK detecta o primeiro beacon (`enter`) e quando o
  /// último beacon expira após o grace period (`exit`).
  /// Fora da zona, somente o filter scan kernel-level fica ativo — BLE e
  /// GPS estão OFF.
  static Stream<BeaconRegionEvent> get beaconRegionStream {
    _beaconRegionStream ??= _beaconRegionChannel.receiveBroadcastStream().map((
      event,
    ) {
      return BeaconRegionEvent.fromMap(_asMap(event));
    });
    return _beaconRegionStream!;
  }

  /// Stream do estado de scan ativo (v2.4.0).
  ///
  /// `isActive` fica `true` enquanto ranging + BLE central scan estão
  /// rodando. Fora da zona o gate desliga tudo — `isActive` vira `false`.
  static Stream<ActiveScanEvent> get activeScanStream {
    _activeScanStream ??= _activeScanChannel.receiveBroadcastStream().map((
      event,
    ) {
      return ActiveScanEvent.fromMap(_asMap(event));
    });
    return _activeScanStream!;
  }

  /// Stream do ciclo de captura de localização (v2.4.0).
  ///
  /// O SDK dispara `started` quando abre a janela de GPS (sempre por
  /// detecção de beacon) e `completed` quando fecha — com ou sem fix.
  /// GPS NUNCA é acionado fora de uma zona de beacon.
  static Stream<LocationCaptureResult> get locationCaptureStream {
    _locationCaptureStream ??= _locationCaptureChannel
        .receiveBroadcastStream()
        .map((event) {
          return LocationCaptureResult.fromMap(_asMap(event));
        });
    return _locationCaptureStream!;
  }

  static Map<String, dynamic> _asMap(Object? event) {
    if (event is Map) {
      return Map<String, dynamic>.from(event);
    }
    return <String, dynamic>{};
  }
}
