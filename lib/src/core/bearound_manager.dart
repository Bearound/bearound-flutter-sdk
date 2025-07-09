import 'dart:async';
import 'dart:io';
import 'package:bearound_flutter_sdk/bearound_flutter_sdk_method_channel.dart';

import '../data/api/beacon_api_service.dart';
import '../data/storage/beacon_local_storage.dart';
import '../data/storage/beacon_database.dart';
import 'beacon_scanner.dart';
import 'beacon_sync_service.dart';

class BearoundManager {
  static final BearoundManager instance = BearoundManager._internal();

  BeaconSyncService? _syncService;

  BearoundManager._internal();

  Future<void> _ensureInitialized() async {
    if (_syncService != null) return;
    final db = await BeaconDatabase.database;
    final storage = BeaconLocalStorage(db);
    final api = BeaconApiService();
    _syncService = BeaconSyncService(apiService: api);
  }

  /// Inicia scanner e sincronização periódica.
  Future<void> start({bool debug = false}) async {
    if (_syncService == null) {
      await _ensureInitialized();
    }
    await BeaconScanner.startScan(debug: debug);
    final idfa = await _getAdvertisingId();
    final deviceType = Platform.isAndroid ? 'Android' : 'iOS';
    final appState = await _getPlatformAppState();

    print("[BearoundFlutterSdk] Scanner iniciado, IDFA: $idfa, Tipo de dispositivo: $deviceType, Estado do app: $appState");
    print("[BearoundFlutterSdk] Iniciando sync...");

    // Só chama startSync! Não precisa ouvir a stream aqui!
    _syncService!.startSync(
      beaconStream: BeaconScanner.beaconStream,
      deviceType: deviceType,
      idfa: idfa,
      appState: appState,
    );
  }

  /// Para o scanner e o sync.
  Future<void> stop() async {
    if (_syncService == null) return;
    await BeaconScanner.stopScan();
    _syncService!.dispose();
  }

  /// Obtém o ID de publicidade (IDFA) do dispositivo.
  Future<String> _getAdvertisingId() async {
    return await MethodChannelBearoundFlutterSdk().getAdvertisingId();
  }

  /// Obtém o estado do aplicativo na plataforma. Foregroun e background.
  Future<String> _getPlatformAppState() async {
    return await MethodChannelBearoundFlutterSdk().getAppState();
  }
}