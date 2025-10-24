import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Beacon', () {
    test('should create instance with required fields', () {
      final beacon = Beacon(
        uuid: 'test-uuid',
        major: 100,
        minor: 200,
        rssi: -50,
      );

      expect(beacon.uuid, equals('test-uuid'));
      expect(beacon.major, equals(100));
      expect(beacon.minor, equals(200));
      expect(beacon.rssi, equals(-50));
      expect(beacon.bluetoothName, isNull);
      expect(beacon.bluetoothAddress, isNull);
      expect(beacon.distanceMeters, isNull);
    });

    test('should create instance with all fields', () {
      final beacon = Beacon(
        uuid: 'test-uuid',
        major: 100,
        minor: 200,
        rssi: -50,
        bluetoothName: 'Test Beacon',
        bluetoothAddress: '00:11:22:33:44:55',
        distanceMeters: 1.5,
      );

      expect(beacon.uuid, equals('test-uuid'));
      expect(beacon.major, equals(100));
      expect(beacon.minor, equals(200));
      expect(beacon.rssi, equals(-50));
      expect(beacon.bluetoothName, equals('Test Beacon'));
      expect(beacon.bluetoothAddress, equals('00:11:22:33:44:55'));
      expect(beacon.distanceMeters, equals(1.5));
    });

    test('should create instance from JSON with all fields', () {
      final json = {
        'uuid': 'test-uuid',
        'major': 100,
        'minor': 200,
        'rssi': -50,
        'bluetoothName': 'Test Beacon',
        'bluetoothAddress': '00:11:22:33:44:55',
        'distanceMeters': 1.5,
      };

      final beacon = Beacon.fromJson(json);

      expect(beacon.uuid, equals('test-uuid'));
      expect(beacon.major, equals(100));
      expect(beacon.minor, equals(200));
      expect(beacon.rssi, equals(-50));
      expect(beacon.bluetoothName, equals('Test Beacon'));
      expect(beacon.bluetoothAddress, equals('00:11:22:33:44:55'));
      expect(beacon.distanceMeters, equals(1.5));
    });

    test('should create instance from JSON with only required fields', () {
      final json = {
        'uuid': 'test-uuid',
        'major': 100,
        'minor': 200,
        'rssi': -50,
      };

      final beacon = Beacon.fromJson(json);

      expect(beacon.uuid, equals('test-uuid'));
      expect(beacon.major, equals(100));
      expect(beacon.minor, equals(200));
      expect(beacon.rssi, equals(-50));
      expect(beacon.bluetoothName, isNull);
      expect(beacon.bluetoothAddress, isNull);
      expect(beacon.distanceMeters, isNull);
    });

    test('should convert to JSON with all fields', () {
      final beacon = Beacon(
        uuid: 'test-uuid',
        major: 100,
        minor: 200,
        rssi: -50,
        bluetoothName: 'Test Beacon',
        bluetoothAddress: '00:11:22:33:44:55',
        distanceMeters: 1.5,
      );

      final json = beacon.toJson();

      expect(json['uuid'], equals('test-uuid'));
      expect(json['major'], equals(100));
      expect(json['minor'], equals(200));
      expect(json['rssi'], equals(-50));
      expect(json['bluetoothName'], equals('Test Beacon'));
      expect(json['bluetoothAddress'], equals('00:11:22:33:44:55'));
      expect(json['distanceMeters'], equals(1.5));
    });

    test('should convert to JSON with null optional fields', () {
      final beacon = Beacon(
        uuid: 'test-uuid',
        major: 100,
        minor: 200,
        rssi: -50,
      );

      final json = beacon.toJson();

      expect(json['uuid'], equals('test-uuid'));
      expect(json['major'], equals(100));
      expect(json['minor'], equals(200));
      expect(json['rssi'], equals(-50));
      expect(json['bluetoothName'], isNull);
      expect(json['bluetoothAddress'], isNull);
      expect(json['distanceMeters'], isNull);
    });

    test('should handle distanceMeters as int in JSON', () {
      final json = {
        'uuid': 'test-uuid',
        'major': 100,
        'minor': 200,
        'rssi': -50,
        'distanceMeters': 2, // int instead of double
      };

      final beacon = Beacon.fromJson(json);

      expect(beacon.distanceMeters, equals(2.0));
    });
  });
}
