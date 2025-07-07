import 'dart:async';
import 'package:flutter/services.dart';
import 'bearound_flutter_sdk_platform_interface.dart';

class MethodChannelBearoundFlutterSdk extends BearoundFlutterSdkPlatform {
  static const MethodChannel _channel = MethodChannel('bearound_flutter_sdk');
  static const EventChannel _eventChannel = EventChannel('bearound_flutter_sdk_events');

  @override
  Future<void> initialize({bool debug = false}) async {
    await _channel.invokeMethod('initialize', {'debug': debug});
  }

  @override
  Future<void> stop() async {
    await _channel.invokeMethod('stop');
  }

  Stream<Map<String, dynamic>>? _eventsStream;

  @override
  Stream<Map<String, dynamic>> get events {
    _eventsStream ??= _eventChannel
        .receiveBroadcastStream()
        .map<Map<String, dynamic>>((dynamic event) => Map<String, dynamic>.from(event));
    return _eventsStream!;
  }
}
