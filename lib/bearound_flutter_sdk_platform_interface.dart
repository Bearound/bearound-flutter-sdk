import 'package:bearound_flutter_sdk/bearound_flutter_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class BearoundFlutterSdkPlatform extends PlatformInterface {
  BearoundFlutterSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static BearoundFlutterSdkPlatform _instance = MethodChannelBearoundFlutterSdk();

  static BearoundFlutterSdkPlatform get instance => _instance;

  static set instance(BearoundFlutterSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initialize({bool debug = false}) async {
    throw UnimplementedError('getAdvertisingId() has not been implemented.');
  }

  Future<void> stop() async {
    throw UnimplementedError('getAdvertisingId() has not been implemented.');
  }

  Stream<Map<String, dynamic>> get events;
  Future<String> getAppState() async {
    throw UnimplementedError('getAdvertisingId() has not been implemented.');
  }

  Future<String> getAdvertisingId() async {
    throw UnimplementedError('getAdvertisingId() has not been implemented.');
  }
}
