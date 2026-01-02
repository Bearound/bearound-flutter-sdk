import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:faker/faker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final faker = Faker();

  group('BeaconMetadata Model', () {
    test('fromJson creates valid metadata with all fields', () {
      final firmwareVersion = faker.randomGenerator.string(10);
      final batteryLevel = faker.randomGenerator.integer(100);
      final movements = faker.randomGenerator.integer(1000);
      final temperature = faker.randomGenerator.integer(50, min: -10);
      final txPower = faker.randomGenerator.integer(10, min: -20);
      final rssiFromBLE = faker.randomGenerator.integer(0, min: -100);

      final json = {
        'firmwareVersion': firmwareVersion,
        'batteryLevel': batteryLevel,
        'movements': movements,
        'temperature': temperature,
        'txPower': txPower,
        'rssiFromBLE': rssiFromBLE,
        'isConnectable': true,
      };

      final metadata = BeaconMetadata.fromJson(json);

      expect(metadata.firmwareVersion, equals(firmwareVersion));
      expect(metadata.batteryLevel, equals(batteryLevel));
      expect(metadata.movements, equals(movements));
      expect(metadata.temperature, equals(temperature));
      expect(metadata.txPower, equals(txPower));
      expect(metadata.rssiFromBLE, equals(rssiFromBLE));
      expect(metadata.isConnectable, isTrue);
    });

    test('fromJson uses default values for missing required fields', () {
      final json = <String, dynamic>{};

      final metadata = BeaconMetadata.fromJson(json);

      expect(metadata.firmwareVersion, equals(''));
      expect(metadata.batteryLevel, equals(0));
      expect(metadata.movements, equals(0));
      expect(metadata.temperature, equals(0));
      expect(metadata.txPower, isNull);
      expect(metadata.rssiFromBLE, isNull);
      expect(metadata.isConnectable, isNull);
    });

    test('fromJson handles partial data', () {
      final json = {
        'firmwareVersion': '2.0.1',
        'batteryLevel': 50,
        'movements': 25,
        'temperature': 20,
      };

      final metadata = BeaconMetadata.fromJson(json);

      expect(metadata.firmwareVersion, equals('2.0.1'));
      expect(metadata.batteryLevel, equals(50));
      expect(metadata.movements, equals(25));
      expect(metadata.temperature, equals(20));
      expect(metadata.txPower, isNull);
      expect(metadata.rssiFromBLE, isNull);
      expect(metadata.isConnectable, isNull);
    });

    test('fromJson handles isConnectable as false', () {
      final json = {
        'firmwareVersion': '1.0.0',
        'batteryLevel': 100,
        'movements': 0,
        'temperature': 25,
        'isConnectable': false,
      };

      final metadata = BeaconMetadata.fromJson(json);

      expect(metadata.isConnectable, isFalse);
    });

    test('fromJson handles numeric fields as double', () {
      final json = {
        'firmwareVersion': '1.0.0',
        'batteryLevel': 85.5,
        'movements': 10.2,
        'temperature': 22.7,
        'txPower': -15.3,
        'rssiFromBLE': -65.8,
      };

      final metadata = BeaconMetadata.fromJson(json);

      expect(metadata.batteryLevel, equals(85));
      expect(metadata.movements, equals(10));
      expect(metadata.temperature, equals(22));
      expect(metadata.txPower, equals(-15));
      expect(metadata.rssiFromBLE, equals(-65));
    });
  });
}
