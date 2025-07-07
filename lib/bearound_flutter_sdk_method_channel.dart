import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bearound_flutter_sdk_platform_interface.dart';

/// An implementation of [BearoundFlutterSdkPlatform] that uses method channels.
class MethodChannelBearoundFlutterSdk extends BearoundFlutterSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('bearound_flutter_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
