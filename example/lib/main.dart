import 'dart:async';
import 'dart:io' show Platform;

import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:flutter/material.dart';

import 'events.dart';
import 'eye_card.dart';
import 'log_modal.dart';
import 'settings_page.dart';
import 'two_eyes_modal.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bearound SDK Example',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0B0F),
        cardColor: const Color(0xFF141414),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111111),
          foregroundColor: Colors.white,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1976D2),
          surface: Color(0xFF141414),
        ),
      ),
      home: const BeaconHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BeaconHomePage extends StatefulWidget {
  const BeaconHomePage({super.key});

  @override
  State<BeaconHomePage> createState() => _BeaconHomePageState();
}

class _BeaconHomePageState extends State<BeaconHomePage>
    with WidgetsBindingObserver {
  // ---- SDK config ----
  static const _businessToken = 'ee2ec9c46d2b2ad99bddcdd0afe224e6';

  // ---- Permission state ----
  // NOTE: push is app-level now — the SDK no longer manages notification
  // permission or posting, so the example doesn't request it either.
  bool _locationGranted = false;
  BluetoothState _bluetoothState = BluetoothState.unknown;

  // ---- Scanning state ----
  bool _isScanning = false;
  bool _useForegroundService =
      true; // Android: FGS (true) vs oportunista (false)
  String _status = 'Pronto';
  ScanPrecision _scanPrecision = ScanPrecision.high;
  MaxQueuedPayloads _maxQueuedPayloads = MaxQueuedPayloads.medium;
  String _sdkVersion = '';

  // ---- Beacons / errors ----
  List<Beacon> _detectedBeacons = [];
  DateTime? _lastScanTime;
  String? _lastError;

  // ---- Sync info ----
  DateTime? _lastSyncTime;
  int _lastSyncCount = 0;
  Duration? _lastSyncDuration;
  bool? _lastSyncSuccess;
  DateTime? _syncStartedAt;

  // ---- Geofence debug ----
  bool _isInBeaconRegion = false;
  DateTime? _lastEnteredRegionAt;
  DateTime? _lastExitedRegionAt;
  bool _isActiveScanRunning = false;
  final List<GeofenceEventEntry> _geofenceEvents = [];

  // ---- Two eyes state ----
  int _locationEnterCount = 0;
  bool _isInBluetoothZone = false;
  DateTime? _lastBtEnterAt;
  DateTime? _lastBtExitAt;
  int _btZoneEnterCount = 0;
  BluetoothScanMode _btScanMode = BluetoothScanMode.idle;
  DateTime? _btNextIdleScanAt;
  final Set<String> _locationKeys = {};
  final Set<String> _bluetoothKeys = {};

  // ---- Tick for "X seg atrás" UI ----
  Timer? _tickTimer;
  DateTime _nowTick = DateTime.now();

  // ---- Stream subscriptions ----
  StreamSubscription<List<Beacon>>? _beaconsSub;
  StreamSubscription<bool>? _scanningSub;
  StreamSubscription<BearoundError>? _errorSub;
  StreamSubscription<SyncLifecycleEvent>? _syncSub;
  StreamSubscription<BackgroundDetectionEvent>? _bgDetectionSub;
  StreamSubscription<BeaconRegionEvent>? _regionSub;
  StreamSubscription<ActiveScanEvent>? _activeScanSub;
  StreamSubscription<BluetoothZoneEvent>? _btZoneSub;
  StreamSubscription<BluetoothScanModeEvent>? _btScanModeSub;
  StreamSubscription<BluetoothState>? _btStateSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startListening();
    _bootstrap();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _nowTick = DateTime.now());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickTimer?.cancel();
    _beaconsSub?.cancel();
    _scanningSub?.cancel();
    _errorSub?.cancel();
    _syncSub?.cancel();
    _bgDetectionSub?.cancel();
    _regionSub?.cancel();
    _activeScanSub?.cancel();
    _btZoneSub?.cancel();
    _btScanModeSub?.cancel();
    _btStateSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshState();
    }
  }

  bool get _canScan =>
      _locationGranted || _bluetoothState == BluetoothState.poweredOn;

  // ---------------------------------------------------------------------------
  // Boot
  // ---------------------------------------------------------------------------

  Future<void> _bootstrap() async {
    // Solicita permissões (Location + BT). Não bloqueia — o SDK nativo nunca
    // gateia scan; qualquer olho disponível ativa.
    final granted = await BearoundFlutterSdk.requestPermissions();
    setState(() => _locationGranted = granted);

    // NOTE: push is app-level now — notification permission/posting and ATT/IDFA
    // are no longer part of the SDK, so the example doesn't request them.

    // Bluetooth state inicial.
    final bt = await BearoundFlutterSdk.getBluetoothState();
    setState(() => _bluetoothState = bt);

    // SDK version (iOS retorna, Android retorna '').
    final version = await BearoundFlutterSdk.getSdkVersion();
    setState(() => _sdkVersion = version);

    await _applyConfig();
    await _startScan();
    await _refreshState();
  }

  Future<void> _applyConfig() async {
    try {
      await BearoundFlutterSdk.configure(
        businessToken: _businessToken,
        scanPrecision: _scanPrecision,
        maxQueuedPayloads: _maxQueuedPayloads,
      );
    } catch (e) {
      setState(() => _lastError = e.toString());
    }
  }

  Future<void> _refreshState() async {
    final running = await BearoundFlutterSdk.isScanning();
    if (!mounted) return;
    setState(() {
      _isScanning = running;
      _status = running ? 'Scaneando…' : 'Parado';
    });
  }

  // ---------------------------------------------------------------------------
  // Listeners
  // ---------------------------------------------------------------------------

  void _startListening() {
    _beaconsSub = BearoundFlutterSdk.beaconsStream.listen(_onBeacons);
    _scanningSub = BearoundFlutterSdk.scanningStream.listen(_onScanning);
    _errorSub = BearoundFlutterSdk.errorStream.listen(_onError);
    _syncSub = BearoundFlutterSdk.syncLifecycleStream.listen(_onSync);
    _bgDetectionSub = BearoundFlutterSdk.backgroundDetectionStream.listen(
      _onBackground,
    );
    _regionSub = BearoundFlutterSdk.beaconRegionStream.listen(_onRegion);
    _activeScanSub = BearoundFlutterSdk.activeScanStream.listen(_onActiveScan);
    _btZoneSub = BearoundFlutterSdk.bluetoothZoneStream.listen(_onBtZone);
    _btScanModeSub = BearoundFlutterSdk.bluetoothScanModeStream.listen(
      _onBtScanMode,
    );
    _btStateSub = BearoundFlutterSdk.bluetoothStateStream.listen((state) {
      if (mounted) setState(() => _bluetoothState = state);
    });
  }

  void _onBeacons(List<Beacon> beacons) {
    if (!mounted) return;
    setState(() {
      _detectedBeacons = beacons;
      _lastScanTime = DateTime.now();
      if (beacons.isNotEmpty) _status = '${beacons.length} beacon(s)';

      // Acumula keys por olho (iOS discoverySources).
      for (final b in beacons) {
        final key = '${b.major}.${b.minor}';
        if (b.discoverySources.contains(BeaconDiscoverySource.coreLocation)) {
          _locationKeys.add(key);
        }
        if (b.discoverySources.contains(BeaconDiscoverySource.serviceUUID) ||
            b.discoverySources.contains(BeaconDiscoverySource.name)) {
          _bluetoothKeys.add(key);
        }
      }
    });
  }

  void _onScanning(bool running) {
    if (!mounted) return;
    setState(() {
      _isScanning = running;
      _status = running ? 'Scaneando…' : 'Parado';
      if (!running) _detectedBeacons = [];
    });
  }

  void _onError(BearoundError error) {
    if (!mounted) return;
    setState(() {
      _lastError = error.message;
      _status = 'Erro';
    });
  }

  void _onSync(SyncLifecycleEvent event) {
    if (!mounted) return;
    if (event.isStarted) {
      setState(() {
        _syncStartedAt = DateTime.now();
        _lastSyncCount = event.beaconCount;
      });
    } else if (event.isCompleted) {
      final startedAt = _syncStartedAt;
      final duration = startedAt != null
          ? DateTime.now().difference(startedAt)
          : Duration.zero;
      setState(() {
        _lastSyncTime = DateTime.now();
        _lastSyncCount = event.beaconCount;
        _lastSyncDuration = duration;
        _lastSyncSuccess = event.success;
        _syncStartedAt = null;
        if (event.success == true) {
          _lastError = null;
        } else if (event.error != null) {
          _lastError = event.error;
        }
      });
    }
  }

  void _onBackground(BackgroundDetectionEvent event) {
    // NOTE: push is app-level now — the SDK no longer posts notifications.
    // The host app can react to this event and post its own notification.
    if (!mounted) return;
    setState(() {
      _status = '${event.beaconCount} beacon(s) em background';
    });
  }

  void _onRegion(BeaconRegionEvent event) {
    if (!mounted) return;
    setState(() {
      _isInBeaconRegion = event.isEnter;
      if (event.isEnter) {
        _lastEnteredRegionAt = DateTime.now();
        _locationEnterCount += 1;
      } else {
        _lastExitedRegionAt = DateTime.now();
      }
    });
    _pushGeofenceEvent(
      event.isEnter
          ? GeofenceEventKind.regionEnter
          : GeofenceEventKind.regionExit,
      event.isEnter
          ? 'iOS/Android reportou entrada na zona do beacon'
          : 'Saiu da zona do beacon',
    );
  }

  void _onActiveScan(ActiveScanEvent event) {
    if (!mounted) return;
    setState(() => _isActiveScanRunning = event.isActive);
    _pushGeofenceEvent(
      event.isActive
          ? GeofenceEventKind.scanActive
          : GeofenceEventKind.scanPaused,
      event.isActive
          ? 'Scan ativo (ranging + BLE) LIGADO'
          : 'Scan ativo DESLIGADO — só region monitoring',
    );
  }

  void _onBtZone(BluetoothZoneEvent event) {
    if (!mounted) return;
    setState(() {
      _isInBluetoothZone = event.isEnter;
      if (event.isEnter) {
        _lastBtEnterAt = DateTime.now();
        _btZoneEnterCount += 1;
      } else {
        _lastBtExitAt = DateTime.now();
      }
    });
    _pushGeofenceEvent(
      event.isEnter
          ? GeofenceEventKind.btZoneEnter
          : GeofenceEventKind.btZoneExit,
      event.isEnter
          ? 'BLE detectou beacon (CBCentralManager)'
          : 'Zona BLE vazia (graça expirou)',
    );
  }

  void _onBtScanMode(BluetoothScanModeEvent event) {
    if (!mounted) return;
    setState(() {
      _btScanMode = event.mode;
      _btNextIdleScanAt = event.nextIdleScanAt != null
          ? DateTime.fromMillisecondsSinceEpoch(event.nextIdleScanAt!)
          : null;
    });
  }

  void _pushGeofenceEvent(GeofenceEventKind kind, String detail) {
    if (!mounted) return;
    setState(() {
      _geofenceEvents.insert(
        0,
        GeofenceEventEntry(
          id: '${DateTime.now().millisecondsSinceEpoch}-${_geofenceEvents.length}',
          kind: kind,
          timestamp: DateTime.now(),
          detail: detail,
        ),
      );
      if (_geofenceEvents.length > 30) {
        _geofenceEvents.removeRange(30, _geofenceEvents.length);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _startScan() async {
    try {
      await BearoundFlutterSdk.startScanning();

      // Android: foreground service (opcional) para sobreviver em background.
      // Desligue _useForegroundService para o modo oportunista (sem FGS/vídeo).
      // Sem config: a notificação mostra só o nome do app (sem subtítulo).
      if (Platform.isAndroid && _useForegroundService) {
        await BearoundFlutterSdk.enableForegroundScanning().catchError(
          (_) => null,
        );
      }

      setState(() {
        _geofenceEvents.clear();
        _lastEnteredRegionAt = null;
        _lastExitedRegionAt = null;
        _locationEnterCount = 0;
        _btZoneEnterCount = 0;
        _isInBluetoothZone = false;
        _lastBtEnterAt = null;
        _lastBtExitAt = null;
        _locationKeys.clear();
        _bluetoothKeys.clear();
      });
    } catch (e) {
      setState(() => _lastError = e.toString());
    }
  }

  Future<void> _stopScan() async {
    try {
      await BearoundFlutterSdk.stopScanning();
      if (Platform.isAndroid) {
        await BearoundFlutterSdk.disableForegroundScanning().catchError(
          (_) => null,
        );
      }
    } catch (e) {
      setState(() => _lastError = e.toString());
    }
    setState(() {
      _detectedBeacons = [];
      _lastError = null;
    });
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<SdkSettings>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          initialScanPrecision: _scanPrecision,
          initialMaxQueuedPayloads: _maxQueuedPayloads,
          sdkVersion: _sdkVersion,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _scanPrecision = result.scanPrecision;
        _maxQueuedPayloads = result.maxQueuedPayloads;
      });
      if (_isScanning) await _applyConfig();
    }
  }

  Future<void> _openTwoEyes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TwoEyesModal(
          now: _nowTick,
          location: EyeCardData(
            available: true,
            isInZone: _isInBeaconRegion,
            lastEnter: _lastEnteredRegionAt,
            lastExit: _lastExitedRegionAt,
            enterCount: _locationEnterCount,
            beaconsNow: _detectedBeacons
                .where(
                  (b) => b.discoverySources.contains(
                    BeaconDiscoverySource.coreLocation,
                  ),
                )
                .length,
            totalDetected: _locationKeys.length,
            modeLabel: _isActiveScanRunning ? 'RANGING' : 'REGION',
            modeIsActive: _isActiveScanRunning,
            cadenceLabel: _isActiveScanRunning ? '~1Hz' : 'kernel-level',
          ),
          bluetooth: EyeCardData(
            available: Platform.isIOS,
            isInZone: _isInBluetoothZone,
            lastEnter: _lastBtEnterAt,
            lastExit: _lastBtExitAt,
            enterCount: _btZoneEnterCount,
            beaconsNow: _detectedBeacons
                .where(
                  (b) => b.discoverySources.any(
                    (s) =>
                        s == BeaconDiscoverySource.serviceUUID ||
                        s == BeaconDiscoverySource.name,
                  ),
                )
                .length,
            totalDetected: _bluetoothKeys.length,
            modeLabel: _btScanMode == BluetoothScanMode.active
                ? 'ATIVO'
                : 'STANDBY',
            modeIsActive: _btScanMode == BluetoothScanMode.active,
            cadenceLabel: _btScanMode == BluetoothScanMode.active
                ? '10s tick'
                : '5min cycle',
            nextScanAt: _btNextIdleScanAt,
          ),
          events: _geofenceEvents,
          onClearLog: () => setState(() => _geofenceEvents.clear()),
        ),
      ),
    );
  }

  Future<void> _openLog() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LogModal()),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BeAroundScan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              _status,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isScanning ? Icons.wifi_tethering : Icons.wifi_off,
              color: _isScanning ? Colors.green : Colors.grey,
            ),
            onPressed: null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerActions(),
          if (_lastError != null) _errorBox(),
          _permissionsCard(),
          if (_isScanning) ...[
            const SizedBox(height: 12),
            _scanInfoCard(),
            const SizedBox(height: 12),
            _syncInfoCard(),
            const SizedBox(height: 12),
            _geofenceDebugCard(),
          ],
          const SizedBox(height: 12),
          _controlsCard(),
          const SizedBox(height: 12),
          if (_lastScanTime != null)
            Center(
              child: Text(
                'Última atualização: ${_fmtTime(_lastScanTime!)}',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          const SizedBox(height: 12),
          if (_detectedBeacons.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      'Aguardando próximos scans',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final beacon in _detectedBeacons) _beaconCard(beacon),
        ],
      ),
    );
  }

  Widget _headerActions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _openTwoEyes,
              icon: const Text('👁 👁', style: TextStyle(fontSize: 14)),
              label: const Text('Abrir Dois Olhos'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            onPressed: _openLog,
            icon: const Icon(Icons.list_alt),
          ),
          IconButton.outlined(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
    );
  }

  Widget _errorBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _lastError ?? '',
        style: const TextStyle(color: Colors.redAccent),
      ),
    );
  }

  Widget _permissionsCard() {
    final btLabel = _bluetoothLabel(_bluetoothState);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Permissões',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _permRow(
              'Localização',
              _locationGranted ? 'Concedida' : 'Negada',
              _locationGranted ? Colors.green : Colors.red,
            ),
            _permRow('Bluetooth', btLabel, _bluetoothColor(_bluetoothState)),
            // NOTE: push is app-level now — notification/ATT/IDFA permission rows
            // were removed since the SDK no longer manages them.
            const SizedBox(height: 8),
            Text(
              _canScan
                  ? '✓ Pronto para detectar (Localização e/ou Bluetooth)'
                  : '⚠ Conceda Localização ou ligue o Bluetooth',
              style: TextStyle(
                color: _canScan ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await BearoundFlutterSdk.requestPermissions();
                final bt = await BearoundFlutterSdk.getBluetoothState();
                if (mounted) setState(() => _bluetoothState = bt);
              },
              icon: const Icon(Icons.lock_open),
              label: const Text('Solicitar permissões'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informações do Scan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _infoRow('Precisão', _scanPrecision.value),
            _infoRow('Fila Retry', '${_maxQueuedPayloads.value}'),
            const Divider(),
            const Text(
              '✨ Sync automático: eventos em syncLifecycleStream',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _syncInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informações do Sync',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _infoRow(
              'Último sync',
              _lastSyncTime != null ? _fmtTime(_lastSyncTime!) : '--',
            ),
            _infoRow('Beacons sincronizados', '$_lastSyncCount'),
            _infoRow(
              'Duração',
              _lastSyncDuration == null
                  ? '--'
                  : _lastSyncDuration!.inMilliseconds >= 1000
                  ? '${(_lastSyncDuration!.inMilliseconds / 1000).toStringAsFixed(1)}s'
                  : '${_lastSyncDuration!.inMilliseconds}ms',
            ),
            _infoRow(
              'Resultado',
              _lastSyncSuccess == true
                  ? 'Sucesso'
                  : _lastSyncSuccess == false
                  ? 'Falha'
                  : 'Aguardando…',
              valueColor: _lastSyncSuccess == true
                  ? Colors.green
                  : _lastSyncSuccess == false
                  ? Colors.red
                  : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _geofenceDebugCard() {
    final inZone = _isInBeaconRegion;
    final bg = inZone ? const Color(0xFF0F2B14) : const Color(0xFF2A0F0F);
    final border = inZone ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final titleColor = inZone
        ? const Color(0xFFA5D6A7)
        : const Color(0xFFEF9A9A);
    final emoji = inZone ? '✅' : '⛔';
    final title = inZone ? 'NA ZONA DO BEACON' : 'FORA DA ZONA';
    final body = inZone
        ? 'Beacon detectado — dentro da zona monitorada.'
        : 'Sem beacon detectado no momento.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Debug Geofence',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (_geofenceEvents.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _geofenceEvents.clear()),
                    child: const Text(
                      'Limpar',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      body,
                      style: TextStyle(color: titleColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _infoRow(
              'Zona do beacon',
              inZone ? 'DENTRO' : 'fora',
              valueColor: inZone ? Colors.green : Colors.grey,
            ),
            if (_lastEnteredRegionAt != null)
              _infoRow(
                'Entrou às',
                '${_fmtTime(_lastEnteredRegionAt!)} (${_fmtAge(_nowTick.difference(_lastEnteredRegionAt!))})',
              ),
            if (_lastExitedRegionAt != null)
              _infoRow(
                'Saiu às',
                '${_fmtTime(_lastExitedRegionAt!)} (${_fmtAge(_nowTick.difference(_lastExitedRegionAt!))})',
              ),
            _infoRow(
              'Scan ativo',
              _isActiveScanRunning ? 'LIGADO' : 'desligado',
              valueColor: _isActiveScanRunning ? Colors.green : Colors.grey,
            ),
            if (_geofenceEvents.isNotEmpty) ...[
              const Divider(),
              const Text(
                'Eventos recentes',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              for (final event in _geofenceEvents.take(10))
                _geofenceEventTile(event),
            ],
          ],
        ),
      ),
    );
  }

  Widget _geofenceEventTile(GeofenceEventEntry event) {
    final color = geofenceEventColor(event.kind);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        geofenceEventTitle(event.kind),
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${_fmtTime(event.timestamp)} · ${_fmtAge(_nowTick.difference(event.timestamp))}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                Text(event.detail, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Controle',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (!_isScanning)
              FilledButton.icon(
                onPressed: _startScan,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar Scan'),
              )
            else
              FilledButton.icon(
                onPressed: _stopScan,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC0392B),
                ),
                icon: const Icon(Icons.stop),
                label: const Text('Parar Scan'),
              ),
            if (Platform.isAndroid)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Foreground service'),
                subtitle: Text(
                  _useForegroundService
                      ? 'Contínuo · sobrevive app fechado · exige vídeo no Play'
                      : 'Oportunista · sem vídeo no Play · pode perder detecções',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                value: _useForegroundService,
                onChanged: (v) async {
                  setState(() => _useForegroundService = v);
                  if (_isScanning) {
                    await _stopScan();
                    await _startScan();
                  }
                },
              ),
            const SizedBox(height: 16),
            const Text('Scan Precision', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final precision in ScanPrecision.values)
                  ChoiceChip(
                    label: Text(precision.value),
                    selected: _scanPrecision == precision,
                    onSelected: (_) async {
                      setState(() => _scanPrecision = precision);
                      if (_isScanning) await _applyConfig();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Max Queued Payloads',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final queue in MaxQueuedPayloads.values)
                  ChoiceChip(
                    label: Text('${queue.value}'),
                    selected: _maxQueuedPayloads == queue,
                    onSelected: (_) async {
                      setState(() => _maxQueuedPayloads = queue);
                      if (_isScanning) await _applyConfig();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _beaconCard(Beacon beacon) {
    final m = beacon.metadata;
    final sources = beacon.discoverySources;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Beacon ${beacon.major}.${beacon.minor}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        beacon.uuid,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${beacon.rssi} dB',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                _chip(
                  _proximityLabel(beacon.proximity),
                  _proximityColor(beacon.proximity),
                ),
                if (beacon.accuracy > 0)
                  _chip('${beacon.accuracy.toStringAsFixed(1)}m', Colors.grey),
                if (beacon.isStale) _chip('stale', Colors.orange),
                if (beacon.alreadySynced) _chip('✓ synced', Colors.green),
              ],
            ),
            if (sources.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final source in sources)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _sourceColor(source)),
                      ),
                      child: Text(
                        _sourceLabel(source),
                        style: TextStyle(
                          fontSize: 10,
                          color: _sourceColor(source),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (m != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  Text(
                    '🔋 ${m.batteryLevel}mV',
                    style: TextStyle(
                      color: _batteryColor(m.batteryLevel),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '🌡 ${m.temperature}°C',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  Text(
                    '🚶 ${m.movements}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  Text(
                    'v${m.firmwareVersion}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  if (beacon.txPower != null)
                    Text(
                      'tx ${beacon.txPower}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                ],
              ),
            ],
            if (beacon.rssiSamples != null) ...[
              const SizedBox(height: 4),
              Text(
                'RSSI avg ${beacon.rssiSamples!.avg.round()} dBm (${beacon.rssiSamples!.min}…${beacon.rssiSamples!.max}, n=${beacon.rssiSamples!.count})',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _bluetoothLabel(BluetoothState s) {
    switch (s) {
      case BluetoothState.poweredOn:
        return 'Ligado';
      case BluetoothState.poweredOff:
        return 'Desligado';
      case BluetoothState.unauthorized:
        return 'Não autorizado';
      case BluetoothState.unsupported:
        return 'Não suportado';
      case BluetoothState.resetting:
        return 'Reiniciando';
      case BluetoothState.unknown:
        return 'Verificando…';
    }
  }

  Color _bluetoothColor(BluetoothState s) {
    switch (s) {
      case BluetoothState.poweredOn:
        return Colors.green;
      case BluetoothState.poweredOff:
      case BluetoothState.unauthorized:
      case BluetoothState.unsupported:
        return Colors.red;
      case BluetoothState.resetting:
      case BluetoothState.unknown:
        return Colors.orange;
    }
  }

  Color _batteryColor(int mV) =>
      mV > 2800 ? Colors.green : (mV > 2400 ? Colors.orange : Colors.red);

  String _proximityLabel(BeaconProximity p) {
    switch (p) {
      case BeaconProximity.immediate:
        return 'Imediato';
      case BeaconProximity.near:
        return 'Perto';
      case BeaconProximity.far:
        return 'Longe';
      case BeaconProximity.bt:
        return 'Bluetooth';
      case BeaconProximity.unknown:
        return 'Desconhecido';
    }
  }

  Color _proximityColor(BeaconProximity p) {
    switch (p) {
      case BeaconProximity.immediate:
        return Colors.green;
      case BeaconProximity.near:
        return Colors.orange;
      case BeaconProximity.far:
        return Colors.red;
      case BeaconProximity.bt:
        return Colors.blue;
      case BeaconProximity.unknown:
        return Colors.grey;
    }
  }

  String _sourceLabel(BeaconDiscoverySource source) {
    switch (source) {
      case BeaconDiscoverySource.serviceUUID:
        return 'Service UUID';
      case BeaconDiscoverySource.name:
        return 'Name';
      case BeaconDiscoverySource.coreLocation:
        return 'iBeacon';
    }
  }

  Color _sourceColor(BeaconDiscoverySource source) {
    switch (source) {
      case BeaconDiscoverySource.serviceUUID:
        return const Color(0xFF7E57C2);
      case BeaconDiscoverySource.name:
        return const Color(0xFF26A69A);
      case BeaconDiscoverySource.coreLocation:
        return const Color(0xFF5C6BC0);
    }
  }

  String _fmtTime(DateTime t) {
    String pad(int v) => v.toString().padLeft(2, '0');
    return '${pad(t.hour)}:${pad(t.minute)}:${pad(t.second)}';
  }

  String _fmtAge(Duration d) {
    final sec = d.inSeconds.clamp(0, 1 << 30);
    if (sec < 60) return '${sec}s atrás';
    if (sec < 3600) return '${sec ~/ 60}min ${sec % 60}s atrás';
    return '${sec ~/ 3600}h ${(sec % 3600) ~/ 60}min atrás';
  }
}
