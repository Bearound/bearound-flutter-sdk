/// App-state bucket recorded natively for each persisted log entry.
///
/// The four states the SDK distinguishes:
/// - `foreground` — app is active and on screen.
/// - `background` — app is backgrounded, device screen unlocked.
/// - `backgroundLocked` — app is backgrounded AND the device screen is locked.
///   iOS uses `isProtectedDataAvailable`; Android uses `KeyguardManager`.
/// - `terminated` — the event fired during a system-initiated relaunch
///   (BLE/region wake-up) BEFORE the app's UI has become active. Means the
///   process was started by the OS while the user had the app killed.
enum PersistedLogState {
  foreground('foreground'),
  background('background'),
  backgroundLocked('backgroundLocked'),
  terminated('terminated');

  const PersistedLogState(this.value);

  final String value;

  static PersistedLogState fromString(String? value) {
    switch (value) {
      case 'foreground':
        return PersistedLogState.foreground;
      case 'backgroundLocked':
        return PersistedLogState.backgroundLocked;
      case 'terminated':
        return PersistedLogState.terminated;
      default:
        // 'background' is the default for anything that's not foreground
        // and not explicitly tagged as locked/terminated. Older `closed`
        // entries also fall here.
        return PersistedLogState.background;
    }
  }
}

/// An entry in the native detection log persisted by the SDK. Survives
/// foreground/background/closed app states.
class PersistedLogEntry {
  final String id;
  final int timestamp;
  final PersistedLogState state;
  final String type;
  final String detail;

  const PersistedLogEntry({
    required this.id,
    required this.timestamp,
    required this.state,
    required this.type,
    required this.detail,
  });

  factory PersistedLogEntry.fromJson(Map<String, dynamic> json) {
    return PersistedLogEntry(
      id: json['id']?.toString() ?? '',
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      state: PersistedLogState.fromString(json['state'] as String?),
      type: json['type']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
    );
  }
}
