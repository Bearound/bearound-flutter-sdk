import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:flutter/material.dart';

class SdkSettings {
  final ScanPrecision scanPrecision;
  final MaxQueuedPayloads maxQueuedPayloads;

  const SdkSettings({
    required this.scanPrecision,
    required this.maxQueuedPayloads,
  });
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.initialScanPrecision,
    required this.initialMaxQueuedPayloads,
    this.sdkVersion = '',
  });

  final ScanPrecision initialScanPrecision;
  final MaxQueuedPayloads initialMaxQueuedPayloads;
  final String sdkVersion;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late ScanPrecision _scanPrecision;
  late MaxQueuedPayloads _maxQueuedPayloads;

  @override
  void initState() {
    super.initState();
    _scanPrecision = widget.initialScanPrecision;
    _maxQueuedPayloads = widget.initialMaxQueuedPayloads;
  }

  String _precisionLabel(ScanPrecision p) {
    switch (p) {
      case ScanPrecision.high:
        return 'High — scan contínuo, sync a cada 15s';
      case ScanPrecision.medium:
        return 'Medium — 3x (10s scan + 10s pause) / 60s';
      case ScanPrecision.low:
        return 'Low — 1x (10s scan + 50s pause) / 60s';
    }
  }

  String _queueLabel(MaxQueuedPayloads size) {
    switch (size) {
      case MaxQueuedPayloads.small:
        return 'Pequena (${size.value} batches)';
      case MaxQueuedPayloads.medium:
        return 'Média (${size.value} batches)';
      case MaxQueuedPayloads.large:
        return 'Grande (${size.value} batches)';
      case MaxQueuedPayloads.xlarge:
        return 'Extra Grande (${size.value} batches)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Precisão de Scan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButton<ScanPrecision>(
            value: _scanPrecision,
            isExpanded: true,
            items: ScanPrecision.values.map((p) {
              return DropdownMenuItem(
                value: p,
                child: Text(_precisionLabel(p)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _scanPrecision = value);
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
              return DropdownMenuItem(
                value: size,
                child: Text(_queueLabel(size)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _maxQueuedPayloads = value);
            },
          ),
          const SizedBox(height: 24),
          if (widget.sdkVersion.isNotEmpty)
            Card(
              child: ListTile(
                title: const Text('Versão do SDK nativo'),
                trailing: Text(
                  widget.sdkVersion,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✨ Doutrina v3.0',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• Default é HIGH — alinhado ao SDK iOS nativo'),
                  Text('• Dois olhos: Location + Bluetooth independentes'),
                  Text('• GPS-gating no Android: só dentro da zona'),
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
                  scanPrecision: _scanPrecision,
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
