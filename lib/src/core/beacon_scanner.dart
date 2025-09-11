import 'dart:async';
import 'package:bearound_flutter_sdk/bearound_flutter_sdk_method_channel.dart';
import 'package:bearound_flutter_sdk/src/core/permission_service.dart';

class BeaconScanner {
  static final BeaconScanner _instance = BeaconScanner._internal();

  BeaconScanner._internal();

  static Future<void> startScan(
    String clientToken, {
    bool debug = false,
  }) async {
    try {
      bool isGranted = await PermissionService.instance.requestPermissions();
      if (!isGranted) {
        throw Exception("Permissões necessárias não concedidas.");
      }
      await _instance._startScan(clientToken, debug: debug);
    } catch (_) {
      await _instance._stopScan();
      rethrow;
    }
  }

  static Future<void> stopScan() async {
    await _instance._stopScan();
  }

  Future<void> _startScan(String clientToken, {bool debug = false}) async {
    await MethodChannelBearoundFlutterSdk().initialize(
      clientToken,
      debug: debug,
    );
  }

  Future<void> _stopScan() async {
    await MethodChannelBearoundFlutterSdk().stop();
  }
}
