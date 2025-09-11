import 'dart:async';
import 'package:flutter/services.dart';
import 'bearound_flutter_sdk_platform_interface.dart';

class MethodChannelBearoundFlutterSdk extends BearoundFlutterSdkPlatform {
  static const MethodChannel _channel = MethodChannel('bearound_flutter_sdk');

  @override
  Future<void> initialize(String clientToken, {bool debug = false}) async {
    await _channel.invokeMethod('initialize', {
      'debug': debug,
      'clientToken': clientToken,
    });
  }

  @override
  Future<void> stop() async {
    await _channel.invokeMethod('stop');
  }
}
