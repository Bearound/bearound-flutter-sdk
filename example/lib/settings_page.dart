import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:flutter/material.dart';

class SdkSettings {
  final ForegroundScanInterval foregroundScanInterval;
  final BackgroundScanInterval backgroundScanInterval;
  final MaxQueuedPayloads maxQueuedPayloads;
  final bool enableBluetoothScanning;
  final bool enablePeriodicScanning;

  const SdkSettings({
    required this.foregroundScanInterval,
    required this.backgroundScanInterval,
    required this.maxQueuedPayloads,
    required this.enableBluetoothScanning,
    required this.enablePeriodicScanning,
  });
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.initialForegroundScanInterval,
    required this.initialBackgroundScanInterval,
    required this.initialMaxQueuedPayloads,
    required this.initialBluetoothScanning,
    required this.initialPeriodicScanning,
  });

  final ForegroundScanInterval initialForegroundScanInterval;
  final BackgroundScanInterval initialBackgroundScanInterval;
  final MaxQueuedPayloads initialMaxQueuedPayloads;
  final bool initialBluetoothScanning;
  final bool initialPeriodicScanning;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late ForegroundScanInterval _foregroundScanInterval;
  late BackgroundScanInterval _backgroundScanInterval;
  late MaxQueuedPayloads _maxQueuedPayloads;
  late bool _enableBluetoothScanning;
  late bool _enablePeriodicScanning;

  @override
  void initState() {
    super.initState();
    _foregroundScanInterval = widget.initialForegroundScanInterval;
    _backgroundScanInterval = widget.initialBackgroundScanInterval;
    _maxQueuedPayloads = widget.initialMaxQueuedPayloads;
    _enableBluetoothScanning = widget.initialBluetoothScanning;
    _enablePeriodicScanning = widget.initialPeriodicScanning;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Intervalo de Scan - Foreground',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButton<ForegroundScanInterval>(
            value: _foregroundScanInterval,
            isExpanded: true,
            items: ForegroundScanInterval.values.map((interval) {
              return DropdownMenuItem(
                value: interval,
                child: Text('${interval.seconds} segundos'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _foregroundScanInterval = value;
                });
              }
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Intervalo de Scan - Background',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButton<BackgroundScanInterval>(
            value: _backgroundScanInterval,
            isExpanded: true,
            items: BackgroundScanInterval.values.map((interval) {
              return DropdownMenuItem(
                value: interval,
                child: Text('${interval.seconds} segundos'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _backgroundScanInterval = value;
                });
              }
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Tamanho da Fila de Retry',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButton<MaxQueuedPayloads>(
            value: _maxQueuedPayloads,
            isExpanded: true,
            items: MaxQueuedPayloads.values.map((size) {
              String label;
              switch (size) {
                case MaxQueuedPayloads.small:
                  label = 'Pequena (${size.value} batches)';
                  break;
                case MaxQueuedPayloads.medium:
                  label = 'Média (${size.value} batches)';
                  break;
                case MaxQueuedPayloads.large:
                  label = 'Grande (${size.value} batches)';
                  break;
                case MaxQueuedPayloads.xlarge:
                  label = 'Extra Grande (${size.value} batches)';
                  break;
              }
              return DropdownMenuItem(value: size, child: Text(label));
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _maxQueuedPayloads = value;
                });
              }
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
                  foregroundScanInterval: _foregroundScanInterval,
                  backgroundScanInterval: _backgroundScanInterval,
                  maxQueuedPayloads: _maxQueuedPayloads,
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
