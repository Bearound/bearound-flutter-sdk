/// Scan precision modes.
///
/// Replaces the legacy `ForegroundScanInterval`/`BackgroundScanInterval` enums.
/// A single precision setting controls the duty cycle for both BLE and CoreLocation
/// scanning, matching the native iOS/Android v2.4.0 API.
///
/// - **High** — continuous BLE+CL scan, sync every 15s
/// - **Medium** — 3 cycles of 10s scan + 10s pause per 60s window (default)
/// - **Low** — 1 cycle of 10s scan + 50s pause per 60s window
enum ScanPrecision {
  /// Continuous scan, sync every 15s.
  high('high'),

  /// 3 cycles of 10s scan + 10s pause per 60s window (default).
  medium('medium'),

  /// 1 cycle of 10s scan + 50s pause per 60s window.
  low('low');

  const ScanPrecision(this.value);

  /// String value passed across the platform channel.
  final String value;
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
