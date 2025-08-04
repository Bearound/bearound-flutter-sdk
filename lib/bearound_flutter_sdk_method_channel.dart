import 'dart:async';
import 'package:flutter/services.dart';
import 'bearound_flutter_sdk_platform_interface.dart';

class MethodChannelBearoundFlutterSdk extends BearoundFlutterSdkPlatform {
  static const MethodChannel _channel = MethodChannel('bearound_flutter_sdk');
  static const EventChannel _eventChannel = EventChannel('bearound_flutter_sdk_events');

  Stream<Map<String, dynamic>>? _beaconEventsStream;

  @override
  Future<void> initialize({bool debug = false}) async {
    await _channel.invokeMethod('initialize', {'debug': debug});
  }

  @override
  Future<void> stop() async {
    await _channel.invokeMethod('stop');
  }

  @override
  Stream<Map<String, dynamic>> get beaconStream {
    _beaconEventsStream ??= _eventChannel
        .receiveBroadcastStream()
        .map<Map<String, dynamic>>((event) => Map<String, dynamic>.from(event));
    return _beaconEventsStream!;
  }
}
