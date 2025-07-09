import 'dart:async';
import '../data/models/beacon.dart';
import '../data/api/beacon_api_service.dart';

class BeaconSyncService {
  final BeaconApiService apiService;
  Timer? _timer;
  final Map<String, Beacon> _currentBeacons = {};
  final Map<String, num> _lastSeen = {};
  static const int threshold = 5;
  StreamSubscription<List<Beacon>>? _sub;

  BeaconSyncService({required this.apiService});

  void processBeacons(List<Beacon> beacons) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    for (final b in beacons) {
      final key = _beaconKey(b);
      _currentBeacons[key] = b;
      _lastSeen[key] = now;
    }
  }

  void startSync({
    required Stream<List<Beacon>> beaconStream,
    required String deviceType,
    required String idfa,
    required String appState,
  }) {
    _sub?.cancel();
    _sub = beaconStream.listen(processBeacons);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final now = DateTime.now().millisecondsSinceEpoch / 1000;

      final enterBeacons = _currentBeacons.entries
          .where((e) => now - (_lastSeen[e.key] ?? now) < threshold)
          .map((e) => e.value)
          .toList();

      final exitKeys = _lastSeen.entries
          .where((e) => now - e.value >= threshold)
          .map((e) => e.key)
          .toList();
      final exitBeacons = exitKeys.map((k) => _currentBeacons[k]!).toList();

      if (enterBeacons.isNotEmpty) {
        print("[BeaconSyncService] Enviando ENTER: ${enterBeacons.length} beacons");
        await apiService.sendBeacons(
          deviceType: deviceType,
          idfa: idfa,
          eventType: "enter",
          appState: appState,
          beacons: enterBeacons,
        );
      }
      if (exitBeacons.isNotEmpty) {
        print("[BeaconSyncService] Enviando EXIT: ${exitBeacons.length} beacons");
        await apiService.sendBeacons(
          deviceType: deviceType,
          idfa: idfa,
          eventType: "exit",
          appState: appState,
          beacons: exitBeacons,
        );
        for (final key in exitKeys) {
          _currentBeacons.remove(key);
          _lastSeen.remove(key);
        }
      }
    });
  }

  void stopSync() {
    _timer?.cancel();
    _sub?.cancel();
    _sub = null;
  }

  void dispose() => stopSync();

  String _beaconKey(Beacon b) => "${b.uuid}_${b.major}_${b.minor}";
}
