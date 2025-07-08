import 'dart:async';
import '../data/models/beacon.dart';
import '../data/api/beacon_api_service.dart';
import '../data/storage/beacon_local_storage.dart';

class BeaconSyncService {
  final BeaconApiService apiService;
  final BeaconLocalStorage localStorage;
  Timer? _timer;
  List<Beacon> _lastBeacons = [];
  int _retryCount = 0;
  static const int maxRetries = 3;

  BeaconSyncService({
    required this.apiService,
    required this.localStorage,
  });

  void processBeacons(List<Beacon> beacons) {
    _lastBeacons = beacons;
  }

  void startSync({
    required Stream<List<Beacon>> beaconStream,
    required String deviceType,
    required String idfa,
    required String eventType,
    required String appState,
  }) {
    beaconStream.listen((beacons) => processBeacons(beacons));

    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      print("[BeaconSyncService] Iniciando sincronização de beacons...");
      if (_lastBeacons.isEmpty) {
        print("[BeaconSyncService] Nenhum beacon encontrado, pulando envio.");
        return;
      }
      if (_lastBeacons.isEmpty) return;

      await localStorage.saveBeacons(_lastBeacons);

      print("[BeaconSyncService] Enviando beacons: ${_lastBeacons.length} encontrados");

      bool success = await apiService.sendBeacons(
        deviceType: deviceType,
        idfa: idfa,
        eventType: eventType,
        appState: appState,
        beacons: _lastBeacons,
      );
      if (success) {
        await localStorage.clearBeacons();
        _retryCount = 0;
      } else if (_retryCount < maxRetries) {
        _retryCount++;
      } else {
        _retryCount = 0;
      }
    });
  }

  void stopSync() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stopSync();
}
