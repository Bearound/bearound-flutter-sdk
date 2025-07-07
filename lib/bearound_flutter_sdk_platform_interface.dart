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

  Future<void> initialize({bool debug = false});
  Future<void> stop();
  Stream<Map<String, dynamic>> get events;
}
