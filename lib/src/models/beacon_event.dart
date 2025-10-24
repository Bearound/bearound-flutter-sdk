import 'beacon.dart';

/// Enum representing the type of beacon event (ENTER or EXIT)
enum BeaconEventType {
  enter,
  exit;

  static BeaconEventType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'ENTER':
        return BeaconEventType.enter;
      case 'EXIT':
        return BeaconEventType.exit;
      default:
        throw ArgumentError('Invalid BeaconEventType: $value');
    }
  }
}

/// Base class for all beacon events
abstract class BeaconEvent {
  const BeaconEvent();

  factory BeaconEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;

    switch (type) {
      case 'beaconsDetected':
        return BeaconsDetectedEvent.fromJson(json);
      case 'beaconRegionEnter':
        return BeaconRegionEnterEvent.fromJson(json);
      case 'beaconRegionExit':
        return BeaconRegionExitEvent.fromJson(json);
      case 'syncSuccess':
        return SyncSuccessEvent.fromJson(json);
      case 'syncError':
        return SyncErrorEvent.fromJson(json);
      default:
        throw ArgumentError('Unknown event type: $type');
    }
  }
}

/// Event emitted when beacons are detected
class BeaconsDetectedEvent extends BeaconEvent {
  final List<Beacon> beacons;
  final BeaconEventType eventType;

  const BeaconsDetectedEvent({
    required this.beacons,
    required this.eventType,
  });

  factory BeaconsDetectedEvent.fromJson(Map<String, dynamic> json) {
    final beaconsList = (json['beacons'] as List<dynamic>)
        .map((e) => Beacon.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return BeaconsDetectedEvent(
      beacons: beaconsList,
      eventType: BeaconEventType.fromString(json['eventType'] as String),
    );
  }
}

/// Event emitted when entering a beacon region
class BeaconRegionEnterEvent extends BeaconEvent {
  final String regionName;

  const BeaconRegionEnterEvent({required this.regionName});

  factory BeaconRegionEnterEvent.fromJson(Map<String, dynamic> json) {
    return BeaconRegionEnterEvent(
      regionName: json['regionName'] as String,
    );
  }
}

/// Event emitted when exiting a beacon region
class BeaconRegionExitEvent extends BeaconEvent {
  final String regionName;

  const BeaconRegionExitEvent({required this.regionName});

  factory BeaconRegionExitEvent.fromJson(Map<String, dynamic> json) {
    return BeaconRegionExitEvent(
      regionName: json['regionName'] as String,
    );
  }
}

/// Event emitted when sync with API succeeds
class SyncSuccessEvent extends BeaconEvent {
  final String eventType;
  final int beaconsCount;
  final String message;

  const SyncSuccessEvent({
    required this.eventType,
    required this.beaconsCount,
    required this.message,
  });

  factory SyncSuccessEvent.fromJson(Map<String, dynamic> json) {
    return SyncSuccessEvent(
      eventType: json['eventType'] as String,
      beaconsCount: json['beaconsCount'] as int,
      message: json['message'] as String,
    );
  }
}

/// Event emitted when sync with API fails
class SyncErrorEvent extends BeaconEvent {
  final String eventType;
  final String errorMessage;
  final int beaconsCount;
  final int? errorCode;

  const SyncErrorEvent({
    required this.eventType,
    required this.errorMessage,
    required this.beaconsCount,
    this.errorCode,
  });

  factory SyncErrorEvent.fromJson(Map<String, dynamic> json) {
    return SyncErrorEvent(
      eventType: json['eventType'] as String,
      errorMessage: json['errorMessage'] as String,
      beaconsCount: json['beaconsCount'] as int,
      errorCode: json['errorCode'] as int?,
    );
  }
}