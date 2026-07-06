import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../telemetry/error_reporter.dart';

class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();

  static const MethodChannel _channel = MethodChannel('bearound_flutter_sdk');

  /// Android 12 (S) = API level 31 — first version where the BLE scan is gated
  /// on BLUETOOTH_SCAN (manifest `neverForLocation`) instead of location.
  static const int _androidS = 31;

  /// Reads `Build.VERSION.SDK_INT` from the native plugin so the Dart layer can
  /// mirror the native scan gate exactly. Falls back to [_androidS] (assume the
  /// stricter 12+ gate) if the call fails.
  Future<int> _androidSdkInt() async {
    try {
      final level = await _channel.invokeMethod<int>('getAndroidSdkInt');
      return level ?? _androidS;
    } catch (_) {
      return _androidS;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      if (Platform.isIOS) {
        // iOS: Use native method that calls requestAlwaysAuthorization()
        // This is the same approach used by React Native SDK
        final result = await _channel.invokeMethod<bool>('requestPermissions');
        return result ?? false;
      } else {
        // Android: mirror the native SDK 3.4.5 scan gate.
        // - 12+ (API 31+): ONLY BLUETOOTH_SCAN unlocks the scan (manifest
        //   `neverForLocation`). Location does NOT unlock it, so we do NOT treat
        //   location as sufficient here.
        // - <12: legacy model — ACCESS_FINE/COARSE_LOCATION unlocks the scan.
        final sdkInt = await _androidSdkInt();

        if (sdkInt >= _androidS) {
          // Essential on 12+: BLUETOOTH_SCAN. BLUETOOTH_CONNECT is requested too
          // (needed for the connectedDevice foreground service), but only SCAN
          // gates detection.
          final bluetoothScanStatus = await Permission.bluetoothScan.request();
          await Permission.bluetoothConnect.request();

          // Background location still helps CoreLocation-style wake-ups on
          // Android and is recommended, but it is NOT part of the scan gate.
          final locationStatus = await Permission.location.request();
          if (locationStatus.isGranted) {
            await Permission.locationAlways.request();
          }
          await Permission.notification.request();

          // The scan can only run with BLUETOOTH_SCAN — do not report success
          // from location alone.
          return bluetoothScanStatus.isGranted;
        } else {
          // Android <12: location unlocks the BLE scan.
          final locationStatus = await Permission.location.request();
          if (locationStatus.isGranted) {
            await Permission.locationAlways.request();
          }
          await Permission.notification.request();
          return locationStatus.isGranted;
        }
      }
    } catch (e, s) {
      // Doctrine: fail silently for the host, but every silent failure reports —
      // a broken permission_handler here masks "permission never granted" bugs.
      ErrorReporter.instance.reportCaught(e, s, context: 'requestPermissions');
      return false;
    }
  }

  Future<bool> checkPermissions() async {
    try {
      if (Platform.isIOS) {
        // iOS: Check via native code
        final result = await _channel.invokeMethod<bool>('checkPermissions');
        return result ?? false;
      } else {
        // Android: reflect what the SCAN actually needs (see requestPermissions).
        // - 12+: BLUETOOTH_SCAN granted (location is NOT sufficient).
        // - <12: fine/coarse location granted.
        final sdkInt = await _androidSdkInt();
        if (sdkInt >= _androidS) {
          return await Permission.bluetoothScan.isGranted;
        }
        return await Permission.location.isGranted;
      }
    } catch (e, s) {
      ErrorReporter.instance.reportCaught(e, s, context: 'checkPermissions');
      return false;
    }
  }

  Future<bool> requestNotification() async {
    try {
      final bool granted = await Permission.notification.isGranted;
      if (granted) {
        return true;
      }
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (e, s) {
      ErrorReporter.instance.reportCaught(e, s, context: 'requestNotification');
      return false;
    }
  }
}
