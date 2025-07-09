import 'dart:async';
import 'package:flutter/services.dart';
import 'bearound_flutter_sdk_platform_interface.dart';

class MethodChannelBearoundFlutterSdk extends BearoundFlutterSdkPlatform {
  static const MethodChannel _channel = MethodChannel('bearound_flutter_sdk');
  static const EventChannel _eventChannel = EventChannel('bearound_flutter_sdk_events');

  Stream<Map<String, dynamic>>? _eventsStream;

  @override
  Future<void> initialize({bool debug = false}) async {
    await _channel.invokeMethod('initialize', {'debug': debug});
  }

  @override
  Future<void> stop() async {
    await _channel.invokeMethod('stop');
  }

  @override
  Stream<Map<String, dynamic>> get events {
    _eventsStream ??= _eventChannel
        .receiveBroadcastStream()
        .map<Map<String, dynamic>>(
            (dynamic event) => Map<String, dynamic>.from(event));
    return _eventsStream!;
  }

  @override
  Future<String> getAppState() async {
    try {
      final state = await _channel.invokeMethod<String>('getAppState');
      return state ?? "unknown";
    } catch (e) {
      return "unknown";
    }
  }

  @override
  Future<String> getAdvertisingId() async {
    try {
      final id = await _channel.invokeMethod<String>('getAdvertisingId');
      return id ?? "unknown";
    } catch (e) {
      return "unknown";
    }
  }
}
