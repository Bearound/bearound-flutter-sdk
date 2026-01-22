/// Foreground scan interval configuration.
///
/// Controls how frequently the SDK scans for beacons when the app is in foreground.
enum ForegroundScanInterval {
  /// Scan every 5 seconds (continuous mode - no pause between scans)
  ///
  /// Note: When using 5-second interval, the SDK uses continuous scanning
  /// for maximum beacon detection. Other intervals use periodic scanning
  /// with calculated scan/pause durations.
  seconds5(5),

  /// Scan every 10 seconds
  seconds10(10),

  /// Scan every 15 seconds (default)
  seconds15(15),

  /// Scan every 20 seconds
  seconds20(20),

  /// Scan every 25 seconds
  seconds25(25),

  /// Scan every 30 seconds
  seconds30(30),

  /// Scan every 35 seconds
  seconds35(35),

  /// Scan every 40 seconds
  seconds40(40),

  /// Scan every 45 seconds
  seconds45(45),

  /// Scan every 50 seconds
  seconds50(50),

  /// Scan every 55 seconds
  seconds55(55),

  /// Scan every 60 seconds
  seconds60(60);

  const ForegroundScanInterval(this.seconds);

  /// The interval value in seconds
  final int seconds;
}

/// Background scan interval configuration.
///
/// Controls how frequently the SDK scans for beacons when the app is in background.
enum BackgroundScanInterval {
  /// Scan every 15 seconds
  seconds15(15),

  /// Scan every 30 seconds (default)
  seconds30(30),

  /// Scan every 60 seconds
  seconds60(60),

  /// Scan every 90 seconds
  seconds90(90),

  /// Scan every 120 seconds
  seconds120(120);

  const BackgroundScanInterval(this.seconds);

  /// The interval value in seconds
  final int seconds;
}

/// Maximum queued payloads configuration.
///
/// Controls how many failed API request batches are stored for retry.
/// Each batch contains all beacons from a single sync operation.
enum MaxQueuedPayloads {
  /// Store up to 50 failed batches
  small(50),

  /// Store up to 100 failed batches (default)
  medium(100),

  /// Store up to 200 failed batches
  large(200),

  /// Store up to 500 failed batches
  xlarge(500);

  const MaxQueuedPayloads(this.value);

  /// The maximum number of failed batches that can be queued
  final int value;
}
