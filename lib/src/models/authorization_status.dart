/// Location authorization status. On iOS mirrors `CLAuthorizationStatus`; on
/// Android the SDK returns a coarse permission-status string ("granted",
/// "denied", "background_granted"…).
enum AuthorizationStatus {
  always('always'),
  whenInUse('whenInUse'),
  denied('denied'),
  restricted('restricted'),
  notDetermined('notDetermined'),
  unknown('unknown');

  const AuthorizationStatus(this.value);

  final String value;

  static AuthorizationStatus fromString(String? value) {
    switch (value) {
      case 'always':
      case 'authorizedAlways':
      // snake_case emitted by the Android native SDK
      // (`getLocationPermissionStatus()` returns `authorized_always`).
      case 'authorized_always':
        return AuthorizationStatus.always;
      case 'whenInUse':
      case 'authorizedWhenInUse':
      // snake_case emitted by the Android native SDK
      // (`getLocationPermissionStatus()` returns `authorized_when_in_use`).
      case 'authorized_when_in_use':
        return AuthorizationStatus.whenInUse;
      case 'denied':
        return AuthorizationStatus.denied;
      case 'restricted':
        return AuthorizationStatus.restricted;
      case 'notDetermined':
        return AuthorizationStatus.notDetermined;
      default:
        return AuthorizationStatus.unknown;
    }
  }
}

/// Level requested by `requestLocationAuthorization`.
enum LocationAuthorizationLevel {
  always('always'),
  whenInUse('whenInUse');

  const LocationAuthorizationLevel(this.value);

  final String value;
}
