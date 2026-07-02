import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthorizationStatus.fromString', () {
    test('maps iOS camelCase values', () {
      expect(
        AuthorizationStatus.fromString('always'),
        AuthorizationStatus.always,
      );
      expect(
        AuthorizationStatus.fromString('authorizedAlways'),
        AuthorizationStatus.always,
      );
      expect(
        AuthorizationStatus.fromString('whenInUse'),
        AuthorizationStatus.whenInUse,
      );
      expect(
        AuthorizationStatus.fromString('authorizedWhenInUse'),
        AuthorizationStatus.whenInUse,
      );
    });

    test(
      'maps Android snake_case values from getLocationPermissionStatus()',
      () {
        // The Android native SDK's getLocationPermissionStatus() returns these
        // exact strings; without this mapping getAuthorizationStatus() always
        // resolved to `unknown` on Android even with the permission granted.
        expect(
          AuthorizationStatus.fromString('authorized_always'),
          AuthorizationStatus.always,
        );
        expect(
          AuthorizationStatus.fromString('authorized_when_in_use'),
          AuthorizationStatus.whenInUse,
        );
      },
    );

    test('maps shared values', () {
      expect(
        AuthorizationStatus.fromString('denied'),
        AuthorizationStatus.denied,
      );
      expect(
        AuthorizationStatus.fromString('restricted'),
        AuthorizationStatus.restricted,
      );
      expect(
        AuthorizationStatus.fromString('notDetermined'),
        AuthorizationStatus.notDetermined,
      );
    });

    test('falls back to unknown for null/unrecognized values', () {
      expect(AuthorizationStatus.fromString(null), AuthorizationStatus.unknown);
      expect(AuthorizationStatus.fromString(''), AuthorizationStatus.unknown);
      expect(
        AuthorizationStatus.fromString('bogus'),
        AuthorizationStatus.unknown,
      );
    });
  });
}
