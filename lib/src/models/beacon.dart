import 'beacon_metadata.dart';

enum BeaconProximity {
  immediate,
  near,
  far,
  unknown;

  static BeaconProximity fromString(String value) {
    switch (value.toLowerCase()) {
      case 'immediate':
        return BeaconProximity.immediate;
      case 'near':
        return BeaconProximity.near;
      case 'far':
        return BeaconProximity.far;
      default:
        return BeaconProximity.unknown;
    }
  }
}

class Beacon {
  final String uuid;
  final int major;
  final int minor;
  final int rssi;
  final BeaconProximity proximity;
  final double accuracy;
  final DateTime timestamp;
  final BeaconMetadata? metadata;
  final int? txPower;

  const Beacon({
    required this.uuid,
    required this.major,
    required this.minor,
    required this.rssi,
    required this.proximity,
    required this.accuracy,
    required this.timestamp,
    this.metadata,
    this.txPower,
  });

  factory Beacon.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'];
    DateTime timestamp;

    if (rawTimestamp is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    } else if (rawTimestamp is double) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(rawTimestamp.round());
    } else {
      timestamp = DateTime.now();
    }

    final metadataValue = json['metadata'];
    BeaconMetadata? metadata;
    if (metadataValue is Map) {
      metadata = BeaconMetadata.fromJson(
        Map<String, dynamic>.from(metadataValue),
      );
    }

    return Beacon(
      uuid: json['uuid'] as String? ?? '',
      major: (json['major'] as num?)?.toInt() ?? 0,
      minor: (json['minor'] as num?)?.toInt() ?? 0,
      rssi: (json['rssi'] as num?)?.toInt() ?? 0,
      proximity: BeaconProximity.fromString(
        json['proximity'] as String? ?? 'unknown',
      ),
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      timestamp: timestamp,
      metadata: metadata,
      txPower: (json['txPower'] as num?)?.toInt(),
    );
  }
}
