/// Aggregated RSSI statistics over a sync window. **Android-only** — iOS does
/// not expose per-beacon RSSI sample aggregates.
class RssiStats {
  final int count;
  final int min;
  final int max;
  final double avg;
  final double stdDev;
  final int firstSeen;
  final int lastSeen;

  const RssiStats({
    required this.count,
    required this.min,
    required this.max,
    required this.avg,
    required this.stdDev,
    required this.firstSeen,
    required this.lastSeen,
  });

  factory RssiStats.fromJson(Map<String, dynamic> json) {
    return RssiStats(
      count: (json['count'] as num?)?.toInt() ?? 0,
      min: (json['min'] as num?)?.toInt() ?? 0,
      max: (json['max'] as num?)?.toInt() ?? 0,
      avg: (json['avg'] as num?)?.toDouble() ?? 0,
      stdDev: (json['stdDev'] as num?)?.toDouble() ?? 0,
      firstSeen: (json['firstSeen'] as num?)?.toInt() ?? 0,
      lastSeen: (json['lastSeen'] as num?)?.toInt() ?? 0,
    );
  }
}
