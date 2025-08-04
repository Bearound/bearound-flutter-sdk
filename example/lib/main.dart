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
  StreamSubscription<Beacon>? _beaconSub;
  Beacon? _lastBeacon;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermission();
  }

  @override
  void dispose() {
    _beaconSub?.cancel();
    super.dispose();
  }

  Future<void> _checkAndRequestPermission() async {
    final granted = await BearoundFlutterSdk.requestPermissions();
    setState(() {
      _hasPermission = granted;
      _status = granted ? "Permissões OK" : "Permissões necessárias!";
    });
  }

  Future<void> _startScan() async {
    await BearoundFlutterSdk.startScan(debug: true);
    _beaconSub?.cancel();
    _beaconSub = BearoundFlutterSdk.beaconStream.listen((beacon) {
      setState(() {
        _lastBeacon = beacon;
        _status = "Beacon detectado!";
      });
    });
    setState(() {
      _isScanning = true;
      _status = "Scanning…";
    });
  }

  Future<void> _stopScan() async {
    await BearoundFlutterSdk.stopScan();
    await _beaconSub?.cancel();
    setState(() {
      _isScanning = false;
      _status = "Parado";
      _lastBeacon == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bearound Flutter SDK Example'),
      ),
      body: Container(
        width: double.infinity,
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Parar Beacon Scan"),
              ),
            const SizedBox(height: 32),
            Text(
              "Beacons encontrados:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _lastBeacon == null
                ? const Text("Nenhum beacon detectado ainda.")
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Major: ${_lastBeacon!.major}"),
                        Text("Minor: ${_lastBeacon!.minor}"),
                        Text("RSSI: ${_lastBeacon!.rssi}"),
                        Text("Distância: ${_lastBeacon!.distanceMeters?.toStringAsFixed(2) ?? '--'} m"),
                      ],
                    ),
                  ),
                )
              ]
            ),
          ],
        ),
      ),
    );
  }
}
