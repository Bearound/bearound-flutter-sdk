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

    test(
      'fromJson carries domain and code when the native side sends them',
      () {
        final error = BearoundError.fromJson({
          'message': 'Region monitoring denied by iOS',
          'domain': 'BeAroundSDK',
          'code': 11,
        });

        expect(error.domain, equals('BeAroundSDK'));
        expect(error.code, equals(11));
        expect(error.isLocationAlwaysRequired, isTrue);
      },
    );

    test('fromJson leaves domain/code null for payloads without them', () {
      // Android sends message-only, and so did every iOS plugin build before this change.
      final error = BearoundError.fromJson({'message': 'boom'});

      expect(error.domain, isNull);
      expect(error.code, isNull);
      expect(error.isLocationAlwaysRequired, isFalse);
    });

    test(
      'isLocationAlwaysRequired also matches the raw CoreLocation error',
      () {
        // Older native SDKs forward kCLErrorDomain#4 without re-wrapping it.
        final error = BearoundError.fromJson({
          'message':
              'A operação não pôde ser concluída. (kCLErrorDomain erro 4.)',
          'domain': 'kCLErrorDomain',
          'code': 4,
        });

        expect(error.isLocationAlwaysRequired, isTrue);
      },
    );

    test('isLocationAlwaysRequired is false for other CoreLocation codes', () {
      final error = BearoundError.fromJson({
        'message': 'whatever',
        'domain': 'kCLErrorDomain',
        'code': 5,
      });

      expect(error.isLocationAlwaysRequired, isFalse);
    });

    test('toString shows the domain#code tag when present', () {
      const tagged = BearoundError(
        message: 'boom',
        domain: 'BeAroundSDK',
        code: 11,
      );
      const untagged = BearoundError(message: 'boom');

      expect(tagged.toString(), contains('[BeAroundSDK#11]'));
      expect(untagged.toString(), isNot(contains('[')));
    });
  });
}
