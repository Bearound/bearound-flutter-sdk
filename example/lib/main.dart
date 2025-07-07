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
    return const MaterialApp(
      home: BeaconHomePage(),
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
  String _lastEvent = "";
  StreamSubscription<Map<String, dynamic>>? _eventSub;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermission();
  }

  Future<void> _checkAndRequestPermission() async {
    final granted = await BearoundFlutterSdk.instance.requestPermissions();
    setState(() {
      _hasPermission = granted;
      _status = granted ? "Permissões OK" : "Permissões necessárias!";
    });
  }

  Future<void> _startScan() async {
    await BearoundFlutterSdk.instance.initialize(debug: true);
    _eventSub = BearoundFlutterSdk.instance.events.listen((event) {
      setState(() {
        _lastEvent = event.toString();
        _status = "Beacon evento recebido!";
      });
    });
    setState(() {
      _isScanning = true;
      _status = "Scanning…";
    });
  }

  Future<void> _stopScan() async {
    await BearoundFlutterSdk.instance.stop();
    await _eventSub?.cancel();
    setState(() {
      _isScanning = false;
      _status = "Parado";
      _lastEvent = "";
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bearound Flutter SDK Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isScanning ? Icons.wifi_tethering : Icons.wifi_off,
              size: 60,
              color: _isScanning ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              "Status: $_status",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            if (!_hasPermission)
              ElevatedButton(
                onPressed: _checkAndRequestPermission,
                child: const Text("Solicitar Permissões"),
              ),
            if (_hasPermission && !_isScanning)
              ElevatedButton(
                onPressed: _startScan,
                child: const Text("Iniciar Beacon Scan"),
              ),
            if (_isScanning)
              ElevatedButton(
                onPressed: _stopScan,
                child: const Text("Parar Beacon Scan"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            const SizedBox(height: 32),
            Text(
              "Último evento recebido:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                _lastEvent.isEmpty ? "Nenhum evento ainda…" : _lastEvent,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
