import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Isolated Dart-layer error telemetry for the Bearound Flutter SDK — a
/// "try/catch around the library" for the plugin's own Dart code.
///
/// The plugin embeds the native Android/iOS SDKs, whose own `ErrorReporter`s
/// already capture native crashes. This reporter covers the layer they cannot
/// see: uncaught Dart/Flutter framework errors and async errors whose stack
/// contains frames from `package:bearound_flutter_sdk`. It ships them to the
/// same ingest backend (`POST https://ingest.bearound.io/sdk-errors`), matching
/// the Android [ErrorReporter] contract byte-for-byte (only `sdk.platform`
/// differs: here it is `"flutter"`).
///
/// GOLDEN RULES (identical to Android):
/// 1. NEVER throw, NEVER break the host app, NEVER hijack the host's error flow.
/// 2. Only report errors that ORIGINATE in our library — the FIRST application
///    frame of the stack (skipping the runtime and this telemetry file) must be
///    a `package:bearound_flutter_sdk/` frame. A host error that merely passes
///    through an SDK callback is never captured.
/// 3. The global handlers are ALWAYS chained — the previous
///    [FlutterError.onError] is kept and always invoked, and
///    [PlatformDispatcher.onError] returns `false` so the platform still sees
///    the error.
/// 4. Fire-and-forget delivery with an in-memory rate limit + dedupe (hash of
///    `type|context|first stack line`); stack traces truncated to
///    [_maxStackChars].
/// 5. Isolated transport with short timeouts (own [HttpClient], 5 s).
/// 6. Public opt-out [setEnabled] (default enabled).
class ErrorReporter {
  ErrorReporter._();

  /// Process-wide singleton — the global handlers it chains are process-wide.
  static final ErrorReporter instance = ErrorReporter._();

  static const String _endpoint = 'https://ingest.bearound.io/sdk-errors';

  /// The plugin's Dart package, anchored as a package URI (trailing slash).
  /// A bare substring would also match HOST files named after the SDK
  /// (`package:host_app/bearound_flutter_sdk_helper.dart` — a common naming
  /// pattern for integration wrappers), leaking host errors into our ingest.
  static const String _sdkPackageMarker = 'package:bearound_flutter_sdk/';

  /// This telemetry file — frames from it are excluded from the "is it ours?"
  /// check so a reporter-internal failure is never classified as an SDK error.
  /// Full package path: a bare `error_reporter.dart` would also skip HOST files
  /// with that (very common) name, letting the scan fall through to an SDK
  /// frame below and misattribute a host error to us.
  static const String _telemetryFileMarker =
      'package:bearound_flutter_sdk/src/telemetry/error_reporter.dart';

  static const int _maxStackChars = 8000;
  static const int _maxReportsPerHour = 20;
  static const Duration _rateWindow = Duration(hours: 1);
  static const Duration _dedupeWindow = Duration(minutes: 5);

  /// Prune the dedupe map once it grows past this, to bound memory.
  static const int _dedupeMapPruneSize = 64;

  static const Duration _connectTimeout = Duration(seconds: 5);
  static const Duration _requestTimeout = Duration(seconds: 5);

  bool _enabled = true;
  bool _installed = false;
  String? _businessToken;

  /// The [FlutterError.onError] present before [install] chained ours. Always
  /// invoked so the host's error flow is untouched.
  FlutterExceptionHandler? _previousFlutterOnError;

  /// The [PlatformDispatcher.onError] present before [install] chained ours
  /// (e.g. Crashlytics). Always delegated to, and its return value honored.
  bool Function(Object, StackTrace)? _previousDispatcherOnError;

  // Rate-limit + dedupe state (report can be invoked from any zone/isolate root).
  final List<DateTime> _reportTimestamps = <DateTime>[];
  final Map<String, DateTime> _lastReportedAt = <String, DateTime>{};

  /// Overridable transport for tests. Default posts the JSON body over HTTP.
  /// Returns a future that completes when delivery finishes (or gives up).
  @visibleForTesting
  Future<void> Function(String body, String? token) transport = _httpPost;

  /// Installs the reporter. Idempotent — safe to call on every `configure()`.
  ///
  /// Stores the [businessToken] used for the `Authorization` header and chains
  /// the two Dart-level global error handlers:
  /// - [FlutterError.onError]: keeps the previous handler and ALWAYS delegates
  ///   to it after (optionally) reporting.
  /// - [PlatformDispatcher.instance.onError]: reports, then returns `false` so
  ///   the error is NOT swallowed — the platform default still runs.
  ///
  /// Only errors whose stack contains a `bearound_flutter_sdk` frame are
  /// reported; everything else passes straight through untouched.
  void install(String? businessToken) {
    try {
      _businessToken = businessToken;
      if (_installed) return;
      _installed = true;

      _previousFlutterOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        try {
          if (_isFromSdk(details.stack)) {
            _report(
              type: details.exception.runtimeType.toString(),
              message: _messageOf(
                details.exception,
                details.summary.toString(),
              ),
              stack: details.stack,
              context: 'uncaught',
            );
          }
        } catch (_) {
          // GOLDEN RULE: telemetry must never interfere with the host's flow.
        } finally {
          // ALWAYS delegate to the previous handler (defaults to dumping the
          // error to the console when no host handler was set).
          final previous = _previousFlutterOnError;
          if (previous != null) {
            previous(details);
          } else {
            FlutterError.presentError(details);
          }
        }
      };

      // Chain a pre-existing host handler (e.g. Crashlytics): capture it BEFORE
      // overwriting, always delegate, and honor ITS return value — silently
      // replacing a handler that returned `true` would break the host's error
      // flow (golden rule 3).
      _previousDispatcherOnError = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        try {
          if (_isFromSdk(stack)) {
            _report(
              type: error.runtimeType.toString(),
              message: _messageOf(error, ''),
              stack: stack,
              context: 'async',
            );
          }
        } catch (_) {
          // Swallow — never break the host.
        }
        final previous = _previousDispatcherOnError;
        if (previous != null) {
          try {
            return previous(error, stack);
          } catch (_) {
            // A throwing host handler must not surface through our hook.
            return false;
          }
        }
        // No previous handler: returning false lets the error propagate to the
        // platform default; we do NOT hijack/consume it.
        return false;
      };
    } catch (_) {
      // Install must never throw into the host.
    }
  }

  /// Enables/disables error reporting at runtime. Default: enabled.
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Reports an SDK error. Fire-and-forget: builds the payload, applies the
  /// rate-limit + dedupe gate, and delivers it on the isolated transport. Never
  /// throws. No-ops when disabled or gated. Awaitable so tests can observe that
  /// a failing transport does not surface.
  Future<void> _report({
    required String type,
    required String message,
    required StackTrace? stack,
    required String context,
    DateTime? now,
  }) async {
    try {
      if (!_enabled) return;

      final nowTs = now ?? DateTime.now();
      final stackStr = _stackString(stack);
      final hash = _computeHash(type, context, stackStr);
      if (!_shouldReport(hash, nowTs)) return;

      final token = _businessToken;
      final payload = await _buildPayload(
        type: type,
        message: message,
        stack: stackStr,
        context: context,
        occurredAt: nowTs,
      );
      final body = jsonEncode(payload);

      // Fire-and-forget: run the transport but never let its failure escape.
      await _safeSend(body, token);
    } catch (_) {
      // GOLDEN RULE: reporting must never throw into the host.
    }
  }

  Future<void> _safeSend(String body, String? token) async {
    try {
      await transport(body, token);
    } catch (_) {
      // Delivery is best-effort — swallow transport failures.
    }
  }

  // ---------------------------------------------------------------------------
  // Classification
  // ---------------------------------------------------------------------------

  /// True ONLY when the error ORIGINATED in our package — never a host-app error.
  ///
  /// Ownership is the FIRST application frame (skipping the Dart/Flutter runtime
  /// and this telemetry file). A host error that merely passes THROUGH one of our
  /// callbacks has the host frame on top and ours below — the old "any SDK frame
  /// in the stack" test captured those (a leak of the host app's errors); this
  /// origin test does not.
  bool _isFromSdk(StackTrace? stack) {
    if (stack == null) return false;
    for (final line in const LineSplitter().convert(stack.toString())) {
      final frame = line.trim();
      if (frame.isEmpty || frame == '<asynchronous suspension>') continue;
      // Dart/Flutter runtime frames surface the error but never originate it.
      if (frame.contains('dart:') && !frame.contains('package:')) continue;
      if (frame.contains('package:flutter/')) continue;
      // Our own telemetry file never counts as the origin (avoids self-reporting).
      if (frame.contains(_telemetryFileMarker)) continue;
      // The first real application frame decides ownership.
      return frame.contains(_sdkPackageMarker);
    }
    return false;
  }

  String _messageOf(Object error, String fallback) {
    try {
      final s = error.toString();
      return s.isNotEmpty ? s : fallback;
    } catch (_) {
      return fallback;
    }
  }

  String _stackString(StackTrace? stack) {
    if (stack == null) return '';
    final s = stack.toString();
    return s.length > _maxStackChars ? s.substring(0, _maxStackChars) : s;
  }

  /// sha256-free stable hash of `type|context|first stack line` — dedupe key.
  /// Uses a simple FNV-1a to avoid pulling in `crypto`; collision risk here is
  /// irrelevant (it only gates duplicate reports for a few minutes).
  String _computeHash(String type, String context, String stack) {
    final firstLine = const LineSplitter().convert(stack).isEmpty
        ? ''
        : const LineSplitter().convert(stack).first.trim();
    final key = '$type|$context|$firstLine';
    var hash = 0x811c9dc5;
    for (final code in key.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16);
  }

  /// Combined dedupe + rate-limit gate. Returns true when this hash may be
  /// reported now (and records the attempt).
  bool _shouldReport(String hash, DateTime now) {
    final last = _lastReportedAt[hash];
    if (last != null && now.difference(last) < _dedupeWindow) return false;

    _reportTimestamps.removeWhere((t) => now.difference(t) > _rateWindow);
    if (_reportTimestamps.length >= _maxReportsPerHour) return false;

    _reportTimestamps.add(now);
    _lastReportedAt[hash] = now;

    if (_lastReportedAt.length > _dedupeMapPruneSize) {
      _lastReportedAt.removeWhere((_, t) => now.difference(t) > _dedupeWindow);
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Payload
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _buildPayload({
    required String type,
    required String message,
    required String stack,
    required String context,
    required DateTime occurredAt,
  }) async {
    return <String, dynamic>{
      'error': <String, dynamic>{
        'type': type,
        'message': message,
        'stackTrace': stack,
        'context': context,
      },
      'device': await _deviceSnapshot(),
      'sdk': <String, dynamic>{
        'version': _sdkVersion,
        'platform': 'flutter',
        'appId': _appId(),
      },
      'occurredAt': occurredAt.toUtc().toIso8601String(),
    };
  }

  /// Plugin version — kept in sync with `pubspec.yaml`. A literal (rather than a
  /// method-channel call) so the snapshot never blocks on the platform side.
  static const String _sdkVersion = '3.4.5';

  Future<Map<String, dynamic>> _deviceSnapshot() async {
    final device = <String, dynamic>{
      'deviceId': _safe(() => 'unknown'),
      'model': 'unknown',
      'manufacturer': 'unknown',
      'os': _safe(() => Platform.operatingSystem),
      'osVersion': _safe(() => Platform.operatingSystemVersion),
      'locale': _safe(() => Platform.localeName),
      'appState': null,
    };

    device['permissions'] = await _permissionsSnapshot();
    device['systemState'] = await _systemStateSnapshot();
    return device;
  }

  /// Snapshot of the SDK-relevant runtime permissions AT THE MOMENT OF THE
  /// ERROR, read via `permission_handler` (the same package
  /// [PermissionService] uses). Reads status WITHOUT requesting. Every probe is
  /// individually try/catch'd — a failing getter yields `"unknown"` and never
  /// aborts the report.
  Future<Map<String, dynamic>> _permissionsSnapshot() async {
    return <String, dynamic>{
      'bluetoothScan': await _permissionState(Permission.bluetoothScan),
      'bluetoothConnect': await _permissionState(Permission.bluetoothConnect),
      'location': await _permissionState(Permission.location),
      'locationAlways': await _permissionState(Permission.locationAlways),
      'notification': await _permissionState(Permission.notification),
    };
  }

  Future<String> _permissionState(Permission permission) async {
    try {
      final status = await permission.status;
      if (status.isGranted) return 'granted';
      if (status.isPermanentlyDenied) return 'permanently_denied';
      if (status.isRestricted) return 'restricted';
      if (status.isDenied) return 'denied';
      return status.name;
    } catch (_) {
      return 'unknown';
    }
  }

  /// Best-effort system-state probes reachable from Dart. Bluetooth/location
  /// service toggles live on the native side; from Dart we surface what
  /// `permission_handler` can tell us. Each probe is individually guarded.
  Future<Map<String, dynamic>> _systemStateSnapshot() async {
    final state = <String, dynamic>{};
    try {
      final serviceStatus = await Permission.location.serviceStatus;
      state['locationServicesEnabled'] = serviceStatus.isEnabled;
    } catch (_) {
      // Omit on failure.
    }
    try {
      state['notificationsEnabled'] =
          (await Permission.notification.status).isGranted;
    } catch (_) {
      // Omit on failure.
    }
    return state;
  }

  String _appId() {
    try {
      // dart:io exposes no package name; the native ErrorReporters fill the
      // real appId. Keep the field present with a stable placeholder.
      return 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  String _safe(String Function() probe) {
    try {
      return probe();
    } catch (_) {
      return 'unknown';
    }
  }

  // ---------------------------------------------------------------------------
  // Transport
  // ---------------------------------------------------------------------------

  static Future<void> _httpPost(String body, String? token) async {
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    try {
      final request = await client
          .postUrl(Uri.parse(_endpoint))
          .timeout(_requestTimeout);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, token);
      }
      request.add(utf8.encode(body));
      final response = await request.close().timeout(_requestTimeout);
      // Fire-and-forget: drain and ignore the body.
      await response.drain<void>().timeout(_requestTimeout, onTimeout: () {});
    } finally {
      client.close(force: true);
    }
  }

  /// Test hook: clears gate + config state so tests are independent.
  @visibleForTesting
  void resetForTest() {
    _enabled = true;
    _businessToken = null;
    _reportTimestamps.clear();
    _lastReportedAt.clear();
    transport = _httpPost;
  }

  /// Test hook: undoes [install] — restores the previous global handlers and
  /// re-arms `_installed` so a test can exercise the chaining behavior without
  /// leaking process-wide handler mutations into other tests.
  @visibleForTesting
  void uninstallForTest() {
    if (!_installed) return;
    FlutterError.onError = _previousFlutterOnError;
    PlatformDispatcher.instance.onError = _previousDispatcherOnError;
    _previousFlutterOnError = null;
    _previousDispatcherOnError = null;
    _installed = false;
  }

  /// Reports an error already CAUGHT inside the SDK's own plumbing (e.g. the
  /// internal EventChannel subscription) — the call site itself proves the
  /// origin is ours, so the stack filter is not applied. Fire-and-forget and
  /// exception-proof: this method never throws into the caller.
  void reportCaught(
    Object error,
    StackTrace? stack, {
    required String context,
  }) {
    try {
      _report(
        type: error.runtimeType.toString(),
        message: _messageOf(error, ''),
        stack: stack,
        context: context,
      );
    } catch (_) {
      // GOLDEN RULE: telemetry must never interfere with the host's flow.
    }
  }

  /// Test hook: drives the private report path with an explicit stack/context
  /// (bypassing the global handlers, which are process-wide). Applies the same
  /// package filter as the real handlers.
  @visibleForTesting
  Future<bool> reportForTest({
    required String type,
    required String message,
    required StackTrace stack,
    required String context,
    DateTime? now,
  }) async {
    if (!_isFromSdk(stack)) return false;
    await _report(
      type: type,
      message: message,
      stack: stack,
      context: context,
      now: now,
    );
    return true;
  }
}
