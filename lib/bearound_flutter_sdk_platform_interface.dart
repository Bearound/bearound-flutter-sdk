import 'package:bearound_flutter_sdk/bearound_flutter_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'src/core.dart';

abstract class BearoundFlutterSdkPlatform extends PlatformInterface {
  BearoundFlutterSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static BearoundFlutterSdkPlatform _instance =
      MethodChannelBearoundFlutterSdk();

  static BearoundFlutterSdkPlatform get instance => _instance;

  static set instance(BearoundFlutterSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initialize(String clientToken, {bool debug = false}) async {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  Future<void> stop() async {
    throw UnimplementedError('stop() has not been implemented.');
  }

  /// Stream of beacon detection events
  Stream<BeaconsDetectedEvent> get beaconsStream {
    throw UnimplementedError('beaconsStream has not been implemented.');
  }

  /// Stream of sync events (success and error)
  Stream<BeaconEvent> get syncStream {
    throw UnimplementedError('syncStream has not been implemented.');
  }

  /// Stream of region events (enter and exit)
  Stream<BeaconEvent> get regionStream {
    throw UnimplementedError('regionStream has not been implemented.');
  }
}
