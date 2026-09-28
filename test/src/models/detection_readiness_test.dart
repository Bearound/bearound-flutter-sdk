import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DetectionReadiness', () {
    test('fromString maps every native value', () {
      expect(DetectionReadiness.fromString('full'), DetectionReadiness.full);
      expect(
        DetectionReadiness.fromString('backgroundBle'),
        DetectionReadiness.backgroundBle,
      );
      expect(
        DetectionReadiness.fromString('foregroundOnly'),
        DetectionReadiness.foregroundOnly,
      );
      expect(DetectionReadiness.fromString('blind'), DetectionReadiness.blind);
    });

    test('unknown or missing values fall back to unknown', () {
      expect(DetectionReadiness.fromString(null), DetectionReadiness.unknown);
      expect(
        DetectionReadiness.fromString('bogus'),
        DetectionReadiness.unknown,
      );
    });

    test(
      'only full wakes a terminated app; only foregroundOnly needs it open',
      () {
        for (final r in DetectionReadiness.values) {
          expect(r.wakesWhenTerminated, r == DetectionReadiness.full);
          expect(r.needsAppOpen, r == DetectionReadiness.foregroundOnly);
        }
      },
    );
  });
}
