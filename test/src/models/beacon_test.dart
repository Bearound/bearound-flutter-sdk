import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:faker/faker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final faker = Faker();

  group('Beacon Model', () {
    test('fromJson creates valid beacon with all fields', () {
      final uuid = faker.guid.guid();
      final major = faker.randomGenerator.integer(65535);
      final minor = faker.randomGenerator.integer(65535);
      final rssi = faker.randomGenerator.integer(100, min: -100);
      final accuracy = faker.randomGenerator.decimal();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final txPower = faker.randomGenerator.integer(10, min: -20);

      final json = {
        'uuid': uuid,
        'major': major,
        'minor': minor,
        'rssi': rssi,
        'proximity': 'near',
        'accuracy': accuracy,
        'timestamp': timestamp,
        'txPower': txPower,
      };

      final beacon = Beacon.fromJson(json);

      expect(beacon.uuid, equals(uuid));
      expect(beacon.major, equals(major));
      expect(beacon.minor, equals(minor));
      expect(beacon.rssi, equals(rssi));
      expect(beacon.proximity, equals(BeaconProximity.near));
      expect(beacon.accuracy, equals(accuracy));
      expect(beacon.timestamp.millisecondsSinceEpoch, equals(timestamp));
      expect(beacon.txPower, equals(txPower));
    });

    test('fromJson handles timestamp as double', () {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toDouble();

      final json = {
        'uuid': faker.guid.guid(),
        'major': 100,
        'minor': 200,
        'rssi': -65,
        'proximity': 'immediate',
        'accuracy': 1.5,
        'timestamp': timestamp,
      };

      final beacon = Beacon.fromJson(json);

      expect(
        beacon.timestamp.millisecondsSinceEpoch,
        equals(timestamp.round()),
      );
    });

    test('fromJson uses default values for missing fields', () {
      final json = <String, dynamic>{};

      final beacon = Beacon.fromJson(json);

      expect(beacon.uuid, equals(''));
      expect(beacon.major, equals(0));
      expect(beacon.minor, equals(0));
      expect(beacon.rssi, equals(0));
      expect(beacon.proximity, equals(BeaconProximity.unknown));
      expect(beacon.accuracy, equals(0));
      expect(beacon.timestamp, isA<DateTime>());
      expect(beacon.txPower, isNull);
      expect(beacon.metadata, isNull);
    });

    test('fromJson handles metadata correctly', () {
      final json = {
        'uuid': faker.guid.guid(),
        'major': 100,
        'minor': 200,
        'rssi': -65,
        'proximity': 'far',
        'accuracy': 5.0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'metadata': {
          'firmwareVersion': '1.2.3',
          'batteryLevel': 85,
          'movements': 10,
          'temperature': 22,
        },
      };

      final beacon = Beacon.fromJson(json);

      expect(beacon.metadata, isNotNull);
      expect(beacon.metadata!.firmwareVersion, equals('1.2.3'));
      expect(beacon.metadata!.batteryLevel, equals(85));
      expect(beacon.metadata!.movements, equals(10));
      expect(beacon.metadata!.temperature, equals(22));
    });
  });

  group('BeaconProximity Enum', () {
    test('fromString returns immediate', () {
      expect(
        BeaconProximity.fromString('immediate'),
        equals(BeaconProximity.immediate),
      );
      expect(
        BeaconProximity.fromString('IMMEDIATE'),
        equals(BeaconProximity.immediate),
      );
    });

    test('fromString returns near', () {
      expect(BeaconProximity.fromString('near'), equals(BeaconProximity.near));
      expect(BeaconProximity.fromString('NEAR'), equals(BeaconProximity.near));
    });

    test('fromString returns far', () {
      expect(BeaconProximity.fromString('far'), equals(BeaconProximity.far));
      expect(BeaconProximity.fromString('FAR'), equals(BeaconProximity.far));
    });

    test('fromString returns unknown for invalid values', () {
      expect(
        BeaconProximity.fromString('invalid'),
        equals(BeaconProximity.unknown),
      );
      expect(BeaconProximity.fromString(''), equals(BeaconProximity.unknown));
      expect(
        BeaconProximity.fromString('random'),
        equals(BeaconProximity.unknown),
      );
    });
  });
}
