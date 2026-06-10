/// Which detector(s) saw this beacon. **iOS-only** — drives the "two eyes"
/// model (`coreLocation` = Location eye; `serviceUUID`/`name` = Bluetooth eye).
/// Absent on Android, which is BLE-only and does not distinguish detection
/// sources.
enum BeaconDiscoverySource {
  serviceUUID('serviceUUID'),
  name('name'),
  coreLocation('coreLocation');

  const BeaconDiscoverySource(this.value);

  final String value;

  static BeaconDiscoverySource? fromString(String value) {
    switch (value) {
      case 'serviceUUID':
      case 'Service UUID':
        return BeaconDiscoverySource.serviceUUID;
      case 'name':
      case 'Name':
        return BeaconDiscoverySource.name;
      case 'coreLocation':
      case 'CoreLocation':
        return BeaconDiscoverySource.coreLocation;
      default:
        return null;
    }
  }
}
