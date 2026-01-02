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

          // Mock responses for specific methods
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
      final appId = faker.company.name();

      await BearoundFlutterSdk.configure(
        appId: appId,
        syncInterval: const Duration(seconds: 20),
        enableBluetoothScanning: true,
        enablePeriodicScanning: false,
      );

      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, equals('configure'));
      expect(
        methodCalls.first.arguments,
        equals({
          'appId': appId,
          'syncInterval': 20,
          'enableBluetoothScanning': true,
          'enablePeriodicScanning': false,
        }),
      );
    });

    test('configure uses default values when parameters are omitted', () async {
      await BearoundFlutterSdk.configure();

      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, equals('configure'));
      expect(
        methodCalls.first.arguments,
        equals({
          'syncInterval': 30,
          'enableBluetoothScanning': false,
          'enablePeriodicScanning': true,
        }),
      );
    });

    test('configure ignores empty appId', () async {
      await BearoundFlutterSdk.configure(appId: '   ');

      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.arguments, isNot(contains('appId')));
    });

    test('configure trims appId whitespace', () async {
      await BearoundFlutterSdk.configure(appId: '  test-app  ');

      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.arguments['appId'], equals('test-app'));
    });

    test('configure with minimum sync interval (5 seconds)', () async {
      await BearoundFlutterSdk.configure(
        syncInterval: const Duration(seconds: 5),
      );

      expect(methodCalls.first.arguments['syncInterval'], equals(5));
    });

    test('configure with maximum sync interval (60 seconds)', () async {
      await BearoundFlutterSdk.configure(
        syncInterval: const Duration(seconds: 60),
      );

      expect(methodCalls.first.arguments['syncInterval'], equals(60));
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

    test('setBluetoothScanning with enabled true', () async {
      await BearoundFlutterSdk.setBluetoothScanning(true);

      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, equals('setBluetoothScanning'));
      expect(methodCalls.first.arguments, equals({'enabled': true}));
    });

    test('setBluetoothScanning with enabled false', () async {
      await BearoundFlutterSdk.setBluetoothScanning(false);

      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, equals('setBluetoothScanning'));
      expect(methodCalls.first.arguments, equals({'enabled': false}));
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

    test('syncStream is available', () {
      expect(BearoundFlutterSdk.syncStream, isA<Stream<SyncStatus>>());
    });

    test('scanningStream is available', () {
      expect(BearoundFlutterSdk.scanningStream, isA<Stream<bool>>());
    });

    test('errorStream is available', () {
      expect(BearoundFlutterSdk.errorStream, isA<Stream<BearoundError>>());
    });
  });
}
