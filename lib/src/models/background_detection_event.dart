/// Represents a beacon detection event that occurred while the app was in background.
///
/// v2.2.0: Added to notify when beacons are detected in background mode.
class BackgroundDetectionEvent {
  /// Number of beacons detected in the background
  final int beaconCount;

  const BackgroundDetectionEvent({required this.beaconCount});

  /// Creates a BackgroundDetectionEvent from a JSON map
  factory BackgroundDetectionEvent.fromJson(Map<String, dynamic> json) {
    return BackgroundDetectionEvent(
      beaconCount: (json['beaconCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() {
    return 'BackgroundDetectionEvent(beaconCount: $beaconCount)';
  }
}
