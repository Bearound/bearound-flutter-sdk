import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart' as loc;

class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();

  Future<bool> requestPermissions() async {
    try {
      if (Platform.isIOS) {
        final location = loc.Location();
        var permissionGranted = await location.hasPermission();
        if (permissionGranted == loc.PermissionStatus.denied) {
          permissionGranted = await location.requestPermission();
        }
        if (permissionGranted != loc.PermissionStatus.granted &&
            permissionGranted != loc.PermissionStatus.grantedLimited) {
          return false;
        }
        return true;
      } else {
        // Android permissions - more flexible approach
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
        // These permissions may not all be available on all Android versions
        final bluetoothScanStatus = await Permission.bluetoothScan.request();
        final bluetoothConnectStatus = await Permission.bluetoothConnect
            .request();

        // Consider bluetooth granted if either bluetoothScan is granted
        // or the old bluetooth permission is granted (for older Android versions)
        hasBluetoothPermission =
            bluetoothScanStatus.isGranted ||
            bluetoothConnectStatus.isGranted ||
            await Permission.bluetooth.isGranted;

        // Request optional permissions (won't block if denied)
        await Permission.bluetoothAdvertise.request();
        await Permission.notification.request();

        // Return true if we have at least location OR bluetooth
        // The SDK can work with either
        return hasLocationPermission || hasBluetoothPermission;
      }
    } catch (e) {
      // Error requesting permissions
      return false;
    }
  }
}
