import 'dart:async';
import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:bearound_flutter_sdk/bearound_flutter_sdk_method_channel.dart';
import 'package:bearound_flutter_sdk/src/core/permission_service.dart';

class BeaconScanner {
  static final BeaconScanner _instance = BeaconScanner._internal();
  static Stream<List<Beacon>>? _beaconStream;

  BeaconScanner._internal();

  static Future<void> startScan({bool debug = false}) async {
    try {
      bool isGranted = await PermissionService.instance.requestPermissions();
      if (!isGranted) {
        throw Exception("Permissões necessárias não concedidas.");
      }
      await _instance._startScan(debug: debug);
    } catch (_) {
      await _instance._stopScan();
      rethrow;
    }
  }

  static Future<void> stopScan() async {
    await _instance._stopScan();
  }

  Future<void> _startScan({bool debug = false}) async {
    await MethodChannelBearoundFlutterSdk().initialize(debug: debug);
  }

  Future<void> _stopScan() async {
    await MethodChannelBearoundFlutterSdk().stop();
  }

  static Stream<Beacon> get beaconStream {
    return MethodChannelBearoundFlutterSdk().beaconStream.map((event) {
      final dynamic beaconRaw = event['beacon'];
      if (beaconRaw is Map) {
        return Beacon.fromJson(Map<String, dynamic>.from(beaconRaw));
      } else {
        throw Exception('Evento inválido: $event');
      }
    });
  }
}
