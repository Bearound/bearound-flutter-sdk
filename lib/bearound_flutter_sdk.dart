import 'dart:io' show Platform;

import 'bearound_flutter_sdk_platform_interface.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart' as loc;

class BearoundFlutterSdk {
  BearoundFlutterSdk._();

  /// Singleton instance
  static final BearoundFlutterSdk instance = BearoundFlutterSdk._();

  /// Solicita permissões necessárias para beacon scanning em etapas.
  Future<bool> requestPermissions() async {
    print("[BearoundFlutterSdk] Solicitando permissões para o beacon scanning...");
    try {
      if (Platform.isIOS) {
        final location = loc.Location();
        var permissionGranted = await location.hasPermission();
        if (permissionGranted == loc.PermissionStatus.denied) {
          permissionGranted = await location.requestPermission();
        }
        if (permissionGranted != loc.PermissionStatus.granted &&
            permissionGranted != loc.PermissionStatus.grantedLimited) {
          print("[BearoundFlutterSdk] Permissão de localização NÃO concedida (iOS).");
          return false;
        }
        print("[BearoundFlutterSdk] Permissão de localização concedida (iOS).");
        return true;
      } else {
        if (!await Permission.location.isGranted) {
          final status = await Permission.location.request();
          if (!status.isGranted) return false;
        }
        if (!await Permission.locationAlways.isGranted) {
          final status = await Permission.locationAlways.request();
          if (!status.isGranted) return false;
        }
        final blePermissions = <Permission>[
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
          Permission.notification,
        ];
        for (final perm in blePermissions) {
          if (!await perm.isGranted) {
            final status = await perm.request();
            if (!status.isGranted) return false;
          }
        }
        print("[BearoundFlutterSdk] Todas permissões Android concedidas.");
        return true;
      }
    } catch (e) {
      print("[BearoundFlutterSdk] Erro ao solicitar permissões: $e");
      return false;
    }
  }


  /// Inicializa o beacon scanning
  Future<void> initialize({bool debug = false}) async {
    await BearoundFlutterSdkPlatform.instance.initialize(debug: debug);
  }

  /// Para o beacon scanning
  Future<void> stop() async {
    await BearoundFlutterSdkPlatform.instance.stop();
  }

  /// Stream dos eventos
  Stream<Map<String, dynamic>> get events => BearoundFlutterSdkPlatform.instance.events;
}
