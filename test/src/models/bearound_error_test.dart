import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:faker/faker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final faker = Faker();

  group('BearoundError Model', () {
    test('fromJson creates error with message and details', () {
      final message = faker.lorem.sentence();
      final details = faker.lorem.sentences(3).join(' ');

      final json = {'message': message, 'details': details};

      final error = BearoundError.fromJson(json);

      expect(error.message, equals(message));
      expect(error.details, equals(details));
    });

    test('fromJson creates error with only message', () {
      final message = faker.lorem.sentence();

      final json = {'message': message};

      final error = BearoundError.fromJson(json);

      expect(error.message, equals(message));
      expect(error.details, isNull);
    });

    test('fromJson uses default message for missing message field', () {
      final json = <String, dynamic>{};

      final error = BearoundError.fromJson(json);

      expect(error.message, equals('Unknown error'));
      expect(error.details, isNull);
    });

    test('fromJson handles null message', () {
      final json = {'message': null, 'details': 'Some details'};

      final error = BearoundError.fromJson(json);

      expect(error.message, equals('Unknown error'));
      expect(error.details, equals('Some details'));
    });

    test('fromJson handles empty message', () {
      final json = {'message': '', 'details': 'Some details'};

      final error = BearoundError.fromJson(json);

      expect(error.message, equals(''));
      expect(error.details, equals('Some details'));
    });

    test('constructor creates error correctly', () {
      const error = BearoundError(
        message: 'Test error',
        details: 'Test details',
      );

      expect(error.message, equals('Test error'));
      expect(error.details, equals('Test details'));
    });

    test('constructor creates error without details', () {
      const error = BearoundError(message: 'Test error');

      expect(error.message, equals('Test error'));
      expect(error.details, isNull);
    });
  });
}
