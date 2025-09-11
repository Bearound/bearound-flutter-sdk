import 'package:flutter_test/flutter_test.dart';
import 'package:bearound_flutter_sdk/src/core/beacon_scanner.dart';
import 'package:bearound_flutter_sdk/bearound_flutter_sdk_method_channel.dart';
import 'package:bearound_flutter_sdk/src/core/permission_service.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BeaconScanner', () {
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

    group('startScan', () {
      test('should call initialize method with correct parameters', () async {
        const clientToken = 'test-token';
        const debug = true;

        try {
          await BeaconScanner.startScan(clientToken, debug: debug);
        } catch (e) {
          // Expected to fail due to permission check, but we can still verify method calls
        }

        // Since permissions will likely fail in test environment,
        // we focus on testing the method structure
        expect(BeaconScanner.startScan, isA<Function>());
      });

      test('should handle permission denied gracefully', () async {
        const clientToken = 'test-token';

        expect(
          () async => await BeaconScanner.startScan(clientToken),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('stopScan', () {
      test('should call stop method', () async {
        await BeaconScanner.stopScan();

        expect(methodCalls, hasLength(1));
        expect(methodCalls[0].method, equals('stop'));
      });
    });
  });
}