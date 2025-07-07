import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'bearound_flutter_sdk_method_channel.dart';

abstract class BearoundFlutterSdkPlatform extends PlatformInterface {
  /// Constructs a BearoundFlutterSdkPlatform.
  BearoundFlutterSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static BearoundFlutterSdkPlatform _instance = MethodChannelBearoundFlutterSdk();

  /// The default instance of [BearoundFlutterSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelBearoundFlutterSdk].
  static BearoundFlutterSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [BearoundFlutterSdkPlatform] when
  /// they register themselves.
  static set instance(BearoundFlutterSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
