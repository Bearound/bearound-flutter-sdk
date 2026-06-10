import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'events.dart';
import 'eye_card.dart';

class TwoEyesModal extends StatelessWidget {
  final EyeCardData location;
  final EyeCardData bluetooth;
  final List<GeofenceEventEntry> events;
  final VoidCallback onClearLog;
  final DateTime now;

  const TwoEyesModal({
    super.key,
    required this.location,
    required this.bluetooth,
    required this.events,
    required this.onClearLog,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text('👁 👁 Dois Olhos'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _summary('Location', const Color(0xFF4CAF50),
                    location.isInZone, '${location.beaconsNow} agora'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summary(
                  'Bluetooth',
                  const Color(0xFF2196F3),
                  bluetooth.isInZone,
                  bluetooth.available
                      ? '${bluetooth.modeLabel} · ${bluetooth.beaconsNow} agora'
                      : 'iOS-only',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: EyeCard(
                      eye: EyeKind.location, data: location, now: now)),
              const SizedBox(width: 10),
              Expanded(
                  child: EyeCard(
                      eye: EyeKind.bluetooth, data: bluetooth, now: now)),
            ],
          ),
          if (Platform.isAndroid)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                border: Border.all(color: const Color(0xFF1F1F1F)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'O modelo de "dois olhos" é exclusivo do iOS. No Android a '
                'detecção é BLE-only — só o olho de proximidade reflete dados '
                'reais.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Como ler',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    )),
                const SizedBox(height: 8),
                _legend(const Color(0xFF4CAF50), 'Location',
                    'iBeacon region monitoring (kernel level). Funciona mesmo com BT bloqueado no app.'),
                _legend(const Color(0xFF2196F3), 'Bluetooth',
                    'Scan BLE ativo. STANDBY = peek de 10s a cada 5min. ATIVO = scan contínuo.'),
                _legend(const Color(0xFFFF9800), 'Wake-up',
                    'Quando Location entra na zona, o olho BT acorda pra ATIVO imediatamente.'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Eventos ao vivo',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  )),
              if (events.isNotEmpty)
                TextButton(
                  onPressed: onClearLog,
                  child: const Text('Limpar',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
            ],
          ),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Nenhum evento ainda — aproxime de um beacon para disparar.',
                style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                    fontSize: 11),
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final event in events.take(20)) _eventRow(event),
        ],
      ),
    );
  }

  Widget _summary(String title, Color color, bool isOn, String detail) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isOn ? color.withValues(alpha: 0.12) : Colors.white12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isOn ? color : Colors.grey.shade700,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(detail,
                style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String title, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
                Text(title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    )),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(text,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventRow(GeofenceEventEntry event) {
    final color = geofenceEventColor(event.kind);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                      child: Text(geofenceEventTitle(event.kind),
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                    Text(_fmtTime(event.timestamp),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontFamily: 'monospace',
                          fontSize: 10,
                        )),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(event.detail,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime t) {
    String pad(int v) => v.toString().padLeft(2, '0');
    return '${pad(t.hour)}:${pad(t.minute)}:${pad(t.second)}';
  }
}
