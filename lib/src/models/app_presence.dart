/// App presence: opt-in, local-only check of apps declared in the host build.
///
/// These models mirror the native iOS / Android JSON contract exactly: the same keys,
/// the same enum wire values, `present` and `reason` written as explicit `null`, and
/// timestamps as ISO 8601 UTC with milliseconds.
library;

/// One app the host wants to check for on this device.
///
/// Each platform identifier is optional: a target without the identifier of the
/// running platform is reported as [AppPresenceState.unknown] with
/// [AppPresenceReason.unsupportedPlatform].
class AppPresenceTarget {
  /// Host-chosen id: ASCII `[A-Za-z0-9._-]`, 1 to 64 characters, unique within a
  /// configuration. Validated by the native SDK.
  final String id;

  /// URL scheme queried on iOS (scheme name only, no `://`; `http`/`https` refused).
  /// Must also be listed in the host's `LSApplicationQueriesSchemes`.
  final String? iosScheme;

  /// Package name queried on Android. Must also be declared in the host manifest
  /// `<queries>` and in the build evidence asset.
  final String? androidPackageName;

  const AppPresenceTarget({
    required this.id,
    this.iosScheme,
    this.androidPackageName,
  });

  factory AppPresenceTarget.fromJson(Map<String, dynamic> json) {
    return AppPresenceTarget(
      id: json['id'] as String,
      iosScheme: json['iosScheme'] as String?,
      androidPackageName: json['androidPackageName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'iosScheme': iosScheme,
    'androidPackageName': androidPackageName,
  };

  @override
  bool operator ==(Object other) =>
      other is AppPresenceTarget &&
      other.id == id &&
      other.iosScheme == iosScheme &&
      other.androidPackageName == androidPackageName;

  @override
  int get hashCode => Object.hash(id, iosScheme, androidPackageName);
}

/// Configuration of the app presence feature. Opt-in: the default value is disabled
/// with no targets, and nothing is queried until the host enables it explicitly.
class AppPresenceConfiguration {
  /// Maximum number of targets the native SDK accepts in one configuration.
  static const int maximumTargets = 50;

  final bool enabled;

  /// Targets in the host's order; results are delivered in this same order.
  final List<AppPresenceTarget> targets;

  const AppPresenceConfiguration({
    this.enabled = false,
    this.targets = const <AppPresenceTarget>[],
  });

  /// Missing or null keys restore the opt-in defaults (`enabled = false`,
  /// `targets = []`), so a legacy configuration never turns the feature on.
  factory AppPresenceConfiguration.fromJson(Map<String, dynamic> json) {
    final rawTargets = json['targets'];
    return AppPresenceConfiguration(
      enabled: json['enabled'] as bool? ?? false,
      targets: rawTargets is List
          ? rawTargets
                .map(
                  (item) => AppPresenceTarget.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList(growable: false)
          : const <AppPresenceTarget>[],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled,
    'targets': targets.map((target) => target.toJson()).toList(),
  };
}

/// Thrown by `BearoundFlutterSdk.configureAppPresence` when the native SDK rejects
/// the configuration. Only the app presence feature is disabled and its cached
/// snapshot dropped; the rest of the SDK keeps running.
class AppPresenceConfigurationException implements Exception {
  /// Stable cross-platform error code.
  static const String errorCode = 'app_presence_invalid_configuration';

  final String code;
  final String message;

  const AppPresenceConfigurationException(
    this.message, {
    this.code = errorCode,
  });

  @override
  String toString() => 'AppPresenceConfigurationException($code): $message';
}

/// Result state of one target.
enum AppPresenceState {
  present('present'),
  absent('absent'),
  unknown('unknown');

  const AppPresenceState(this.value);

  /// Wire value shared with the native SDKs.
  final String value;

  static AppPresenceState fromValue(String value) => values.firstWhere(
    (state) => state.value == value,
    orElse: () => throw FormatException('Unknown app presence state: $value'),
  );
}

/// Why a target ended up [AppPresenceState.unknown].
enum AppPresenceReason {
  notDeclared('not_declared'),
  declarationUnverified('declaration_unverified'),
  schemeBudgetExceeded('scheme_budget_exceeded'),
  unsupportedPlatform('unsupported_platform'),
  queryFailed('query_failed');

  const AppPresenceReason(this.value);

  /// Wire value shared with the native SDKs.
  final String value;

  static AppPresenceReason fromValue(String value) => values.firstWhere(
    (reason) => reason.value == value,
    orElse: () => throw FormatException('Unknown app presence reason: $value'),
  );
}

/// How a target was checked.
enum AppPresenceDetectionMethod {
  iosUrlScheme('ios_url_scheme'),
  androidPackage('android_package'),
  none('none');

  const AppPresenceDetectionMethod(this.value);

  /// Wire value shared with the native SDKs.
  final String value;

  static AppPresenceDetectionMethod fromValue(String value) =>
      values.firstWhere(
        (method) => method.value == value,
        orElse: () => throw FormatException(
          'Unknown app presence detection method: $value',
        ),
      );
}

/// Result of one target in a round.
///
/// [present] is `null` whenever [state] is [AppPresenceState.unknown]; it is never
/// coerced to `false`. On iOS, `present == true` means some installed app handles the
/// declared scheme; it does not verify which app.
class AppPresenceResult {
  final String targetId;
  final AppPresenceState state;
  final bool? present;
  final AppPresenceReason? reason;

  /// Moment the decision for this target was made, in UTC.
  final DateTime checkedAt;
  final AppPresenceDetectionMethod detectionMethod;

  const AppPresenceResult({
    required this.targetId,
    required this.state,
    required this.present,
    required this.reason,
    required this.checkedAt,
    required this.detectionMethod,
  });

  /// Throws [FormatException] or [TypeError] on a wrong shape or an unknown enum value.
  factory AppPresenceResult.fromJson(Map<String, dynamic> json) {
    final reason = json['reason'] as String?;
    return AppPresenceResult(
      targetId: json['targetId'] as String,
      state: AppPresenceState.fromValue(json['state'] as String),
      present: json['present'] as bool?,
      reason: reason == null ? null : AppPresenceReason.fromValue(reason),
      checkedAt: _parseUtc(json['checkedAt'] as String),
      detectionMethod: AppPresenceDetectionMethod.fromValue(
        json['detectionMethod'] as String,
      ),
    );
  }

  /// `present` and `reason` are always written, as `null` when absent.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'targetId': targetId,
    'state': state.value,
    'present': present,
    'reason': reason?.value,
    'checkedAt': _formatUtc(checkedAt),
    'detectionMethod': detectionMethod.value,
  };
}

/// A completed round: every configured target exactly once, in the configured order,
/// even when nothing changed since the previous round.
class AppPresenceSnapshot {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;

  /// Generated once per completed round; stable across cached replays.
  final String snapshotId;
  final String configurationFingerprint;

  /// Moment the round completed, in UTC.
  final DateTime checkedAt;

  /// Delivery metadata: `true` when replayed from cache, not a new round.
  final bool cached;
  final List<AppPresenceResult> results;

  const AppPresenceSnapshot({
    this.schemaVersion = currentSchemaVersion,
    required this.snapshotId,
    required this.configurationFingerprint,
    required this.checkedAt,
    required this.cached,
    required this.results,
  });

  /// Throws [FormatException] or [TypeError] on a wrong shape, an unknown enum value
  /// or an unsupported schema version.
  factory AppPresenceSnapshot.fromJson(Map<String, dynamic> json) {
    final version = (json['schemaVersion'] as num).toInt();
    if (version != currentSchemaVersion) {
      throw FormatException('Unsupported app presence schemaVersion: $version');
    }
    return AppPresenceSnapshot(
      schemaVersion: version,
      snapshotId: json['snapshotId'] as String,
      configurationFingerprint: json['configurationFingerprint'] as String,
      checkedAt: _parseUtc(json['checkedAt'] as String),
      cached: json['cached'] as bool,
      results: (json['results'] as List)
          .map(
            (item) => AppPresenceResult.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'snapshotId': snapshotId,
    'configurationFingerprint': configurationFingerprint,
    'checkedAt': _formatUtc(checkedAt),
    'cached': cached,
    'results': results.map((result) => result.toJson()).toList(),
  };
}

DateTime _parseUtc(String value) => DateTime.parse(value).toUtc();

/// ISO 8601 UTC with milliseconds (`2026-10-09T12:34:56.789Z`), as the native SDKs write it.
/// Truncating to whole milliseconds keeps toIso8601String from printing microseconds.
String _formatUtc(DateTime value) => DateTime.fromMillisecondsSinceEpoch(
  value.millisecondsSinceEpoch,
  isUtc: true,
).toIso8601String();
