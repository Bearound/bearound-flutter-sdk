import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Beacon', () {
    test('parses beacon with metadata and timestamp', () {
      final json = {
        'uuid': 'E25B8D3C-947A-452F-A13F-589CB706D2E5',
        'major': 1,
        'minor': 2,
        'rssi': -50,
        'proximity': 'near',
        'accuracy': 1.2,
        'timestamp': 1700000000000,
        'txPower': -59,
        'metadata': {
          'firmwareVersion': '1.0.0',
          'batteryLevel': 80,
          'movements': 3,
          'temperature': 24,
          'txPower': -59,
          'rssiFromBLE': -55,
          'isConnectable': true,
        },
      };

      final beacon = Beacon.fromJson(json);

      expect(beacon.uuid, equals('E25B8D3C-947A-452F-A13F-589CB706D2E5'));
      expect(beacon.major, equals(1));
      expect(beacon.minor, equals(2));
      expect(beacon.rssi, equals(-50));
      expect(beacon.proximity, equals(BeaconProximity.near));
      expect(beacon.accuracy, equals(1.2));
      expect(beacon.timestamp.millisecondsSinceEpoch, equals(1700000000000));
      expect(beacon.txPower, equals(-59));
      expect(beacon.metadata, isNotNull);
      expect(beacon.metadata?.batteryLevel, equals(80));
    });

    test('defaults missing optional fields', () {
      final json = {
        'uuid': 'test',
        'major': 10,
        'minor': 20,
        'rssi': -90,
        'proximity': 'unknown',
        'accuracy': 0.0,
      };

      final beacon = Beacon.fromJson(json);

      expect(beacon.metadata, isNull);
      expect(beacon.txPower, isNull);
      expect(beacon.proximity, equals(BeaconProximity.unknown));
    });
  });
}
