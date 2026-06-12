import 'beacon_discovery_source.dart';
import 'beacon_metadata.dart';
import 'rssi_stats.dart';

enum BeaconProximity {
  immediate,
  near,
  far,
  bt,
  unknown;

  static BeaconProximity fromString(String value) {
    switch (value.toLowerCase()) {
      case 'immediate':
        return BeaconProximity.immediate;
      case 'near':
        return BeaconProximity.near;
      case 'far':
        return BeaconProximity.far;
      case 'bt':
        return BeaconProximity.bt;
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

  /// Whether this beacon has already been synced to the ingest API.
  final bool alreadySynced;

  /// Epoch ms of the last successful sync for this beacon, if any.
  final DateTime? syncedAt;

  /// iOS-only. Which detector(s) saw this beacon. Drives the "two eyes" model.
  /// Absent on Android (BLE-only).
  final List<BeaconDiscoverySource> discoverySources;

  /// Android-only. Raw (unsmoothed) RSSI of the latest sample.
  final int? rssiRaw;

  /// Android-only. See [RssiStats].
  final RssiStats? rssiSamples;

  /// Android-only. True when the beacon hasn't been seen within the freshness
  /// window.
  final bool isStale;

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
    this.alreadySynced = false,
    this.syncedAt,
    this.discoverySources = const [],
    this.rssiRaw,
    this.rssiSamples,
    this.isStale = false,
  });

  /// Identifier used by the example apps to bucket beacons: "major.minor".
  String get identifier => '$major.$minor';

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

    final syncedAtRaw = json['syncedAt'];
    DateTime? syncedAt;
    if (syncedAtRaw is int) {
      syncedAt = DateTime.fromMillisecondsSinceEpoch(syncedAtRaw);
    } else if (syncedAtRaw is double) {
      syncedAt = DateTime.fromMillisecondsSinceEpoch(syncedAtRaw.round());
    }

    final discoverySourcesRaw = json['discoverySources'];
    final List<BeaconDiscoverySource> discoverySources = [];
    if (discoverySourcesRaw is List) {
      for (final entry in discoverySourcesRaw) {
        final parsed = BeaconDiscoverySource.fromString(entry.toString());
        if (parsed != null) {
          discoverySources.add(parsed);
        }
      }
    }

    final rssiSamplesRaw = json['rssiSamples'];
    RssiStats? rssiSamples;
    if (rssiSamplesRaw is Map) {
      rssiSamples = RssiStats.fromJson(
        Map<String, dynamic>.from(rssiSamplesRaw),
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
      alreadySynced: json['alreadySynced'] as bool? ?? false,
      syncedAt: syncedAt,
      discoverySources: discoverySources,
      rssiRaw: (json['rssiRaw'] as num?)?.toInt(),
      rssiSamples: rssiSamples,
      isStale: json['isStale'] as bool? ?? false,
    );
  }
}
