export 'src/core/beacon_scanner.dart';
export 'src/data/models/beacon.dart';


import 'package:bearound_flutter_sdk/src/core/bearound_manager.dart';

import 'src/core/permission_service.dart';
import 'src/core/beacon_scanner.dart';
import 'src/data/models/beacon.dart';

class BearoundFlutterSdk {
  BearoundFlutterSdk._();

  static Future<bool> requestPermissions() => PermissionService.instance.requestPermissions();

  /// Inicia scanner e sync (tudo automático).
  static Future<void> startScan({bool debug = false}) =>
      BearoundManager.instance.start(debug: debug);

  /// Para tudo.
  static Future<void> stopScan() => BearoundManager.instance.stop();

  /// Stream dos beacons encontrados.
  static Stream<List<Beacon>> get beaconStream => BeaconScanner.beaconStream;
}
