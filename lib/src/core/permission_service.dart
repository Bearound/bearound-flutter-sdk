import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show visibleForTesting;
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

  /// Android 13 — where `NEARBY_WIFI_DEVICES` exists.
  static const int _androidT = 33;

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

  /// [includeBackgroundLocation] — whether to also request ACCESS_BACKGROUND_LOCATION.
  /// **Defaults to false, and that default is a policy decision, not a preference.**
  ///
  /// Google Play requires the host app to show a prominent disclosure *before* any
  /// background-location request. An SDK asking on its own takes that ordering away from
  /// the host: the system screen appears no matter what the user answered to the app's own
  /// disclosure, which also makes the demonstration video Play asks for impossible to record
  /// honestly. So the host decides when — and whether — to ask.
  ///
  /// The permission is not free to skip: from Android 10 on, a backgrounded app without it
  /// gets an empty Wi-Fi scan list and the placeholder BSSID 02:00:00:00:00:00 — no error,
  /// nothing in logcat, `wifis[]` simply arrives empty (measured: 25 access points to zero
  /// the instant the app backgrounded). Beacon detection is unaffected — on 12+ the scan
  /// runs on BLUETOOTH_SCAN alone. Pass true only after your own disclosure.
  Future<bool> requestPermissions({
    bool includeBackgroundLocation = false,
  }) async {
    try {
      if (Platform.isIOS) {
        // iOS: Use native method that calls requestAlwaysAuthorization()
        // This is the same approach used by React Native SDK
        final result = await _channel.invokeMethod<bool>('requestPermissions');
        return result ?? false;
      } else {
        return await _requestAndroidPermissions(
          includeBackgroundLocation: includeBackgroundLocation,
        );
      }
    } catch (e, s) {
      // Doctrine: fail silently for the host, but every silent failure reports —
      // a broken permission_handler here masks "permission never granted" bugs.
      ErrorReporter.instance.reportCaught(e, s, context: 'requestPermissions');
      return false;
    }
  }

  /// Extracted so tests can exercise the Android permission-request flow
  /// directly. `Platform.isAndroid` reflects the *host* OS in a `flutter test`
  /// run (there is no device), so it is always false there and the branch in
  /// [requestPermissions] is otherwise unreachable off-device.
  @visibleForTesting
  Future<bool> requestAndroidPermissionsForTest({
    bool includeBackgroundLocation = false,
  }) => _requestAndroidPermissions(
    includeBackgroundLocation: includeBackgroundLocation,
  );

  Future<bool> _requestAndroidPermissions({
    required bool includeBackgroundLocation,
  }) async {
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

      // Encounter layer: BLUETOOTH_ADVERTISE lets other SDK devices see
      // this one. It is in the SAME "Nearby devices" runtime group as
      // BLUETOOTH_SCAN on Android 12+, so requesting it here does not
      // pop a second system dialog. Denial degrades gracefully — it does
      // NOT gate the scan (bluetoothScanStatus below is unaffected), it
      // only makes this device invisible to peers: the mesh becomes
      // one-way instead of failing outright.
      await Permission.bluetoothAdvertise.request();

      // Background location is NOT part of the scan gate — on 12+ the SDK
      // scans on BLUETOOTH_SCAN, with no location at all. Do NOT remove it
      // for that reason: it is what keeps the Wi-Fi observations coming once
      // the app is backgrounded. Without it, from Android 10 on, a
      // backgrounded app gets an empty scan list and the placeholder BSSID
      // 02:00:00:00:00:00 — no error, nothing in logcat, `wifis[]` simply
      // arrives empty. Measured in production on a sibling SDK: 25 access
      // points dropped to zero the instant the app went to background, with
      // every permission it asked for granted.
      final locationStatus = await Permission.location.request();
      if (includeBackgroundLocation && locationStatus.isGranted) {
        await Permission.locationAlways.request();
      }
      await Permission.notification.request();

      // Android 13+: unlocks the neighbouring access points for the Wi-Fi
      // observations. Same "Nearby devices" dialog as BLUETOOTH_SCAN, so it
      // costs the user no extra prompt — and without it the SDK reports only
      // the connected access point, never its neighbours.
      if (sdkInt >= _androidT) {
        await Permission.nearbyWifiDevices.request();
      }

      // The scan can only run with BLUETOOTH_SCAN — do not report success
      // from location alone.
      return bluetoothScanStatus.isGranted;
    } else {
      // Android <12: location unlocks the BLE scan.
      final locationStatus = await Permission.location.request();
      if (includeBackgroundLocation && locationStatus.isGranted) {
        await Permission.locationAlways.request();
      }
      await Permission.notification.request();
      return locationStatus.isGranted;
    }
  }

  Future<bool> checkPermissions() async {
    try {
      if (Platform.isIOS) {
        // iOS: Check via native code
        final result = await _channel.invokeMethod<bool>('checkPermissions');
        return result ?? false;
      } else {
        return await _checkAndroidPermissions();
      }
    } catch (e, s) {
      ErrorReporter.instance.reportCaught(e, s, context: 'checkPermissions');
      return false;
    }
  }

  /// Same seam as [requestAndroidPermissionsForTest] — see its doc.
  @visibleForTesting
  Future<bool> checkAndroidPermissionsForTest() => _checkAndroidPermissions();

  Future<bool> _checkAndroidPermissions() async {
    // Android: reflect what the SCAN actually needs (see requestPermissions).
    // - 12+: BLUETOOTH_SCAN granted (location is NOT sufficient).
    // - <12: fine/coarse location granted.
    final sdkInt = await _androidSdkInt();
    if (sdkInt >= _androidS) {
      // Read bluetoothAdvertise's status too so it is observable — but
      // it does NOT gate the returned bool: the scan only depends on
      // bluetoothScan, and a denied bluetoothAdvertise must not report
      // the SDK as broken (see requestPermissions doc — it only makes
      // this device invisible to peers, not blind).
      await Permission.bluetoothAdvertise.isGranted;
      return await Permission.bluetoothScan.isGranted;
    }
    return await Permission.location.isGranted;
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
