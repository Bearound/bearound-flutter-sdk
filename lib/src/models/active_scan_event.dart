/// Active-scan gate state ("LIGADO" / "desligado").
class ActiveScanEvent {
  /// True when ranging + BLE active scan are running. False when paused.
  final bool isActive;

  const ActiveScanEvent({required this.isActive});

  factory ActiveScanEvent.fromMap(Map<dynamic, dynamic> map) {
    return ActiveScanEvent(isActive: (map['isActive'] as bool?) ?? false);
  }
}
