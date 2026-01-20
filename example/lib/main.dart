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

  ForegroundScanInterval _foregroundScanInterval =
      ForegroundScanInterval.seconds15;
  BackgroundScanInterval _backgroundScanInterval =
      BackgroundScanInterval.seconds30;
  MaxQueuedPayloads _maxQueuedPayloads = MaxQueuedPayloads.medium;

  List<Beacon> _detectedBeacons = [];
  final List<String> _logs = [];
  SyncStatus _syncStatus = const SyncStatus(
    secondsUntilNextSync: 0,
    isRanging: false,
  );
  String? _lastError;

  StreamSubscription<List<Beacon>>? _beaconsSubscription;
  StreamSubscription<SyncStatus>? _syncSubscription;
  StreamSubscription<bool>? _scanningSubscription;
  StreamSubscription<BearoundError>? _errorSubscription;
  StreamSubscription<SyncLifecycleEvent>? _syncLifecycleSubscription;
  StreamSubscription<BackgroundDetectionEvent>?
  _backgroundDetectionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startListening();
    _initializeSdk();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _beaconsSubscription?.cancel();
    _syncSubscription?.cancel();
    _scanningSubscription?.cancel();
    _errorSubscription?.cancel();
    _syncLifecycleSubscription?.cancel();
    _backgroundDetectionSubscription?.cancel();
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
        foregroundScanInterval: _foregroundScanInterval,
        backgroundScanInterval: _backgroundScanInterval,
        maxQueuedPayloads: _maxQueuedPayloads,
      );

      _addLog(
        '⚙️ Configurado: FG ${_foregroundScanInterval.seconds}s, '
        'BG ${_backgroundScanInterval.seconds}s, '
        'Queue ${_maxQueuedPayloads.value} '
        '(BLE metadata e scan periódico são automáticos em v2.2.0)',
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

    // Sync status stream (deprecated but kept for compatibility)
    _syncSubscription = BearoundFlutterSdk.syncStream.listen((status) {
      debugPrint(
        '[DEBUG] 🔄 Sync status: ${status.secondsUntilNextSync}s, ranging: ${status.isRanging}',
      );
      setState(() {
        _syncStatus = status;
      });
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

    debugPrint('[DEBUG] ✅ Todos os streams inicializados');
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

    await _applyConfiguration();
    try {
      await BearoundFlutterSdk.startScanning();
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
      _syncStatus = const SyncStatus(secondsUntilNextSync: 0, isRanging: false);
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
                      initialForegroundScanInterval: _foregroundScanInterval,
                      initialBackgroundScanInterval: _backgroundScanInterval,
                      initialMaxQueuedPayloads: _maxQueuedPayloads,
                    ),
                  ),
                );

                if (result != null) {
                  setState(() {
                    _foregroundScanInterval = result.foregroundScanInterval;
                    _backgroundScanInterval = result.backgroundScanInterval;
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                Text('Scanning: ${_isScanning ? 'ativo' : 'parado'}'),
                const SizedBox(height: 8),
                Text('Próxima sync: ${_syncStatus.secondsUntilNextSync}s'),
                const SizedBox(height: 8),
                Text('Ranging: ${_syncStatus.isRanging ? 'ativo' : 'inativo'}'),
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
}
