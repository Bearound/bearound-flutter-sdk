import 'package:flutter/material.dart';

class SdkSettings {
  final int syncIntervalSeconds;
  final bool enableBluetoothScanning;
  final bool enablePeriodicScanning;

  const SdkSettings({
    required this.syncIntervalSeconds,
    required this.enableBluetoothScanning,
    required this.enablePeriodicScanning,
  });
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.initialSyncIntervalSeconds,
    required this.initialBluetoothScanning,
    required this.initialPeriodicScanning,
  });

  final int initialSyncIntervalSeconds;
  final bool initialBluetoothScanning;
  final bool initialPeriodicScanning;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int _syncIntervalSeconds;
  late bool _enableBluetoothScanning;
  late bool _enablePeriodicScanning;

  @override
  void initState() {
    super.initState();
    _syncIntervalSeconds = widget.initialSyncIntervalSeconds;
    _enableBluetoothScanning = widget.initialBluetoothScanning;
    _enablePeriodicScanning = widget.initialPeriodicScanning;
  }

  String _intervalLabel(int value) {
    if (value <= 10) {
      return 'Alta frequência';
    }
    if (value <= 30) {
      return 'Balanceado';
    }
    return 'Economia de bateria';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Intervalo de Sincronização',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '$_syncIntervalSeconds segundos (${_intervalLabel(_syncIntervalSeconds)})',
            style: const TextStyle(color: Colors.grey),
          ),
          Slider(
            value: _syncIntervalSeconds.toDouble(),
            min: 5,
            max: 60,
            divisions: 11,
            label: '$_syncIntervalSeconds s',
            onChanged: (value) {
              setState(() {
                _syncIntervalSeconds = value.round();
              });
            },
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Bluetooth Metadata'),
            subtitle: const Text('Coleta bateria, firmware e temperatura'),
            value: _enableBluetoothScanning,
            onChanged: (value) {
              setState(() {
                _enableBluetoothScanning = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Scan Periódico'),
            subtitle: const Text('Melhora consumo de bateria'),
            value: _enablePeriodicScanning,
            onChanged: (value) {
              setState(() {
                _enablePeriodicScanning = value;
              });
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(
                context,
                SdkSettings(
                  syncIntervalSeconds: _syncIntervalSeconds,
                  enableBluetoothScanning: _enableBluetoothScanning,
                  enablePeriodicScanning: _enablePeriodicScanning,
                ),
              );
            },
            icon: const Icon(Icons.save),
            label: const Text('Aplicar configurações'),
          ),
        ],
      ),
    );
  }
}
