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
