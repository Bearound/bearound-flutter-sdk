import 'dart:async';
import 'package:bearound_flutter_sdk/bearound_flutter_sdk_method_channel.dart';
import 'package:bearound_flutter_sdk/src/data/models/beacon.dart';

class BeaconScanner {
  static final BeaconScanner _instance = BeaconScanner._internal();
  final StreamController<List<Beacon>> _beaconStreamController = StreamController.broadcast();

  bool _isScanning = false;
  StreamSubscription? _nativeSub;

  BeaconScanner._internal();

  static Future<void> startScan({bool debug = false}) async {
    try{
      await _instance._startScan(debug: debug);
    }catch(_){
      await _instance._stopScan();
      rethrow;
    }
  }

  static Future<void> stopScan() async {
    await _instance._stopScan();
  }

  static Stream<List<Beacon>> get beaconStream => _instance._beaconStreamController.stream;

  Future<void> _startScan({bool debug = false}) async {
    if (_isScanning) return;
    _isScanning = true;

    await MethodChannelBearoundFlutterSdk().initialize(debug: debug);

    _nativeSub = MethodChannelBearoundFlutterSdk().events.listen((event) {
      final list = event['beacons'] as List<dynamic>? ?? [];
      _beaconStreamController.add(
        list.map((b) => Beacon.fromJson(Map<String, dynamic>.from(b))).toList(),
      );
    });
  }

  Future<void> _stopScan() async {
    if (!_isScanning) return;
    _isScanning = false;
    await MethodChannelBearoundFlutterSdk().stop();
    await _nativeSub?.cancel();
    _nativeSub = null;
    _beaconStreamController.add([]);
  }
}
