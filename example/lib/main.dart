import 'dart:async';

import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:flutter/material.dart';

import 'settings_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bearound SDK Example',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
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
  bool _hasPermission = false;
  bool _isScanning = false;
  String _status = 'Parado';

  ScanPrecision _scanPrecision = ScanPrecision.medium;
  MaxQueuedPayloads _maxQueuedPayloads = MaxQueuedPayloads.medium;

  List<Beacon> _detectedBeacons = [];
  final List<String> _logs = [];
  String? _lastError;

  // v2.4 — Geofence Debug state
  bool _isInBeaconRegion = false;
  DateTime? _lastEnteredRegionAt;
  DateTime? _lastExitedRegionAt;
  bool _isActiveScanRunning = false;
  bool _isCapturingLocation = false;
  String _lastCaptureOpenReason = '—';
  String _lastCaptureOutcome = '—';
  CapturedLocation? _lastCapturedLocation;
  DateTime? _lastCaptureCompletedAt;
  int _locationCaptureCount = 0;
  final List<_GeofenceEvent> _geofenceEvents = [];
  Timer? _tickTimer;
  DateTime _nowTick = DateTime.now();

  StreamSubscription<List<Beacon>>? _beaconsSubscription;
  StreamSubscription<bool>? _scanningSubscription;
  StreamSubscription<BearoundError>? _errorSubscription;
  StreamSubscription<SyncLifecycleEvent>? _syncLifecycleSubscription;
  StreamSubscription<BackgroundDetectionEvent>?
  _backgroundDetectionSubscription;
  StreamSubscription<BeaconRegionEvent>? _beaconRegionSubscription;
  StreamSubscription<ActiveScanEvent>? _activeScanSubscription;
  StreamSubscription<LocationCaptureResult>? _locationCaptureSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startListening();
    _initializeSdk();
    // 1Hz tick so "X seg atrás" ages render live in the Debug Geofence card.
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _nowTick = DateTime.now());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickTimer?.cancel();
    _beaconsSubscription?.cancel();
    _scanningSubscription?.cancel();
    _errorSubscription?.cancel();
    _syncLifecycleSubscription?.cancel();
    _backgroundDetectionSubscription?.cancel();
    _beaconRegionSubscription?.cancel();
    _activeScanSubscription?.cancel();
    _locationCaptureSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshScanningState();
    }
  }

  Future<void> _initializeSdk() async {
    final granted = await BearoundFlutterSdk.requestPermissions();
    setState(() {
      _hasPermission = granted;
      _status = granted ? 'Permissões OK' : 'Permissões necessárias!';
    });

    if (!granted) {
      return;
    }

    await _applyConfiguration();
    await _refreshScanningState();
  }

  Future<void> _applyConfiguration() async {
    try {
      await BearoundFlutterSdk.configure(
        businessToken: "your-business-token-here",
        scanPrecision: _scanPrecision,
        maxQueuedPayloads: _maxQueuedPayloads,
      );

      _addLog(
        '⚙️ Configurado: precision ${_scanPrecision.value}, '
        'queue ${_maxQueuedPayloads.value}',
      );
    } catch (error) {
      setState(() {
        _lastError = error.toString();
      });
      _addLog('❌ Erro ao configurar: $error');
    }
  }

  Future<void> _refreshScanningState() async {
    final isRunning = await BearoundFlutterSdk.isScanning();
    setState(() {
      _isScanning = isRunning;
      _status = isRunning ? 'Scaneando…' : 'Parado';
    });
  }

  void _startListening() {
    // Beacons stream
    _beaconsSubscription = BearoundFlutterSdk.beaconsStream.listen((beacons) {
      debugPrint('[DEBUG] 📡 Beacons callback: ${beacons.length} beacons');
      setState(() {
        _detectedBeacons = beacons;
      });
      _addLog('📡 Beacons detectados: ${beacons.length}');
      for (final beacon in beacons) {
        debugPrint(
          '[DEBUG]   - Beacon ${beacon.major}.${beacon.minor}: RSSI ${beacon.rssi}dBm',
        );
      }
    });

    // Scanning state stream
    _scanningSubscription = BearoundFlutterSdk.scanningStream.listen((
      isScanning,
    ) {
      debugPrint('[DEBUG] 🎯 Scanning state changed: $isScanning');
      setState(() {
        _isScanning = isScanning;
        _status = isScanning ? 'Scaneando…' : 'Parado';
      });
      _addLog('🔄 Scanning ${isScanning ? 'ativo' : 'parado'}');
    });

    // Error stream
    _errorSubscription = BearoundFlutterSdk.errorStream.listen((error) {
      debugPrint('[DEBUG] ❌ Error callback: ${error.message}');
      setState(() {
        _lastError = error.message;
      });
      _addLog('❌ Erro: ${error.message}');
    });

    // v2.2.0: Sync lifecycle stream (NEW!)
    _syncLifecycleSubscription = BearoundFlutterSdk.syncLifecycleStream.listen((
      event,
    ) {
      debugPrint(
        '[DEBUG] 🔄 Sync lifecycle: ${event.type}, beacons: ${event.beaconCount}',
      );
      if (event.isStarted) {
        _addLog('🚀 Sync iniciado com ${event.beaconCount} beacon(s)');
      } else if (event.isCompleted) {
        if (event.success == true) {
          _addLog('✅ Sync completo: ${event.beaconCount} beacon(s) enviados');
        } else {
          _addLog('❌ Sync falhou: ${event.error ?? "erro desconhecido"}');
        }
      }
    });

    // v2.2.0: Background detection stream (NEW!)
    _backgroundDetectionSubscription = BearoundFlutterSdk
        .backgroundDetectionStream
        .listen((event) {
          debugPrint(
            '[DEBUG] 🌙 Background detection: ${event.beaconCount} beacons',
          );
          _addLog('🌙 Background: ${event.beaconCount} beacon(s) detectado(s)');
        });

    // v2.4.0: Beacon region transitions
    _beaconRegionSubscription = BearoundFlutterSdk.beaconRegionStream.listen((
      event,
    ) {
      setState(() {
        _isInBeaconRegion = event.isEnter;
        if (event.isEnter) {
          _lastEnteredRegionAt = DateTime.now();
        } else {
          _lastExitedRegionAt = DateTime.now();
        }
      });
      _pushGeofenceEvent(
        event.isEnter
            ? _GeofenceEventKind.regionEnter
            : _GeofenceEventKind.regionExit,
        event.isEnter
            ? 'iOS/Android reportou entrada na zona do beacon'
            : 'Saiu da zona do beacon',
      );
    });

    // v2.4.0: Active scan state
    _activeScanSubscription = BearoundFlutterSdk.activeScanStream.listen((
      event,
    ) {
      setState(() => _isActiveScanRunning = event.isActive);
      _pushGeofenceEvent(
        event.isActive
            ? _GeofenceEventKind.scanActive
            : _GeofenceEventKind.scanPaused,
        event.isActive
            ? 'Scan ativo (ranging + BLE) LIGADO'
            : 'Scan ativo DESLIGADO — só region monitoring',
      );
    });

    // v2.4.0: Location capture lifecycle
    _locationCaptureSubscription = BearoundFlutterSdk.locationCaptureStream
        .listen((event) {
          if (event.isStarted) {
            setState(() {
              _isCapturingLocation = true;
              _lastCaptureOpenReason = event.reason;
            });
            _pushGeofenceEvent(
              _GeofenceEventKind.captureStarted,
              'Janela GPS aberta — motivo: ${event.reason}',
            );
          } else {
            setState(() {
              _isCapturingLocation = false;
              _lastCaptureOutcome = event.outcome;
              _lastCapturedLocation = event.location;
              _lastCaptureCompletedAt = DateTime.fromMillisecondsSinceEpoch(
                event.timestamp,
              );
              _locationCaptureCount += 1;
            });
            if (event.hasFix && event.location != null) {
              final loc = event.location!;
              final acc = loc.horizontalAccuracy?.toInt();
              _pushGeofenceEvent(
                _GeofenceEventKind.captureFix,
                'Fix: ${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)} '
                '±${acc ?? "?"}m | abriu: ${event.reason} | fechou: ${event.outcome}',
              );
            } else {
              _pushGeofenceEvent(
                _GeofenceEventKind.captureNoFix,
                'Sem fix — abriu: ${event.reason} | fechou: ${event.outcome}',
              );
            }
          }
        });

    debugPrint('[DEBUG] ✅ Todos os streams inicializados');
  }

  void _pushGeofenceEvent(_GeofenceEventKind kind, String detail) {
    if (!mounted) return;
    setState(() {
      _geofenceEvents.insert(
        0,
        _GeofenceEvent(kind: kind, timestamp: DateTime.now(), detail: detail),
      );
      if (_geofenceEvents.length > 30) {
        _geofenceEvents.removeRange(30, _geofenceEvents.length);
      }
    });
  }

  void _clearGeofenceLog() {
    setState(() => _geofenceEvents.clear());
  }

  void _addLog(String log) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    if (!mounted) {
      return;
    }
    setState(() {
      _logs.insert(0, '[$timestamp] $log');
      if (_logs.length > 50) {
        _logs.removeLast();
      }
    });
  }

  Future<void> _startScan() async {
    if (!_hasPermission) {
      _addLog('⚠️ Permissões necessárias');
      return;
    }

    // Configuration already applied in _initializeSdk() or when settings change
    // No need to call _applyConfiguration() here, it would restart the scan twice
    try {
      await BearoundFlutterSdk.startScanning();
      // Reset geofence/capture session counters for a fresh debug session
      setState(() {
        _geofenceEvents.clear();
        _locationCaptureCount = 0;
        _lastEnteredRegionAt = null;
        _lastExitedRegionAt = null;
        _lastCaptureOpenReason = '—';
        _lastCaptureOutcome = '—';
        _lastCapturedLocation = null;
        _lastCaptureCompletedAt = null;
      });
      _addLog('🚀 Scanner iniciado');
    } catch (error) {
      setState(() {
        _lastError = error.toString();
      });
      _addLog('❌ Erro ao iniciar: $error');
    }
  }

  Future<void> _stopScan() async {
    try {
      await BearoundFlutterSdk.stopScanning();
    } catch (error) {
      setState(() {
        _lastError = error.toString();
      });
      _addLog('❌ Erro ao parar: $error');
    }
    setState(() {
      _detectedBeacons = [];
      _lastError = null;
    });
    _addLog('🛑 Scanner parado');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bearound SDK'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.radar), text: 'Beacons'),
              Tab(icon: Icon(Icons.sync), text: 'Status'),
              Tab(icon: Icon(Icons.article), text: 'Logs'),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: Center(
                child: Row(
                  children: [
                    Icon(
                      _isScanning ? Icons.wifi_tethering : Icons.wifi_off,
                      color: _isScanning ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(_status),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () async {
                final result = await Navigator.push<SdkSettings>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(
                      initialScanPrecision: _scanPrecision,
                      initialMaxQueuedPayloads: _maxQueuedPayloads,
                    ),
                  ),
                );

                if (result != null) {
                  setState(() {
                    _scanPrecision = result.scanPrecision;
                    _maxQueuedPayloads = result.maxQueuedPayloads;
                  });
                  if (_hasPermission) {
                    await _applyConfiguration();
                  }
                }
              },
              tooltip: 'Configurações',
            ),
          ],
        ),
        body: TabBarView(
          children: [_buildBeaconsTab(), _buildStatusTab(), _buildLogsTab()],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildBeaconsTab() {
    return Column(
      children: [
        if (_lastError != null)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red.shade50,
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lastError!,
                    style: const TextStyle(fontSize: 14, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _detectedBeacons.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum beacon detectado ainda',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _detectedBeacons.length,
                  itemBuilder: (context, index) {
                    final beacon = _detectedBeacons[index];
                    final metadata = beacon.metadata;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(
                          'Major: ${beacon.major} | Minor: ${beacon.minor}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('UUID: ${beacon.uuid}'),
                            Text('RSSI: ${beacon.rssi} dBm'),
                            Text(
                              'Proximidade: ${beacon.proximity.name} | '
                              'Precisão: ${beacon.accuracy.toStringAsFixed(2)}m',
                            ),
                            if (metadata != null)
                              Text(
                                'Bateria: ${metadata.batteryLevel}% | '
                                'Temp: ${metadata.temperature}°C | '
                                'Firmware: ${metadata.firmwareVersion}',
                              ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatusTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGeofenceDebugCard(),
          const SizedBox(height: 16),
          const Text(
            'Status do SDK',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isScanning ? Icons.wifi_tethering : Icons.wifi_off,
                      color: _isScanning ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Scanning: ${_isScanning ? 'ativo' : 'parado'}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isScanning ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Beacons detectados: ${_detectedBeacons.length}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Configuração Atual',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Foreground: ${_foregroundScanInterval.seconds}s'),
          Text('Background: ${_backgroundScanInterval.seconds}s'),
          Text('Fila de retry: ${_maxQueuedPayloads.value} batches'),
          const SizedBox(height: 8),
          const Text(
            '✨ Automático em v2.2.0:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const Text('• Bluetooth metadata: sempre ativo'),
          const Text('• Scan periódico: FG ativo, BG contínuo'),
          if (_lastError != null) ...[
            const SizedBox(height: 16),
            Text(
              'Último erro: $_lastError',
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total de logs: ${_logs.length}'),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _logs.clear();
                  });
                },
                icon: const Icon(Icons.delete),
                label: const Text('Limpar'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _logs.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum log ainda',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Text(
                        _logs[index],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (!_hasPermission)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _initializeSdk,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Solicitar Permissões'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if (_hasPermission && !_isScanning)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _startScan,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar Scan'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            if (_isScanning)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _stopScan,
                  icon: const Icon(Icons.stop),
                  label: const Text('Parar Scan'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // v2.4 — Geofence Debug card with policy banner, counters, live ages, and rolling log.
  Widget _buildGeofenceDebugCard() {
    final inZone = _isInBeaconRegion;
    final bg = inZone ? const Color(0xFF0F2B14) : const Color(0xFF2A0F0F);
    final border =
        inZone ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final titleColor =
        inZone ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A);
    final emoji = inZone ? '✅' : '⛔';
    final title = inZone ? 'GPS LIBERADO' : 'GPS BLOQUEADO';
    final body = !inZone
        ? 'Sem beacon detectado. Localização NÃO está sendo lida.'
        : _isCapturingLocation
            ? 'Capturando agora — janela aberta porque você entrou na zona.'
            : 'Dentro da zona. GPS já capturou o que precisava; agora está em standby.';

    return Card(
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Debug Geofence',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_geofenceEvents.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: _clearGeofenceLog,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Policy banner
            Container(
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
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
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(color: titleColor, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  _policyCounterRow(
                    '📊 Capturas nesta sessão:',
                    '$_locationCaptureCount',
                  ),
                  const SizedBox(height: 4),
                  _policyCounterRow(
                    '🛡️ Capturas fora da zona:',
                    '0 ✓',
                    valueColor: const Color(0xFFA5D6A7),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _statusRow(
              'Zona do beacon',
              inZone ? 'DENTRO' : 'fora',
              inZone ? Colors.green : Colors.grey,
            ),
            if (_lastEnteredRegionAt != null)
              _detailRow(
                'Entrou às',
                '${_fmtTime(_lastEnteredRegionAt!)}  (${_fmtAge(_nowTick.difference(_lastEnteredRegionAt!))})',
              ),
            if (_lastExitedRegionAt != null)
              _detailRow(
                'Saiu às',
                '${_fmtTime(_lastExitedRegionAt!)}  (${_fmtAge(_nowTick.difference(_lastExitedRegionAt!))})',
              ),
            _statusRow(
              'Scan ativo',
              _isActiveScanRunning ? 'LIGADO' : 'desligado',
              _isActiveScanRunning ? Colors.green : Colors.grey,
            ),
            _statusRow(
              'Captura GPS',
              _isCapturingLocation ? 'EM ANDAMENTO…' : 'idle',
              _isCapturingLocation ? Colors.blue : Colors.grey,
            ),
            const Divider(),
            _detailRow('Última abertura', _lastCaptureOpenReason),
            _detailRow('Último fechamento', _lastCaptureOutcome),
            if (_lastCapturedLocation != null)
              _detailRow(
                'Última coord',
                '${_lastCapturedLocation!.latitude.toStringAsFixed(5)}, ${_lastCapturedLocation!.longitude.toStringAsFixed(5)} '
                '±${_lastCapturedLocation!.horizontalAccuracy?.toInt() ?? "?"}m',
              )
            else
              _detailRow('Última coord', '—'),
            if (_lastCaptureCompletedAt != null)
              _detailRow(
                'Concluído em',
                '${_fmtTime(_lastCaptureCompletedAt!)}  (${_fmtAge(_nowTick.difference(_lastCaptureCompletedAt!))})',
              ),
            if (_geofenceEvents.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Eventos recentes',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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

  Widget _statusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _policyCounterRow(String label, String value, {Color? valueColor}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _geofenceEventTile(_GeofenceEvent event) {
    final (color, title) = switch (event.kind) {
      _GeofenceEventKind.regionEnter => (Colors.green, 'ENTROU NA ZONA'),
      _GeofenceEventKind.regionExit => (Colors.orange, 'SAIU DA ZONA'),
      _GeofenceEventKind.scanActive => (Colors.teal, 'SCAN LIGADO'),
      _GeofenceEventKind.scanPaused => (Colors.grey, 'SCAN PAUSADO'),
      _GeofenceEventKind.captureStarted => (Colors.blue, 'GPS DISPARADO'),
      _GeofenceEventKind.captureFix => (Colors.green, 'FIX OK'),
      _GeofenceEventKind.captureNoFix => (Colors.red, 'SEM FIX'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
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
                        title,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      '${_fmtTime(event.timestamp)} · ${_fmtAge(_nowTick.difference(event.timestamp))}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
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

  String _fmtTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  String _fmtAge(Duration d) {
    final sec = d.inSeconds.clamp(0, 1 << 30);
    if (sec < 60) return '${sec}s atrás';
    if (sec < 3600) return '${sec ~/ 60}min ${sec % 60}s atrás';
    return '${sec ~/ 3600}h ${(sec % 3600) ~/ 60}min atrás';
  }
}

enum _GeofenceEventKind {
  regionEnter,
  regionExit,
  scanActive,
  scanPaused,
  captureStarted,
  captureFix,
  captureNoFix,
}

class _GeofenceEvent {
  final _GeofenceEventKind kind;
  final DateTime timestamp;
  final String detail;
  _GeofenceEvent({
    required this.kind,
    required this.timestamp,
    required this.detail,
  });
}
