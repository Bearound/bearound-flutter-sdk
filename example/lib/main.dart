import 'package:flutter/material.dart';
import 'dart:async';
import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';

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

class _BeaconHomePageState extends State<BeaconHomePage> {
  bool _hasPermission = false;
  bool _isScanning = false;
  String _status = "Parado";

  // Listeners
  StreamSubscription<BeaconsDetectedEvent>? _beaconsSubscription;
  StreamSubscription<BeaconEvent>? _syncSubscription;
  StreamSubscription<BeaconEvent>? _regionSubscription;

  // Data
  List<Beacon> _detectedBeacons = [];
  final List<String> _logs = [];
  String _lastSyncStatus = "Nenhuma sincronização ainda";
  String _regionStatus = "Fora de região";

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermission();
  }

  @override
  void dispose() {
    _beaconsSubscription?.cancel();
    _syncSubscription?.cancel();
    _regionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAndRequestPermission() async {
    final granted = await BearoundFlutterSdk.requestPermissions();
    setState(() {
      _hasPermission = granted;
      _status = granted ? "Permissões OK" : "Permissões necessárias!";
    });
  }

  void _startListening() {
    // Listen to beacon detection events
    _beaconsSubscription = BearoundFlutterSdk.beaconsStream.listen((event) {
      setState(() {
        _detectedBeacons = event.beacons;
        _addLog(
          '📡 Beacons detectados (${event.eventType.name}): ${event.beacons.length}',
        );
      });
    });

    // Listen to sync events
    _syncSubscription = BearoundFlutterSdk.syncStream.listen((event) {
      if (event is SyncSuccessEvent) {
        setState(() {
          _lastSyncStatus =
              '✅ Sucesso: ${event.beaconsCount} beacons (${event.eventType})';
          _addLog('✅ Sync sucesso: ${event.message}');
        });
      } else if (event is SyncErrorEvent) {
        setState(() {
          _lastSyncStatus =
              '❌ Erro: ${event.errorMessage} (código: ${event.errorCode})';
          _addLog('❌ Sync erro: ${event.errorMessage}');
        });
      }
    });

    // Listen to region events
    _regionSubscription = BearoundFlutterSdk.regionStream.listen((event) {
      if (event is BeaconRegionEnterEvent) {
        setState(() {
          _regionStatus = '🟢 Dentro da região: ${event.regionName}';
          _addLog('🟢 Entrou na região: ${event.regionName}');
        });
      } else if (event is BeaconRegionExitEvent) {
        setState(() {
          _regionStatus = '🔴 Fora da região: ${event.regionName}';
          _addLog('🔴 Saiu da região: ${event.regionName}');
        });
      }
    });
  }

  void _addLog(String log) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _logs.insert(0, '[$timestamp] $log');
    if (_logs.length > 50) {
      _logs.removeLast();
    }
  }

  Future<void> _startScan() async {
    await BearoundFlutterSdk.startScan("test_token", debug: true);
    setState(() {
      _isScanning = true;
      _status = "Scanning…";
    });
    _startListening();
    _addLog('🚀 Scanner iniciado');
  }

  Future<void> _stopScan() async {
    await BearoundFlutterSdk.stopScan();
    _beaconsSubscription?.cancel();
    _syncSubscription?.cancel();
    _regionSubscription?.cancel();

    setState(() {
      _isScanning = false;
      _status = "Parado";
      _detectedBeacons = [];
      _lastSyncStatus = "Nenhuma sincronização ainda";
      _regionStatus = "Fora de região";
    });
    _addLog('🛑 Scanner parado');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bearound SDK Example'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.radar), text: 'Beacons'),
              Tab(icon: Icon(Icons.sync), text: 'Sync'),
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
          ],
        ),
        body: TabBarView(
          children: [_buildBeaconsTab(), _buildSyncTab(), _buildLogsTab()],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildBeaconsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _regionStatus,
                  style: const TextStyle(fontSize: 16),
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
                            if (beacon.bluetoothName != null)
                              Text('Nome: ${beacon.bluetoothName}'),
                            if (beacon.distanceMeters != null)
                              Text(
                                'Distância: ${beacon.distanceMeters!.toStringAsFixed(2)}m',
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

  Widget _buildSyncTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status de Sincronização com API',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _lastSyncStatus.contains('✅')
                            ? Icons.check_circle
                            : Icons.error,
                        color: _lastSyncStatus.contains('✅')
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Último Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_lastSyncStatus),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Informações:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '• O SDK sincroniza automaticamente os beacons detectados com a API\n'
            '• Eventos de sucesso mostram quantos beacons foram enviados\n'
            '• Eventos de erro mostram o código e mensagem de erro',
            style: TextStyle(color: Colors.grey),
          ),
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
                  onPressed: _checkAndRequestPermission,
                  icon: const Icon(Icons.lock_open),
                  label: const Text("Solicitar Permissões"),
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
                  label: const Text("Iniciar Scan"),
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
                  label: const Text("Parar Scan"),
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
