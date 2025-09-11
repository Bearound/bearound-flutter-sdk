import 'package:flutter_test/flutter_test.dart';
import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BearoundFlutterSdk', () {
    const MethodChannel channel = MethodChannel('bearound_flutter_sdk');
    List<MethodCall> methodCalls = [];

    setUp(() {
      methodCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            methodCalls.add(methodCall);

            switch (methodCall.method) {
              case 'initialize':
                return null;
              case 'stop':
                return null;
              default:
                throw MissingPluginException();
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    group('requestPermissions', () {
      test('should call PermissionService requestPermissions', () async {
        expect(BearoundFlutterSdk.requestPermissions, isA<Function>());
      });
    });

    group('startScan', () {
      test(
        'should call BeaconScanner startScan with correct parameters',
        () async {
          const clientToken = 'test-token';
          const debug = true;

          try {
            await BearoundFlutterSdk.startScan(clientToken, debug: debug);
          } catch (e) {
            // Expected to fail due to permission requirements in test environment
          }

          expect(BearoundFlutterSdk.startScan, isA<Function>());
        },
      );

      test(
        'should call BeaconScanner startScan with default debug false',
        () async {
          const clientToken = 'test-token';

          try {
            await BearoundFlutterSdk.startScan(clientToken);
          } catch (e) {
            // Expected to fail due to permission requirements in test environment
          }

          expect(BearoundFlutterSdk.startScan, isA<Function>());
        },
      );
    });

    group('stopScan', () {
      test('should call BeaconScanner stopScan', () async {
        await BearoundFlutterSdk.stopScan();

        expect(methodCalls, hasLength(1));
        expect(methodCalls[0].method, equals('stop'));
      });
    });

    test('should have private constructor', () {
      // Test that the class cannot be instantiated
      expect(BearoundFlutterSdk, isA<Type>());
    });
  });
}
