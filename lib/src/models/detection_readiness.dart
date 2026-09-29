/// What this install can actually detect, in one value.
///
/// Beacon detection on iOS is not a boolean: it depends on the authorization the
/// user granted (runtime) and the background modes the app declared (build time).
/// The SDK can ask for the first and read the second; it can grant neither. So
/// instead of leaving the app to infer the regime from an error string, it names it.
///
/// It describes durable capability, not the radio: Bluetooth turned off stops
/// detection in every regime and is reported separately by `getBluetoothState()`.
///
/// An **iOS** signal. On Android, and on native SDKs without `detectionReadiness`,
/// the value arrives as [DetectionReadiness.unknown].
enum DetectionReadiness {
  /// Location `Always` + full accuracy. Region monitoring arms, so iOS relaunches
  /// the app on region entry, **even after a force-quit**. The only regime with a
  /// deterministic waker.
  full('full'),

  /// No CoreLocation waker (at most "While Using", or Precise Location off), but
  /// the app declares `bluetooth-central`: the BLE eye keeps scanning in the
  /// background and state restoration relaunches the app after a **system**
  /// termination. A force-quit stays dead until the user opens the app again; that
  /// gap is Apple's, and only `Always` closes it.
  backgroundBle('backgroundBle'),

  /// No waker and no `bluetooth-central`: detects only with the app in the foreground.
  foregroundOnly('foregroundOnly'),

  /// Nothing can scan: Bluetooth denied/restricted and Location cannot range beacons.
  blind('blind'),

  /// The platform does not report this signal (Android, or an older native SDK).
  unknown('unknown');

  const DetectionReadiness(this.value);

  final String value;

  static DetectionReadiness fromString(String? value) {
    switch (value) {
      case 'full':
        return DetectionReadiness.full;
      case 'backgroundBle':
        return DetectionReadiness.backgroundBle;
      case 'foregroundOnly':
        return DetectionReadiness.foregroundOnly;
      case 'blind':
        return DetectionReadiness.blind;
      default:
        return DetectionReadiness.unknown;
    }
  }

  /// `true` when the app is woken with its process dead. Only [full] guarantees it.
  bool get wakesWhenTerminated => this == DetectionReadiness.full;

  /// `true` when detection depends on the app being open on screen.
  bool get needsAppOpen => this == DetectionReadiness.foregroundOnly;
}
