import 'bearound_flutter_sdk_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart';

class BearoundFlutterSdk {
  BearoundFlutterSdk._();

  /// Singleton instance
  static final BearoundFlutterSdk instance = BearoundFlutterSdk._();

  /// Solicita permissões necessárias para beacon scanning.
  Future<bool> requestPermissions() async {
    final permissions = <Permission>[
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.notification,
    ];

    final results = await permissions.request();
    return results.values.every((status) => status.isGranted);
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
