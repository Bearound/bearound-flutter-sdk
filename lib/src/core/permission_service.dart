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
        if (!await Permission.location.isGranted) {
          final status = await Permission.location.request();
          if (!status.isGranted) return false;
        }
        if (!await Permission.locationAlways.isGranted) {
          final status = await Permission.locationAlways.request();
          if (!status.isGranted) return false;
        }
        final blePermissions = <Permission>[
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
          Permission.notification,
        ];
        for (final perm in blePermissions) {
          if (!await perm.isGranted) {
            final status = await perm.request();
            if (!status.isGranted) return false;
          }
        }
        return true;
      }
    } catch (e) {
      return false;
    }
  }
}
