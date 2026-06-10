/// Bluetooth-zone enter/exit transition event. **iOS-only.**
///
/// Backed by the CBCentralManager BLE scan, independent of CoreLocation region
/// monitoring. Android has no equivalent — this stream registers but never
/// emits on Android.
class BluetoothZoneEvent {
  final String type;

  const BluetoothZoneEvent({required this.type});

  factory BluetoothZoneEvent.fromMap(Map<dynamic, dynamic> map) {
    final t = (map['type'] as String?)?.toLowerCase() ?? 'enter';
    return BluetoothZoneEvent(type: t == 'exit' ? 'exit' : 'enter');
  }

  bool get isEnter => type == 'enter';
  bool get isExit => type == 'exit';
}

/// Bluetooth scanner duty-cycle mode. **iOS-only.**
///
/// - `idle`: scanner OFF most of the time; peeks for 10s every 5 min.
/// - `active`: scanner ON continuously; UI tick every 10s.
enum BluetoothScanMode {
  idle('idle'),
  active('active');

  const BluetoothScanMode(this.value);

  final String value;

  static BluetoothScanMode fromString(String value) {
    return value.toLowerCase() == 'active'
        ? BluetoothScanMode.active
        : BluetoothScanMode.idle;
  }
}

/// Bluetooth scanner duty-cycle mode change event. **iOS-only.**
class BluetoothScanModeEvent {
  /// Current mode (`idle` or `active`).
  final BluetoothScanMode mode;

  /// Epoch ms of the next idle peek. Present only when `mode == idle`.
  final int? nextIdleScanAt;

  const BluetoothScanModeEvent({required this.mode, this.nextIdleScanAt});

  factory BluetoothScanModeEvent.fromMap(Map<dynamic, dynamic> map) {
    final raw = map['mode'] as String? ?? 'idle';
    final nextRaw = map['nextIdleScanAt'];
    final next = nextRaw is num ? nextRaw.toInt() : null;
    return BluetoothScanModeEvent(
      mode: BluetoothScanMode.fromString(raw),
      nextIdleScanAt: next,
    );
  }
}

/// Bluetooth adapter state, mirroring iOS `CBManagerState` / Android adapter
/// state.
enum BluetoothState {
  poweredOn('poweredOn'),
  poweredOff('poweredOff'),
  unauthorized('unauthorized'),
  unsupported('unsupported'),
  resetting('resetting'),
  unknown('unknown');

  const BluetoothState(this.value);

  final String value;

  static BluetoothState fromString(String? value) {
    switch (value) {
      case 'poweredOn':
        return BluetoothState.poweredOn;
      case 'poweredOff':
        return BluetoothState.poweredOff;
      case 'unauthorized':
        return BluetoothState.unauthorized;
      case 'unsupported':
        return BluetoothState.unsupported;
      case 'resetting':
        return BluetoothState.resetting;
      default:
        return BluetoothState.unknown;
    }
  }
}

/// Bluetooth adapter state change event.
class BluetoothStateEvent {
  final BluetoothState state;

  const BluetoothStateEvent({required this.state});

  factory BluetoothStateEvent.fromMap(Map<dynamic, dynamic> map) {
    final raw = map['state'] as String?;
    return BluetoothStateEvent(state: BluetoothState.fromString(raw));
  }
}
