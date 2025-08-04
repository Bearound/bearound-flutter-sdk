// import 'package:flutter_test/flutter_test.dart';
// import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
// import 'package:bearound_flutter_sdk/bearound_flutter_sdk_platform_interface.dart';
// import 'package:bearound_flutter_sdk/bearound_flutter_sdk_method_channel.dart';
// import 'package:plugin_platform_interface/plugin_platform_interface.dart';
//
// class MockBearoundFlutterSdkPlatform
//     with MockPlatformInterfaceMixin
//     implements BearoundFlutterSdkPlatform {
//
//   @override
//   Future<String?> getPlatformVersion() => Future.value('42');
// }
//
// void main() {
//   final BearoundFlutterSdkPlatform initialPlatform = BearoundFlutterSdkPlatform.instance;
//
//   test('$MethodChannelBearoundFlutterSdk is the default instance', () {
//     expect(initialPlatform, isInstanceOf<MethodChannelBearoundFlutterSdk>());
//   });
//
//   test('getPlatformVersion', () async {
//     BearoundFlutterSdk bearoundFlutterSdkPlugin = BearoundFlutterSdk();
//     MockBearoundFlutterSdkPlatform fakePlatform = MockBearoundFlutterSdkPlatform();
//     BearoundFlutterSdkPlatform.instance = fakePlatform;
//
//     expect(await bearoundFlutterSdkPlugin.getPlatformVersion(), '42');
//   });
// }
