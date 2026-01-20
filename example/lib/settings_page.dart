import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:flutter/material.dart';

class SdkSettings {
  final ForegroundScanInterval foregroundScanInterval;
  final BackgroundScanInterval backgroundScanInterval;
  final MaxQueuedPayloads maxQueuedPayloads;

  const SdkSettings({
    required this.foregroundScanInterval,
    required this.backgroundScanInterval,
    required this.maxQueuedPayloads,
  });
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.initialForegroundScanInterval,
    required this.initialBackgroundScanInterval,
    required this.initialMaxQueuedPayloads,
  });

  final ForegroundScanInterval initialForegroundScanInterval;
  final BackgroundScanInterval initialBackgroundScanInterval;
  final MaxQueuedPayloads initialMaxQueuedPayloads;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late ForegroundScanInterval _foregroundScanInterval;
  late BackgroundScanInterval _backgroundScanInterval;
  late MaxQueuedPayloads _maxQueuedPayloads;

  @override
  void initState() {
    super.initState();
    _foregroundScanInterval = widget.initialForegroundScanInterval;
    _backgroundScanInterval = widget.initialBackgroundScanInterval;
    _maxQueuedPayloads = widget.initialMaxQueuedPayloads;
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
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✨ Automático em v2.2.0',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• Bluetooth Metadata: sempre ativo'),
                  Text('  (coleta bateria, firmware e temperatura)'),
                  SizedBox(height: 8),
                  Text('• Scan Periódico:'),
                  Text('  - Foreground: ativo (economia de bateria)'),
                  Text('  - Background: contínuo (máxima detecção)'),
                ],
              ),
            ),
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
