import 'dart:io' show Platform;

import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:flutter/widgets.dart';

/// App-side detection log for Android.
///
/// The native Android SDK has no persisted-log API (the plugin's
/// `getPersistedLog` is an explicit iOS-only stub returning `[]`), so on Android
/// the log has to be built by the HOST APP from the SDK's event streams —
/// exactly how the native BearoundScan sample does it: keep an
/// app-state flag, and tag every detection with the state it arrived in.
///
/// On iOS this store stays empty and the modal keeps reading the native
/// persisted log, which does exist there.
class LocalDetectionLog with WidgetsBindingObserver {
  LocalDetectionLog._();

  static final LocalDetectionLog instance = LocalDetectionLog._();

  static const _maxEntries = 500;

  final ValueNotifier<List<PersistedLogEntry>> entries =
      ValueNotifier<List<PersistedLogEntry>>(const []);

  /// True while the app is not in the foreground (background or locked screen).
  bool _isBackground = false;

  /// Last logged timestamp per beacon — the streams re-emit the whole current
  /// list on every delivery, so only FRESH sightings become log entries.
  final Map<String, int> _lastLoggedAt = {};

  int _seq = 0;
  bool _started = false;

  /// Whether this platform builds the log app-side (Android) or reads it from
  /// the native SDK (iOS).
  bool get isAppSide => Platform.isAndroid;

  void start() {
    if (_started || !isAppSide) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isBackground = state != AppLifecycleState.resumed;
  }

  PersistedLogState get _currentState =>
      _isBackground ? PersistedLogState.background : PersistedLogState.foreground;

  /// Records detections coming from `beaconsStream`, tagged with the current
  /// app state. Re-emissions of an already-logged sighting are ignored.
  void recordDetections(List<Beacon> beacons) {
    if (!isAppSide || beacons.isEmpty) return;
    final fresh = <PersistedLogEntry>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final b in beacons) {
      final key = '${b.major}.${b.minor}';
      final ts = b.timestamp.millisecondsSinceEpoch;
      if (_lastLoggedAt[key] == ts) continue;
      _lastLoggedAt[key] = ts;
      fresh.add(
        PersistedLogEntry(
          id: 'd${_seq++}',
          timestamp: now,
          state: _currentState,
          type: 'detection',
          detail: '$key · RSSI ${b.rssi}',
        ),
      );
    }
    _append(fresh);
  }

  /// Records the SDK's dedicated background-detection event. It fires exactly
  /// when the SDK itself considers the app backgrounded, so it is the most
  /// trustworthy background marker available to the app.
  void recordBackgroundDetection(int beaconCount) {
    if (!isAppSide) return;
    _append([
      PersistedLogEntry(
        id: 'b${_seq++}',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        state: PersistedLogState.background,
        type: 'background-detection',
        detail: '$beaconCount beacon(s) detectado(s) em background',
      ),
    ]);
  }

  /// Records sync outcomes so the log shows the full pipeline, not just sightings.
  void recordSync({required int beaconCount, required bool success}) {
    if (!isAppSide) return;
    _append([
      PersistedLogEntry(
        id: 's${_seq++}',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        state: _currentState,
        type: success ? 'sync-ok' : 'sync-fail',
        detail: '$beaconCount beacon(s) · ${success ? 'enviado' : 'falhou'}',
      ),
    ]);
  }

  /// Records region enter/exit transitions.
  void recordRegion({required bool entered}) {
    if (!isAppSide) return;
    _append([
      PersistedLogEntry(
        id: 'r${_seq++}',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        state: _currentState,
        type: entered ? 'region-enter' : 'region-exit',
        detail: entered ? 'Entrou na zona' : 'Saiu da zona',
      ),
    ]);
  }

  void clear() {
    _lastLoggedAt.clear();
    entries.value = const [];
  }

  void _append(List<PersistedLogEntry> fresh) {
    if (fresh.isEmpty) return;
    final next = [...fresh.reversed, ...entries.value];
    entries.value =
        next.length > _maxEntries ? next.sublist(0, _maxEntries) : next;
  }
}
