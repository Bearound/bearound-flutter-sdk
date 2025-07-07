import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bearound_flutter_sdk/bearound_flutter_sdk_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelBearoundFlutterSdk platform = MethodChannelBearoundFlutterSdk();
  const MethodChannel channel = MethodChannel('bearound_flutter_sdk');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
