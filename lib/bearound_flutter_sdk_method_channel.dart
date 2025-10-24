import 'dart:async';
import 'package:flutter/services.dart';
import 'bearound_flutter_sdk_platform_interface.dart';
import 'src/core.dart';

class MethodChannelBearoundFlutterSdk extends BearoundFlutterSdkPlatform {
  static const MethodChannel _channel = MethodChannel('bearound_flutter_sdk');

  // EventChannels for listening to native events
  static const EventChannel _beaconsEventChannel =
      EventChannel('bearound_flutter_sdk/beacons');
  static const EventChannel _syncEventChannel =
      EventChannel('bearound_flutter_sdk/sync');
  static const EventChannel _regionEventChannel =
      EventChannel('bearound_flutter_sdk/region');

  // Streams for beacon events
  Stream<BeaconsDetectedEvent>? _beaconsStream;
  Stream<BeaconEvent>? _syncStream;
  Stream<BeaconEvent>? _regionStream;

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

  /// Stream of beacon detection events
  @override
  Stream<BeaconsDetectedEvent> get beaconsStream {
    _beaconsStream ??= _beaconsEventChannel
        .receiveBroadcastStream()
        .map((dynamic event) {
          final map = Map<String, dynamic>.from(event as Map);
          return BeaconsDetectedEvent.fromJson(map);
        });
    return _beaconsStream!;
  }

  /// Stream of sync events (success and error)
  @override
  Stream<BeaconEvent> get syncStream {
    _syncStream ??= _syncEventChannel
        .receiveBroadcastStream()
        .map((dynamic event) {
          final map = Map<String, dynamic>.from(event as Map);
          return BeaconEvent.fromJson(map);
        });
    return _syncStream!;
  }

  /// Stream of region events (enter and exit)
  @override
  Stream<BeaconEvent> get regionStream {
    _regionStream ??= _regionEventChannel
        .receiveBroadcastStream()
        .map((dynamic event) {
          final map = Map<String, dynamic>.from(event as Map);
          return BeaconEvent.fromJson(map);
        });
    return _regionStream!;
  }
}
