# 🐻 Bearound Flutter SDK

[![CI](https://github.com/Bearound/bearound-flutter-sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/Bearound/bearound-flutter-sdk/actions/workflows/ci.yml)
[![Release](https://github.com/Bearound/bearound-flutter-sdk/actions/workflows/release.yml/badge.svg)](https://github.com/Bearound/bearound-flutter-sdk/actions/workflows/release.yml)
[![codecov](https://codecov.io/gh/Bearound/bearound-flutter-sdk/branch/main/graph/badge.svg)](https://codecov.io/gh/Bearound/bearound-flutter-sdk)
[![pub.dev](https://img.shields.io/pub/v/bearound_flutter_sdk.svg)](https://pub.dev/packages/bearound_flutter_sdk)

Official Flutter plugin for integrating Bearound's secure BLE beacon detection and indoor location technology.

## ✨ Features

- 🎯 **BLE Beacon Scanning**: High-performance beacon detection for iOS and Android
- 🔄 **Real-time Scanning**: High-performance beacon detection with distance estimation
- 🛡️ **Cross-platform**: Unified API for iOS and Android with native performance
- 🔐 **Secure**: Built-in token-based authentication and encrypted communication
- 🎛️ **Permission Management**: Automatic handling of location and Bluetooth permissions
- 📱 **Background Support**: Continue scanning even when app is in background
- 🧪 **Well Tested**: Comprehensive unit test suite with 25+ test cases
- 📚 **Type Safe**: Full null-safety support and comprehensive documentation

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  bearound_flutter_sdk: ^1.0.0
```

Install the package:

```bash
flutter pub get
```

## ⚙️ Platform Setup

### Android Configuration

Add the following permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Required permissions -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />

<!-- Android 12+ (API 31+) -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />

<!-- Background scanning -->
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

### iOS Configuration

Add the following to `ios/Runner/Info.plist`:

```xml
<!-- Background modes -->
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>location</string>
</array>

<!-- Permission descriptions -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to detect nearby beacons for location services.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to detect nearby beacons.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs location access to detect nearby beacons, even in background.</string>

<key>NSUserTrackingUsageDescription</key>
<string>This app needs tracking permission for beacon detection on iOS 14+.</string>
```

> **Note:** Requires iOS 13.0+ for optimal performance. Background scanning requires additional iOS configuration.

## 🚀 Quick Start

### Basic Usage

```dart
import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';

class BeaconScanner extends StatefulWidget {
  @override
  _BeaconScannerState createState() => _BeaconScannerState();
}

class _BeaconScannerState extends State<BeaconScanner> {
  bool _isScanning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Beacon Scanner')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _isScanning ? _stopScanning : _startScanning,
            child: Text(_isScanning ? 'Stop Scanning' : 'Start Scanning'),
          ),
          Expanded(
            child: Center(
              child: Text(_isScanning ? 'Scanning for beacons...' : 'Press to start'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startScanning() async {
    // Request permissions first
    final granted = await BearoundFlutterSdk.requestPermissions();
    if (!granted) {
      print('Permissions not granted');
      return;
    }

    // Start scanning with your client token
    await BearoundFlutterSdk.startScan(
      'your-client-token-here',
      debug: true, // Enable debug logs
    );

    setState(() => _isScanning = true);
  }

  Future<void> _stopScanning() async {
    await BearoundFlutterSdk.stopScan();
    setState(() => _isScanning = false);
  }

  @override
  void dispose() {
    if (_isScanning) {
      BearoundFlutterSdk.stopScan();
    }
    super.dispose();
  }
}
```

### Permission Handling Example

```dart
class PermissionManager {
  static Future<bool> checkAndRequestPermissions() async {
    try {
      final granted = await BearoundFlutterSdk.requestPermissions();
      return granted;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  static void showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permissions Required'),
        content: Text(
          'This app needs location and Bluetooth permissions to detect beacons. '
          'Please grant the required permissions in the next dialog.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await checkAndRequestPermissions();
            },
            child: Text('Grant Permissions'),
          ),
        ],
      ),
    );
  }
}

## 📋 API Reference

### BearoundFlutterSdk

The main entry point for the SDK.

#### Methods

##### `requestPermissions()`

Requests all necessary permissions for beacon scanning.

```dart
static Future<bool> requestPermissions()
```

**Returns:** `true` if all permissions are granted, `false` otherwise.

##### `startScan(String clientToken, {bool debug = false})`

Starts beacon scanning with the provided client token.

```dart
static Future<void> startScan(String clientToken, {bool debug = false})
```

**Parameters:**
- `clientToken` (String): Your Bearound client token
- `debug` (bool): Enable debug logging (default: `false`)

**Throws:** `Exception` if permissions are not granted or scanning fails.

##### `stopScan()`

Stops beacon scanning and cleans up resources.

```dart
static Future<void> stopScan()
```

### Beacon Model

Represents a detected beacon with all its properties.

```dart
class Beacon {
  final String uuid;              // Beacon UUID
  final int major;                // Major identifier
  final int minor;                // Minor identifier
  final int rssi;                 // Signal strength in dBm
  final String? bluetoothName;    // Bluetooth device name (optional)
  final String? bluetoothAddress; // Bluetooth MAC address (optional)
  final double? distanceMeters;   // Estimated distance in meters (optional)
}
```

#### Methods

##### `fromJson(Map<String, dynamic> json)`

Creates a Beacon instance from JSON data.

##### `toJson()`

Converts the beacon to JSON format.

## 🛡️ Error Handling

The SDK provides comprehensive error handling:

```dart
try {
  final granted = await BearoundFlutterSdk.requestPermissions();
  if (!granted) {
    throw Exception('Required permissions not granted');
  }
  
  await BearoundFlutterSdk.startScan('your-token');
} catch (e) {
  print('Error starting beacon scan: $e');
  // Handle the error appropriately
}
```

## 🧪 Testing

The SDK includes a comprehensive test suite. Run tests with:

```bash
flutter test
```

For coverage report:

```bash
flutter test --coverage
```

## 🤝 Contributing

We welcome contributions! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass: `flutter test`
6. Check code formatting: `dart format .`
7. Run static analysis: `flutter analyze`
8. Submit a pull request

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed list of changes.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- 📚 [Documentation](https://docs.bearound.com)
- 🐛 [Issue Tracker](https://github.com/Bearound/bearound-flutter-sdk/issues)
- 💬 [Discussions](https://github.com/Bearound/bearound-flutter-sdk/discussions)
- 📧 [Email Support](mailto:support@bearound.com)
