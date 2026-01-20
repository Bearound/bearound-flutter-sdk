import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:faker/faker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('bearound_flutter_sdk');
  final List<MethodCall> methodCalls = [];
  final faker = Faker();

  setUp(() {
    methodCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          methodCalls.add(call);

          switch (call.method) {
            case 'isScanning':
              return true;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('BearoundFlutterSdk Configuration', () {
    test('configure sends expected arguments with all parameters', () async {
      final businessToken = faker.guid.guid();

      await BearoundFlutterSdk.configure(
        businessToken: businessToken,
        foregroundScanInterval: ForegroundScanInterval.seconds20,
        backgroundScanInterval: BackgroundScanInterval.seconds90,
        maxQueuedPayloads: MaxQueuedPayloads.large,
      );

      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, equals('configure'));
      expect(
        methodCalls.first.arguments,
        equals({
          'businessToken': businessToken,
          'foregroundScanInterval': 20,
          'backgroundScanInterval': 90,
          'maxQueuedPayloads': 200,
        }),
      );
    });

    test('configure uses default values when parameters are omitted', () async {
      await BearoundFlutterSdk.configure(businessToken: 'test-token');

      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, equals('configure'));
      expect(
        methodCalls.first.arguments,
        equals({
          'businessToken': 'test-token',
          'foregroundScanInterval': 15,
          'backgroundScanInterval': 30,
          'maxQueuedPayloads': 100,
        }),
      );
    });

    test(
      'configure throws ArgumentError when businessToken is empty',
      () async {
        expect(
          () => BearoundFlutterSdk.configure(businessToken: ''),
          throwsA(isA<ArgumentError>()),
        );

        expect(methodCalls, isEmpty);
      },
    );

    test(
      'configure throws ArgumentError when businessToken is whitespace',
      () async {
        expect(
          () => BearoundFlutterSdk.configure(businessToken: '   '),
          throwsA(isA<ArgumentError>()),
        );

        expect(methodCalls, isEmpty);
      },
    );

    test('configure trims businessToken whitespace', () async {
      await BearoundFlutterSdk.configure(businessToken: '  test-token  ');

      expect(methodCalls, hasLength(1));
      expect(
        methodCalls.first.arguments['businessToken'],
        equals('test-token'),
      );
    });

    test(
      'configure with minimum foreground scan interval (5 seconds)',
      () async {
        await BearoundFlutterSdk.configure(
          businessToken: 'test-token',
          foregroundScanInterval: ForegroundScanInterval.seconds5,
        );

        expect(
          methodCalls.first.arguments['foregroundScanInterval'],
          equals(5),
        );
      },
    );

    test(
      'configure with maximum foreground scan interval (60 seconds)',
      () async {
        await BearoundFlutterSdk.configure(
          businessToken: 'test-token',
          foregroundScanInterval: ForegroundScanInterval.seconds60,
        );

        expect(
          methodCalls.first.arguments['foregroundScanInterval'],
          equals(60),
        );
      },
    );

    test('configure with different background scan intervals', () async {
      await BearoundFlutterSdk.configure(
        businessToken: 'test-token',
        backgroundScanInterval: BackgroundScanInterval.seconds120,
      );

      expect(
        methodCalls.first.arguments['backgroundScanInterval'],
        equals(120),
      );
    });

    test('configure with different max queued payloads', () async {
      await BearoundFlutterSdk.configure(
        businessToken: 'test-token',
        maxQueuedPayloads: MaxQueuedPayloads.xlarge,
      );

      expect(methodCalls.first.arguments['maxQueuedPayloads'], equals(500));
    });
  });

  group('BearoundFlutterSdk Scanning', () {
    test('startScanning triggers method channel call', () async {
      await BearoundFlutterSdk.startScanning();

      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, equals('startScanning'));
    });

    test('stopScanning triggers method channel call', () async {
      await BearoundFlutterSdk.stopScanning();

      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, equals('stopScanning'));
    });

    test('isScanning returns true when scanning', () async {
      final result = await BearoundFlutterSdk.isScanning();

      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, equals('isScanning'));
      expect(result, isTrue);
    });
  });

  group('BearoundFlutterSdk User Properties', () {
    test('setUserProperties sends complete payload', () async {
      final internalId = faker.guid.guid();
      final email = faker.internet.email();
      final name = faker.person.name();

      await BearoundFlutterSdk.setUserProperties(
        UserProperties(
          internalId: internalId,
          email: email,
          name: name,
          customProperties: {'plan': 'premium', 'tier': 'gold'},
        ),
      );

      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, equals('setUserProperties'));
      expect(
        methodCalls.first.arguments,
        equals({
          'internalId': internalId,
          'email': email,
          'name': name,
          'customProperties': {'plan': 'premium', 'tier': 'gold'},
        }),
      );
    });

    test('setUserProperties with minimal data', () async {
      await BearoundFlutterSdk.setUserProperties(const UserProperties());

      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, equals('setUserProperties'));
      expect(methodCalls.first.arguments, equals({'customProperties': {}}));
    });

    test('clearUserProperties triggers method channel call', () async {
      await BearoundFlutterSdk.clearUserProperties();

      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, equals('clearUserProperties'));
    });
  });

  group('BearoundFlutterSdk Streams', () {
    test('beaconsStream is available', () {
      expect(BearoundFlutterSdk.beaconsStream, isA<Stream<List<Beacon>>>());
    });

    test('scanningStream is available', () {
      expect(BearoundFlutterSdk.scanningStream, isA<Stream<bool>>());
    });

    test('errorStream is available', () {
      expect(BearoundFlutterSdk.errorStream, isA<Stream<BearoundError>>());
    });
  });
}
