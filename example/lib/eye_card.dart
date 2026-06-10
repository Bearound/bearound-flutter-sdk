import 'package:flutter/material.dart';

enum EyeKind { location, bluetooth }

class EyeCardData {
  final bool available;
  final bool isInZone;
  final DateTime? lastEnter;
  final DateTime? lastExit;
  final int enterCount;
  final int beaconsNow;
  final int totalDetected;
  final String modeLabel;
  final bool modeIsActive;
  final String cadenceLabel;
  final DateTime? nextScanAt;

  const EyeCardData({
    required this.available,
    required this.isInZone,
    this.lastEnter,
    this.lastExit,
    required this.enterCount,
    required this.beaconsNow,
    required this.totalDetected,
    required this.modeLabel,
    required this.modeIsActive,
    required this.cadenceLabel,
    this.nextScanAt,
  });
}

class EyeCard extends StatelessWidget {
  final EyeKind eye;
  final EyeCardData data;
  final DateTime now;

  const EyeCard({
    super.key,
    required this.eye,
    required this.data,
    required this.now,
  });

  Color get _color => eye == EyeKind.location
      ? const Color(0xFF4CAF50)
      : const Color(0xFF2196F3);
  String get _title => eye == EyeKind.location ? '👁 Location' : '👁 Bluetooth';
  String get _sub =>
      eye == EyeKind.location ? 'CoreLocation region' : 'CBCentralManager BLE';

  @override
  Widget build(BuildContext context) {
    if (!data.available) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          border: Border.all(color: const Color(0xFF1F1F1F)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _sub,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'N/A nesta plataforma',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final inZone = data.isInZone;
    final countdown = _countdown();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: inZone
            ? _color.withValues(alpha: 0.08)
            : const Color(0xFF141414),
        border: Border.all(color: inZone ? _color : const Color(0xFF1F1F1F)),
        borderRadius: BorderRadius.circular(10),
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
                  color: inZone ? _color : Colors.grey.shade700,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(_sub, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              inZone ? 'NA ZONA' : 'FORA',
              style: TextStyle(
                color: inZone ? _color : Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _stat('Agora', '${data.beaconsNow}'),
          _stat('Total visto', '${data.totalDetected}'),
          _stat('Entradas', '${data.enterCount}'),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Modo',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: data.modeIsActive
                      ? _color.withValues(alpha: 0.13)
                      : const Color(0xFF1A1A1A),
                  border: Border.all(
                    color: data.modeIsActive ? _color : const Color(0xFF2A2A2A),
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.modeLabel,
                  style: TextStyle(
                    color: data.modeIsActive ? _color : Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Text(
            data.cadenceLabel,
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
          if (countdown != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Próx. scan em $countdown',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          const Divider(color: Color(0xFF1F1F1F)),
          Text(
            'Entrou: ${_fmt(data.lastEnter)}',
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
          Text(
            'Saiu: ${_fmt(data.lastExit)}',
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime? t) {
    if (t == null) return '--';
    String pad(int v) => v.toString().padLeft(2, '0');
    return '${pad(t.hour)}:${pad(t.minute)}:${pad(t.second)}';
  }

  String? _countdown() {
    if (data.nextScanAt == null) return null;
    final remaining = data.nextScanAt!.difference(now).inSeconds;
    if (remaining < 0) return null;
    final m = remaining ~/ 60;
    final s = remaining % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
