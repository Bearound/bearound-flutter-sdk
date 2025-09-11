import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:bearound_flutter_sdk/bearound_flutter_sdk_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelBearoundFlutterSdk', () {
    late MethodChannelBearoundFlutterSdk methodChannel;
    const MethodChannel channel = MethodChannel('bearound_flutter_sdk');
    List<MethodCall> methodCalls = [];

    setUp(() {
      methodChannel = MethodChannelBearoundFlutterSdk();
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

    group('initialize', () {
      test('should call initialize method with clientToken and debug false', () async {
        const clientToken = 'test-client-token';
        const debug = false;

        await methodChannel.initialize(clientToken, debug: debug);

        expect(methodCalls, hasLength(1));
        expect(methodCalls[0].method, equals('initialize'));
        expect(methodCalls[0].arguments, equals({
          'debug': debug,
          'clientToken': clientToken,
        }));
      });

      test('should call initialize method with clientToken and debug true', () async {
        const clientToken = 'test-client-token';
        const debug = true;

        await methodChannel.initialize(clientToken, debug: debug);

        expect(methodCalls, hasLength(1));
        expect(methodCalls[0].method, equals('initialize'));
        expect(methodCalls[0].arguments, equals({
          'debug': debug,
          'clientToken': clientToken,
        }));
      });

      test('should call initialize method with default debug false', () async {
        const clientToken = 'test-client-token';

        await methodChannel.initialize(clientToken);

        expect(methodCalls, hasLength(1));
        expect(methodCalls[0].method, equals('initialize'));
        expect(methodCalls[0].arguments, equals({
          'debug': false,
          'clientToken': clientToken,
        }));
      });

      test('should handle platform exception during initialize', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          throw PlatformException(
            code: 'ERROR',
            message: 'Platform error',
            details: null,
          );
        });

        expect(
          () async => await methodChannel.initialize('test-token'),
          throwsA(isA<PlatformException>()),
        );
      });
    });

    group('stop', () {
      test('should call stop method', () async {
        await methodChannel.stop();

        expect(methodCalls, hasLength(1));
        expect(methodCalls[0].method, equals('stop'));
        expect(methodCalls[0].arguments, isNull);
      });

      test('should handle platform exception during stop', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          throw PlatformException(
            code: 'ERROR',
            message: 'Platform error',
            details: null,
          );
        });

        expect(
          () async => await methodChannel.stop(),
          throwsA(isA<PlatformException>()),
        );
      });
    });

    test('should handle missing plugin exception', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw MissingPluginException();
      });

      expect(
        () async => await methodChannel.initialize('test-token'),
        throwsA(isA<MissingPluginException>()),
      );
    });
  });
}