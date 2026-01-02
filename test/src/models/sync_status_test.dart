import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:faker/faker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final faker = Faker();

  group('SyncStatus Model', () {
    test('fromJson creates valid sync status with all fields', () {
      final secondsUntilNextSync = faker.randomGenerator.integer(60);

      final json = {
        'secondsUntilNextSync': secondsUntilNextSync,
        'isRanging': true,
      };

      final syncStatus = SyncStatus.fromJson(json);

      expect(syncStatus.secondsUntilNextSync, equals(secondsUntilNextSync));
      expect(syncStatus.isRanging, isTrue);
    });

    test('fromJson uses default values for missing fields', () {
      final json = <String, dynamic>{};

      final syncStatus = SyncStatus.fromJson(json);

      expect(syncStatus.secondsUntilNextSync, equals(0));
      expect(syncStatus.isRanging, isFalse);
    });

    test('fromJson handles isRanging as false', () {
      final json = {'secondsUntilNextSync': 30, 'isRanging': false};

      final syncStatus = SyncStatus.fromJson(json);

      expect(syncStatus.secondsUntilNextSync, equals(30));
      expect(syncStatus.isRanging, isFalse);
    });

    test('fromJson handles secondsUntilNextSync as double', () {
      final json = {'secondsUntilNextSync': 45.7, 'isRanging': true};

      final syncStatus = SyncStatus.fromJson(json);

      expect(syncStatus.secondsUntilNextSync, equals(45));
      expect(syncStatus.isRanging, isTrue);
    });

    test('fromJson handles zero secondsUntilNextSync', () {
      final json = {'secondsUntilNextSync': 0, 'isRanging': true};

      final syncStatus = SyncStatus.fromJson(json);

      expect(syncStatus.secondsUntilNextSync, equals(0));
      expect(syncStatus.isRanging, isTrue);
    });

    test('fromJson handles large secondsUntilNextSync values', () {
      final json = {'secondsUntilNextSync': 3600, 'isRanging': false};

      final syncStatus = SyncStatus.fromJson(json);

      expect(syncStatus.secondsUntilNextSync, equals(3600));
      expect(syncStatus.isRanging, isFalse);
    });
  });
}
