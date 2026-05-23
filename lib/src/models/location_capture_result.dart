/// A location coordinate captured during a beacon-triggered GPS window.
class CapturedLocation {
  /// Latitude in degrees (WGS84).
  final double latitude;

  /// Longitude in degrees (WGS84).
  final double longitude;

  /// Estimated horizontal accuracy in meters. `null` if unavailable.
  final double? horizontalAccuracy;

  /// Altitude in meters above the WGS84 ellipsoid. `null` if unavailable.
  final double? altitude;

  /// Instantaneous speed in m/s. `null` if unavailable.
  final double? speed;

  /// Direction of travel in degrees (0–360). `null` if unavailable.
  final double? course;

  /// Time the fix was generated (epoch ms).
  final int timestamp;

  const CapturedLocation({
    required this.latitude,
    required this.longitude,
    this.horizontalAccuracy,
    this.altitude,
    this.speed,
    this.course,
    required this.timestamp,
  });

  factory CapturedLocation.fromMap(Map<dynamic, dynamic> map) {
    return CapturedLocation(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      horizontalAccuracy: (map['horizontalAccuracy'] as num?)?.toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      course: (map['course'] as num?)?.toDouble(),
      timestamp:
          (map['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Outcome of a beacon-triggered location capture window.
///
/// v2.4: GPS is consulted only when a beacon is in range. When the SDK opens
/// a capture window, it stays open until the first acceptable fix arrives or
/// until the timeout elapses. This class reports what happened.
class LocationCaptureResult {
  /// Whether the capture window was just opened (`started`) or has closed (`completed`).
  ///
  /// When `started`, only [reason] is set.
  /// When `completed`, [outcome], [hasFix], [timestamp] are also set; [location]
  /// is set only if `hasFix == true`.
  final String type;

  /// Why the capture window was opened (e.g. `"beacon_rising_edge"`, `"stale_refresh"`).
  final String reason;

  /// Outcome label of the closed window (e.g. `"fix_acquired_acc=18m"`,
  /// `"timeout"`, `"beacons_lost"`). Empty when [type] == `started`.
  final String outcome;

  /// True if a usable fix was acquired during this window.
  final bool hasFix;

  /// When the window closed (epoch ms). Zero when [type] == `started`.
  final int timestamp;

  /// The acquired location, or `null` if [hasFix] is false.
  final CapturedLocation? location;

  const LocationCaptureResult({
    required this.type,
    required this.reason,
    this.outcome = '',
    this.hasFix = false,
    this.timestamp = 0,
    this.location,
  });

  factory LocationCaptureResult.fromMap(Map<dynamic, dynamic> map) {
    final type = (map['type'] as String?) ?? 'completed';
    final locMap = map['location'] as Map?;
    return LocationCaptureResult(
      type: type,
      reason: (map['reason'] as String?) ?? '',
      outcome: (map['outcome'] as String?) ?? '',
      hasFix: (map['hasFix'] as bool?) ?? false,
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      location: locMap != null ? CapturedLocation.fromMap(locMap) : null,
    );
  }

  /// True when the SDK has just opened a GPS capture window.
  bool get isStarted => type == 'started';

  /// True when the SDK has just closed a GPS capture window (with or without fix).
  bool get isCompleted => type == 'completed';
}

/// Beacon region transition event ("enter" or "exit").
class BeaconRegionEvent {
  /// Transition type: `'enter'` (rising edge) or `'exit'` (falling edge).
  final String type;

  const BeaconRegionEvent({required this.type});

  factory BeaconRegionEvent.fromMap(Map<dynamic, dynamic> map) {
    final t = (map['type'] as String?)?.toLowerCase() ?? 'enter';
    return BeaconRegionEvent(type: t == 'exit' ? 'exit' : 'enter');
  }

  bool get isEnter => type == 'enter';
  bool get isExit => type == 'exit';
}

/// Active-scan gate state ("LIGADO" / "desligado").
class ActiveScanEvent {
  /// True when ranging + BLE active scan are running. False when paused.
  final bool isActive;

  const ActiveScanEvent({required this.isActive});

  factory ActiveScanEvent.fromMap(Map<dynamic, dynamic> map) {
    return ActiveScanEvent(isActive: (map['isActive'] as bool?) ?? false);
  }
}

// region Two Eyes (v2.6)
//
// Bluetooth-only zone presence + duty cycle. The BT eye runs independently of
// CLBeaconRegion / BeaconManager region monitoring. See `BluetoothZoneEvent`
// (rising/falling edges) and `BluetoothScanModeEvent` (duty cycle).

/// BLE-only zone transition event ("enter" or "exit").
class BluetoothZoneEvent {
  /// Transition type: `'enter'` (rising edge) or `'exit'` (falling edge).
  final String type;

  const BluetoothZoneEvent({required this.type});

  factory BluetoothZoneEvent.fromMap(Map<dynamic, dynamic> map) {
    final t = (map['type'] as String?)?.toLowerCase() ?? 'enter';
    return BluetoothZoneEvent(type: t == 'exit' ? 'exit' : 'enter');
  }

  bool get isEnter => type == 'enter';
  bool get isExit => type == 'exit';
}

/// BT eye duty-cycle mode. `idle` = scanner off, peeks every 5min.
/// `active` = continuous scan, 10s heartbeat.
enum BluetoothScanMode {
  idle,
  active;

  static BluetoothScanMode fromString(String? raw) {
    return raw?.toLowerCase() == 'active' ? BluetoothScanMode.active : BluetoothScanMode.idle;
  }
}

/// Emitted whenever the BT eye flips between `idle` and `active`.
class BluetoothScanModeEvent {
  final BluetoothScanMode mode;

  /// Absolute time (epoch ms) of the next idle peek. Non-null only when mode
  /// is `idle`. Use this to render a live countdown in the UI.
  final int? nextIdleScanAtEpochMs;

  const BluetoothScanModeEvent({
    required this.mode,
    this.nextIdleScanAtEpochMs,
  });

  factory BluetoothScanModeEvent.fromMap(Map<dynamic, dynamic> map) {
    return BluetoothScanModeEvent(
      mode: BluetoothScanMode.fromString(map['mode'] as String?),
      nextIdleScanAtEpochMs: (map['nextIdleScanAtEpochMs'] as num?)?.toInt(),
    );
  }

  bool get isIdle => mode == BluetoothScanMode.idle;
  bool get isActive => mode == BluetoothScanMode.active;
}

// endregion
