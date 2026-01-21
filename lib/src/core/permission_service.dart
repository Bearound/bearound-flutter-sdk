import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();

  static const MethodChannel _channel = MethodChannel('bearound_flutter_sdk');

  Future<bool> requestPermissions() async {
    try {
      if (Platform.isIOS) {
        // iOS: Use native method that calls requestAlwaysAuthorization()
        // This is the same approach used by React Native SDK
        final result = await _channel.invokeMethod<bool>('requestPermissions');
        return result ?? false;
      } else {
        // Android: Use permission_handler package
        bool hasLocationPermission = false;
        bool hasBluetoothPermission = false;

        // Request location permission (essential)
        final locationStatus = await Permission.location.request();
        hasLocationPermission = locationStatus.isGranted;

        // Request background location if Android >= 10 (optional but recommended)
        if (hasLocationPermission) {
          await Permission.locationAlways.request();
        }

        // Request Bluetooth permissions (essential for beacon scanning)
        final bluetoothScanStatus = await Permission.bluetoothScan.request();
        final bluetoothConnectStatus = await Permission.bluetoothConnect
            .request();

        hasBluetoothPermission =
            bluetoothScanStatus.isGranted ||
            bluetoothConnectStatus.isGranted ||
            await Permission.bluetooth.isGranted;

        // Request optional permissions (won't block if denied)
        await Permission.bluetoothAdvertise.request();
        await Permission.notification.request();

        return hasLocationPermission || hasBluetoothPermission;
      }
    } catch (e) {
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
        // Android: Check via permission_handler
        final location = await Permission.location.isGranted;
        final bluetooth =
            await Permission.bluetoothScan.isGranted ||
            await Permission.bluetooth.isGranted;
        return location || bluetooth;
      }
    } catch (e) {
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
    } catch (e) {
      return false;
    }
  }
}
