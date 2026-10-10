import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _snapshotJson({
  String snapshotId = '0b5d7e1c-6c2a-4f7e-9a51-1f0e2d3c4b5a',
  bool cached = false,
}) => <String, dynamic>{
  'schemaVersion': 1,
  'snapshotId': snapshotId,
  'configurationFingerprint': 'f' * 64,
  'checkedAt': '2026-10-09T12:34:56.789Z',
  'cached': cached,
  'results': <Map<String, dynamic>>[
    {
      'targetId': 'beta',
      'state': 'present',
      'present': true,
      'reason': null,
      'checkedAt': '2026-10-09T12:34:56.700Z',
      'detectionMethod': 'android_package',
    },
    {
      'targetId': 'alpha',
      'state': 'unknown',
      'present': null,
      'reason': 'unsupported_platform',
      'checkedAt': '2026-10-09T12:34:56.701Z',
      'detectionMethod': 'none',
    },
    {
      'targetId': 'gamma',
      'state': 'absent',
      'present': false,
      'reason': null,
      'checkedAt': '2026-10-09T12:34:56.702Z',
      'detectionMethod': 'ios_url_scheme',
    },
  ],
};

void main() {
  group('AppPresenceConfiguration', () {
    test('defaults to disabled with no targets', () {
      const configuration = AppPresenceConfiguration();
      expect(configuration.enabled, isFalse);
      expect(configuration.targets, isEmpty);
    });

    test(
      'a legacy configuration without opt-in keys restores the defaults',
      () {
        final configuration = AppPresenceConfiguration.fromJson(
          <String, dynamic>{},
        );
        expect(configuration.enabled, isFalse);
        expect(configuration.targets, isEmpty);

        final nulls = AppPresenceConfiguration.fromJson(<String, dynamic>{
          'enabled': null,
          'targets': null,
        });
        expect(nulls.enabled, isFalse);
        expect(nulls.targets, isEmpty);
      },
    );

    test('serializes targets in order with explicit null identifiers', () {
      const configuration = AppPresenceConfiguration(
        enabled: true,
        targets: [
          AppPresenceTarget(id: 'b', androidPackageName: 'com.example.b'),
          AppPresenceTarget(id: 'a', iosScheme: 'example-a'),
        ],
      );

      final json = configuration.toJson();

      expect(json['enabled'], isTrue);
      expect(json['targets'], [
        {'id': 'b', 'iosScheme': null, 'androidPackageName': 'com.example.b'},
        {'id': 'a', 'iosScheme': 'example-a', 'androidPackageName': null},
      ]);
      expect((json['targets'] as List).first, containsPair('iosScheme', null));
      expect(
        AppPresenceConfiguration.fromJson(json).targets,
        configuration.targets,
      );
    });
  });

  group('AppPresenceSnapshot', () {
    test('parses every field and keeps the configured order', () {
      final snapshot = AppPresenceSnapshot.fromJson(_snapshotJson());

      expect(snapshot.schemaVersion, 1);
      expect(snapshot.snapshotId, '0b5d7e1c-6c2a-4f7e-9a51-1f0e2d3c4b5a');
      expect(snapshot.configurationFingerprint, 'f' * 64);
      expect(snapshot.cached, isFalse);
      expect(snapshot.results.map((r) => r.targetId), [
        'beta',
        'alpha',
        'gamma',
      ]);
      expect(snapshot.results.map((r) => r.state), [
        AppPresenceState.present,
        AppPresenceState.unknown,
        AppPresenceState.absent,
      ]);
      expect(snapshot.results.map((r) => r.detectionMethod), [
        AppPresenceDetectionMethod.androidPackage,
        AppPresenceDetectionMethod.none,
        AppPresenceDetectionMethod.iosUrlScheme,
      ]);
    });

    test('keeps unknown as null, never false, with its reason', () {
      final snapshot = AppPresenceSnapshot.fromJson(_snapshotJson());

      expect(snapshot.results[0].present, isTrue);
      expect(snapshot.results[0].reason, isNull);
      expect(snapshot.results[1].present, isNull);
      expect(snapshot.results[1].reason, AppPresenceReason.unsupportedPlatform);
      expect(snapshot.results[2].present, isFalse);
      expect(snapshot.results[2].reason, isNull);
    });

    test('parses timestamps as UTC with milliseconds', () {
      final snapshot = AppPresenceSnapshot.fromJson(_snapshotJson());

      expect(snapshot.checkedAt.isUtc, isTrue);
      expect(snapshot.checkedAt, DateTime.utc(2026, 10, 9, 12, 34, 56, 789));
      expect(snapshot.results[1].checkedAt.isUtc, isTrue);
      expect(
        snapshot.results[1].checkedAt,
        DateTime.utc(2026, 10, 9, 12, 34, 56, 701),
      );
    });

    test('round-trips to the native JSON contract with explicit nulls', () {
      final json = _snapshotJson(cached: true);

      expect(AppPresenceSnapshot.fromJson(json).toJson(), json);
    });

    test('maps every reason wire value', () {
      expect(AppPresenceReason.values.map((r) => r.value), [
        'not_declared',
        'declaration_unverified',
        'scheme_budget_exceeded',
        'unsupported_platform',
        'query_failed',
      ]);
      for (final reason in AppPresenceReason.values) {
        expect(AppPresenceReason.fromValue(reason.value), reason);
      }
    });

    test('rejects an unknown enum value or schema version', () {
      final badState = _snapshotJson();
      (badState['results'] as List).first['state'] = 'maybe';
      expect(
        () => AppPresenceSnapshot.fromJson(badState),
        throwsFormatException,
      );

      final badVersion = _snapshotJson()..['schemaVersion'] = 2;
      expect(
        () => AppPresenceSnapshot.fromJson(badVersion),
        throwsFormatException,
      );
    });
  });
}
