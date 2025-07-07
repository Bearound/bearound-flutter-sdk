
import 'bearound_flutter_sdk_platform_interface.dart';

class BearoundFlutterSdk {
  Future<String?> getPlatformVersion() {
    return BearoundFlutterSdkPlatform.instance.getPlatformVersion();
  }
}
