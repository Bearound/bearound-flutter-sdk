library;

import 'dart:async';

import 'package:flutter/services.dart';

import 'src/core/permission_service.dart';
import 'src/models/beacon.dart';
import 'src/models/bearound_error.dart';
import 'src/models/scan_interval_configuration.dart';
import 'src/models/sync_status.dart';
import 'src/models/user_properties.dart';

export 'src/models/beacon.dart';
export 'src/models/beacon_metadata.dart';
export 'src/models/bearound_error.dart';
export 'src/models/scan_interval_configuration.dart';
export 'src/models/sync_status.dart';
export 'src/models/user_properties.dart';

/// SDK principal do Bearound para integração com o SDK nativo 2.0.1.
class BearoundFlutterSdk {
  BearoundFlutterSdk._();

  static const MethodChannel _channel = MethodChannel('bearound_flutter_sdk');
  static const EventChannel _beaconsChannel = EventChannel(
    'bearound_flutter_sdk/beacons',
  );
  static const EventChannel _syncChannel = EventChannel(
    'bearound_flutter_sdk/sync',
  );
  static const EventChannel _scanningChannel = EventChannel(
    'bearound_flutter_sdk/scanning',
  );
  static const EventChannel _errorChannel = EventChannel(
    'bearound_flutter_sdk/errors',
  );

  static Stream<List<Beacon>>? _beaconsStream;
  static Stream<SyncStatus>? _syncStream;
  static Stream<bool>? _scanningStream;
  static Stream<BearoundError>? _errorStream;

  /// Solicita as permissões necessárias para operação do SDK.
  static Future<bool> requestPermissions() =>
      PermissionService.instance.requestPermissions();

  /// Configura o SDK nativo antes de iniciar o scan.
  ///
  /// O [businessToken] é obrigatório para autenticação.
  /// O [foregroundScanInterval] configura o intervalo de scan quando o app está em primeiro plano (padrão: 15s).
  /// O [backgroundScanInterval] configura o intervalo de scan quando o app está em background (padrão: 30s).
  /// O [maxQueuedPayloads] configura o tamanho da fila de retry para falhas de API (padrão: medium/100).
  static Future<void> configure({
    required String businessToken,
    ForegroundScanInterval foregroundScanInterval =
        ForegroundScanInterval.seconds15,
    BackgroundScanInterval backgroundScanInterval =
        BackgroundScanInterval.seconds30,
    MaxQueuedPayloads maxQueuedPayloads = MaxQueuedPayloads.medium,
    bool enableBluetoothScanning = false,
    bool enablePeriodicScanning = true,
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
      'foregroundScanInterval': foregroundScanInterval.seconds,
      'backgroundScanInterval': backgroundScanInterval.seconds,
      'maxQueuedPayloads': maxQueuedPayloads.value,
      'enableBluetoothScanning': enableBluetoothScanning,
      'enablePeriodicScanning': enablePeriodicScanning,
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

  /// Habilita ou desabilita o scan Bluetooth de metadados.
  static Future<void> setBluetoothScanning(bool enabled) async {
    await _channel.invokeMethod('setBluetoothScanning', {'enabled': enabled});
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

  /// Stream com o status de sincronização do SDK.
  static Stream<SyncStatus> get syncStream {
    _syncStream ??= _syncChannel.receiveBroadcastStream().map((event) {
      final payload = _asMap(event);
      return SyncStatus.fromJson(payload);
    });
    return _syncStream!;
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

  static Map<String, dynamic> _asMap(Object? event) {
    if (event is Map) {
      return Map<String, dynamic>.from(event);
    }
    return <String, dynamic>{};
  }
}
