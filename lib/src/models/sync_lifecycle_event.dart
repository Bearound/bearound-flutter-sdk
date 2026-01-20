/// Represents a sync lifecycle event from the native SDK.
///
/// v2.2.0: Added to track sync operations start and completion.
class SyncLifecycleEvent {
  /// Type of sync event: 'started' or 'completed'
  final String type;

  /// Number of beacons involved in the sync operation
  final int beaconCount;

  /// Whether the sync completed successfully (only for 'completed' type)
  final bool? success;

  /// Error message if sync failed (only for 'completed' type when success is false)
  final String? error;

  const SyncLifecycleEvent({
    required this.type,
    required this.beaconCount,
    this.success,
    this.error,
  });

  /// Creates a SyncLifecycleEvent from a JSON map
  factory SyncLifecycleEvent.fromJson(Map<String, dynamic> json) {
    return SyncLifecycleEvent(
      type: json['type'] as String? ?? 'unknown',
      beaconCount: (json['beaconCount'] as num?)?.toInt() ?? 0,
      success: json['success'] as bool?,
      error: json['error'] as String?,
    );
  }

  /// Returns true if this is a sync started event
  bool get isStarted => type == 'started';

  /// Returns true if this is a sync completed event
  bool get isCompleted => type == 'completed';

  @override
  String toString() {
    if (isStarted) {
      return 'SyncLifecycleEvent(type: $type, beaconCount: $beaconCount)';
    }
    return 'SyncLifecycleEvent(type: $type, beaconCount: $beaconCount, success: $success, error: $error)';
  }
}
