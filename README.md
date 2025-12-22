# 🐻 Bearound Flutter SDK

[![CI](https://github.com/Bearound/bearound-flutter-sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/Bearound/bearound-flutter-sdk/actions/workflows/ci.yml)
[![Release](https://github.com/Bearound/bearound-flutter-sdk/actions/workflows/release.yml/badge.svg)](https://github.com/Bearound/bearound-flutter-sdk/actions/workflows/release.yml)
[![codecov](https://codecov.io/gh/Bearound/bearound-flutter-sdk/branch/main/graph/badge.svg)](https://codecov.io/gh/Bearound/bearound-flutter-sdk)
[![pub.dev](https://img.shields.io/pub/v/bearound_flutter_sdk.svg)](https://pub.dev/packages/bearound_flutter_sdk)

Official Flutter plugin for integrating Bearound's secure BLE beacon detection and indoor location technology.

## ✨ Features

- 🎯 **BLE Beacon Scanning**: High-performance beacon detection for iOS and Android
- 🔄 **Real-time Event Streams**: Live beacon detection, sync status, and region monitoring
- ⚙️ **Configurable Scanning** (v1.3.1+): Adjustable scan intervals (5-60s) and backup sizes (5-50 beacons) for optimal performance
- 🎛️ **Dynamic Configuration**: Change scan frequency based on battery level or network conditions
- 🛡️ **Cross-platform**: Unified API for iOS and Android with native performance
- 🔐 **Secure**: Built-in token-based authentication and encrypted communication
- 🎛️ **Permission Management**: Automatic handling of location and Bluetooth permissions
- 📱 **Background Support**: Continue scanning even when app is in background
- 🔁 **State Synchronization**: Automatic UI sync when app reopens
- 📊 **Distance Estimation**: Real-time distance calculation to nearby beacons
- 🔋 **Battery Optimization**: Smart filtering and configurable intervals for extended battery life
- 🔍 **Smart Filtering**: Automatically filters invalid beacons (RSSI = 0)
- 🧪 **Well Tested**: Comprehensive unit test suite with 25+ test cases
- 📚 **Type Safe**: Full null-safety support and comprehensive documentation

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  bearound_flutter_sdk: ^1.3.1
```

Install the package:

```bash
flutter pub get
```

### What's New in v1.3.1

- ⚙️ **Configurable Scan Intervals** (5-60 seconds) - Balance between battery and detection speed
- 💾 **Configurable Backup Sizes** (5-50 beacons) - Control failed beacon storage
- 🔧 **Runtime Configuration** - Adjust settings dynamically based on battery or network conditions
- 🎨 **Settings UI Example** - Complete configuration screen in example app
- 🔍 **Smart Beacon Filtering** - Automatically filters invalid beacons (RSSI = 0)
- 🐛 **iOS Bug Fix** - Fixed critical initialization issue preventing beacon detection
- 🚀 **Improved iOS Architecture** - Async/await pattern for reliable permission handling
- 📱 **Native SDK Updates** - iOS 1.3.1 and Android 1.3.1 with modular architecture

> **Important iOS Fix:** This version resolves a critical bug where beacons were not being detected on iOS. The SDK now properly waits for permissions before starting services, ensuring reliable beacon detection.

See [CHANGELOG.md](CHANGELOG.md) for complete release notes.

## ⚙️ Platform Setup

### Android Configuration

#### 1. Project Settings

**Important:** Add the JitPack repository to your `android/settings.gradle.kts` file:

```kotlin
allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}
```

> This configuration is required for the SDK's native Android dependencies to work properly during APK builds.

#### 2. Permissions

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
```

### Real-time Event Streams

The SDK provides three event streams for real-time monitoring of beacon activity:

```dart
class BeaconMonitor extends StatefulWidget {
  @override
  _BeaconMonitorState createState() => _BeaconMonitorState();
}

class _BeaconMonitorState extends State<BeaconMonitor> {
  List<Beacon> _beacons = [];
  String _syncStatus = 'Waiting...';
  String _regionStatus = 'Outside region';

  StreamSubscription<BeaconsDetectedEvent>? _beaconsSubscription;
  StreamSubscription<BeaconEvent>? _syncSubscription;
  StreamSubscription<BeaconEvent>? _regionSubscription;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    // Listen to beacon detection events
    _beaconsSubscription = BearoundFlutterSdk.beaconsStream.listen((event) {
      setState(() {
        _beacons = event.beacons;
      });
      print('Beacons detected (${event.eventType.name}): ${event.beacons.length}');
      for (var beacon in event.beacons) {
        print('  - UUID: ${beacon.uuid}, Major: ${beacon.major}, Minor: ${beacon.minor}');
        print('    RSSI: ${beacon.rssi} dBm, Distance: ${beacon.distanceMeters?.toStringAsFixed(2)}m');
      }
    });

    // Listen to API sync events
    _syncSubscription = BearoundFlutterSdk.syncStream.listen((event) {
      if (event is SyncSuccessEvent) {
        setState(() {
          _syncStatus = 'Success: ${event.beaconsCount} beacons synced';
        });
        print('Sync success: ${event.message}');
      } else if (event is SyncErrorEvent) {
        setState(() {
          _syncStatus = 'Error: ${event.errorMessage}';
        });
        print('Sync error (${event.errorCode}): ${event.errorMessage}');
      }
    });

    // Listen to region enter/exit events
    _regionSubscription = BearoundFlutterSdk.regionStream.listen((event) {
      if (event is BeaconRegionEnterEvent) {
        setState(() {
          _regionStatus = 'Inside region: ${event.regionName}';
        });
        print('Entered beacon region: ${event.regionName}');
      } else if (event is BeaconRegionExitEvent) {
        setState(() {
          _regionStatus = 'Outside region: ${event.regionName}';
        });
        print('Exited beacon region: ${event.regionName}');
      }
    });
  }

  @override
  void dispose() {
    _beaconsSubscription?.cancel();
    _syncSubscription?.cancel();
    _regionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Beacon Monitor')),
      body: Column(
        children: [
          ListTile(
            title: Text('Sync Status'),
            subtitle: Text(_syncStatus),
          ),
          ListTile(
            title: Text('Region Status'),
            subtitle: Text(_regionStatus),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _beacons.length,
              itemBuilder: (context, index) {
                final beacon = _beacons[index];
                return ListTile(
                  title: Text('Beacon ${index + 1}'),
                  subtitle: Text(
                    'UUID: ${beacon.uuid}\n'
                    'Major: ${beacon.major}, Minor: ${beacon.minor}\n'
                    'RSSI: ${beacon.rssi} dBm',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

## ⚙️ Configuration (v1.3.1+)

The SDK provides configurable scan intervals and backup sizes to optimize performance and battery usage based on your app's needs.

### Sync Interval (Beacon Scan Frequency)

Configure how often the SDK scans for beacons. Lower intervals provide faster detection but consume more battery.

```dart
import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';

// Set scan interval (5-60 seconds)
await BearoundFlutterSdk.setSyncInterval(SyncInterval.time20); // 20 seconds (default)

// Get current interval
final interval = await BearoundFlutterSdk.getSyncInterval();
print('Current interval: ${interval.seconds} seconds');
```

**Available Intervals:**
- `SyncInterval.time5` to `SyncInterval.time60` (5 to 60 seconds)
- **Default: `SyncInterval.time20` (20 seconds)** - Balanced performance and battery

### Backup Size (Failed Beacon Storage)

Configure how many failed beacon detections are stored for retry when API calls fail.

```dart
// Set backup size (5-50 beacons)
await BearoundFlutterSdk.setBackupSize(BackupSize.size40); // 40 beacons (default)

// Get current backup size
final size = await BearoundFlutterSdk.getBackupSize();
print('Backup size: ${size.value} beacons');
```

**Available Sizes:**
- `BackupSize.size5` to `BackupSize.size50` (5 to 50 beacons)
- Default: `BackupSize.size40` (40 beacons)

### Configuration Recommendations

| Scenario | Sync Interval | Backup Size | Use Case |
|----------|--------------|-------------|----------|
| **Real-time tracking** | `time5` - `time10` | `size15` - `size20` | Immediate updates, lower backup needed |
| **Standard monitoring** | `time20` - `time30` (⭐ default) | `size30` - `size40` | Balanced performance and battery |
| **Battery-optimized** | `time40` - `time60` | `size40` - `size50` | Longer intervals, larger backup for reliability |
| **Offline-first apps** | `time30` - `time60` | `size50` | Handle poor network conditions |


### Platform-Specific Notes

- **iOS**: Both settings can be changed at any time (before or after `startScan()`)
- **Android**: 
  - `setSyncInterval()` can be changed dynamically at runtime
  - `setBackupSize()` must be set **before** calling `startScan()`

### Example: Battery-Optimized Configuration

```dart
class BatteryOptimizedScanner {
  Future<void> startScanning() async {
    // Configure for battery optimization
    await BearoundFlutterSdk.setBackupSize(BackupSize.size50);  // Android: set before startScan
    await BearoundFlutterSdk.setSyncInterval(SyncInterval.time60);
    
    // Request permissions
    final granted = await BearoundFlutterSdk.requestPermissions();
    if (!granted) return;
    
    // Start scanning
    await BearoundFlutterSdk.startScan('your-token', debug: false);
  }
}
```

### Example: Real-time Tracking Configuration

```dart
class RealtimeTracker {
  Future<void> startTracking() async {
    // Configure for real-time tracking
    await BearoundFlutterSdk.setBackupSize(BackupSize.size20);  // Android: set before startScan
    await BearoundFlutterSdk.setSyncInterval(SyncInterval.time5);
    
    final granted = await BearoundFlutterSdk.requestPermissions();
    if (!granted) return;
    
    await BearoundFlutterSdk.startScan('your-token', debug: true);
  }
  
  Future<void> adjustForBatteryLevel(int batteryLevel) async {
    // Dynamically adjust based on battery (iOS and Android)
    if (batteryLevel < 20) {
      await BearoundFlutterSdk.setSyncInterval(SyncInterval.time60);
    } else if (batteryLevel < 50) {
      await BearoundFlutterSdk.setSyncInterval(SyncInterval.time30);
    } else {
      await BearoundFlutterSdk.setSyncInterval(SyncInterval.time10);
    }
  }
}
```

### Background Scanning & State Synchronization

When your app supports background scanning, the SDK may continue running even after the app is closed. To properly synchronize the UI state when the app reopens, implement lifecycle management:

```dart
class BackgroundScannerApp extends StatefulWidget {
  @override
  _BackgroundScannerAppState createState() => _BackgroundScannerAppState();
}

class _BackgroundScannerAppState extends State<BackgroundScannerApp>
    with WidgetsBindingObserver {
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncStateWithNative();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App returned to foreground, sync state
      _syncStateWithNative();
    }
  }

  /// Synchronizes UI state with native SDK state
  Future<void> _syncStateWithNative() async {
    final isRunning = await BearoundFlutterSdk.isInitialized();

    if (isRunning && !_isScanning) {
      // SDK is running but UI shows stopped - reconnect
      print('Detected SDK running in background, reconnecting...');

      // Re-register listeners and update state
      await BearoundFlutterSdk.startScan('your-token', debug: true);
      setState(() {
        _isScanning = true;
      });

      print('Reconnection successful: events restored');
    } else if (!isRunning && _isScanning) {
      // SDK stopped but UI shows running - update state
      setState(() {
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Background Scanner'),
        actions: [
          Icon(_isScanning ? Icons.wifi_tethering : Icons.wifi_off),
        ],
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _isScanning ? _stopScanning : _startScanning,
          child: Text(_isScanning ? 'Stop' : 'Start'),
        ),
      ),
    );
  }

  Future<void> _startScanning() async {
    final granted = await BearoundFlutterSdk.requestPermissions();
    if (!granted) return;

    await BearoundFlutterSdk.startScan('your-token', debug: true);
    setState(() => _isScanning = true);
  }

  Future<void> _stopScanning() async {
    await BearoundFlutterSdk.stopScan();
    setState(() => _isScanning = false);
  }
}
```

**Key Benefits:**
- ✅ UI stays in sync with background services
- ✅ Handles app restarts gracefully
- ✅ Automatically reconnects event listeners
- ✅ No initialization errors on app reopen

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

##### `isInitialized()` 🆕

Checks if the SDK is currently initialized and running. Useful for state synchronization when app reopens after being closed.

```dart
static Future<bool> isInitialized()
```

**Returns:** `true` if SDK is initialized and running, `false` otherwise.

**Example:**
```dart
final isRunning = await BearoundFlutterSdk.isInitialized();
if (isRunning) {
  print('SDK is already running in background');
}
```

#### Event Streams 🆕

##### `beaconsStream`

Stream of real-time beacon detection events.

```dart
static Stream<BeaconsDetectedEvent> get beaconsStream
```

**Event Types:**
- `BeaconEventType.ENTER` - Beacon entered range
- `BeaconEventType.EXIT` - Beacon exited range
- `BeaconEventType.FAILED` - Beacon detection failed

**Example:**
```dart
BearoundFlutterSdk.beaconsStream.listen((event) {
  print('Event: ${event.eventType.name}');
  print('Beacons: ${event.beacons.length}');
  for (var beacon in event.beacons) {
    print('  UUID: ${beacon.uuid}, RSSI: ${beacon.rssi}');
  }
});
```

##### `syncStream`

Stream of API synchronization events (success and errors).

```dart
static Stream<BeaconEvent> get syncStream
```

**Event Types:**
- `SyncSuccessEvent` - Sync completed successfully
- `SyncErrorEvent` - Sync failed with error

**Example:**
```dart
BearoundFlutterSdk.syncStream.listen((event) {
  if (event is SyncSuccessEvent) {
    print('Synced ${event.beaconsCount} beacons: ${event.message}');
  } else if (event is SyncErrorEvent) {
    print('Sync error (${event.errorCode}): ${event.errorMessage}');
  }
});
```

##### `regionStream`

Stream of beacon region entry and exit events.

```dart
static Stream<BeaconEvent> get regionStream
```

**Event Types:**
- `BeaconRegionEnterEvent` - Entered a beacon region
- `BeaconRegionExitEvent` - Exited a beacon region

**Example:**
```dart
BearoundFlutterSdk.regionStream.listen((event) {
  if (event is BeaconRegionEnterEvent) {
    print('Entered region: ${event.regionName}');
  } else if (event is BeaconRegionExitEvent) {
    print('Exited region: ${event.regionName}');
  }
});
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
  final int? lastSeen;            // 🆕 Last detection timestamp in milliseconds
}
```

**Properties:**
- `uuid`: Universally unique identifier of the beacon
- `major`: Major value for grouping beacons (e.g., by location)
- `minor`: Minor value for identifying specific beacons
- `rssi`: Received Signal Strength Indicator in dBm (higher = closer)
- `bluetoothName`: Human-readable name of the Bluetooth device
- `bluetoothAddress`: Physical MAC address of the Bluetooth device
- `distanceMeters`: Estimated distance from device to beacon in meters
- `lastSeen`: Unix timestamp (milliseconds) when beacon was last detected

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

## 🔧 Troubleshooting

### iOS: Beacons Not Detected

**Problem:** SDK initializes successfully but no beacons are detected.

**Solution (Fixed in v1.3.1):**
- ✅ Ensure you're using v1.3.1 or later (critical fix for iOS beacon detection)
- ✅ Check that Location permission is set to "Always" (not just "When In Use")
- ✅ Verify Bluetooth is enabled on the device
- ✅ Confirm beacons are broadcasting with UUID: `E25B8D3C-947A-452F-A13F-589CB706D2E5`
- ✅ Test with physical beacons (simulators don't support BLE properly)

**Debugging:**
```dart
// Enable debug mode to see detailed logs
await BearoundFlutterSdk.startScan('your-token', debug: true);

// Check if SDK is initialized
final isRunning = await BearoundFlutterSdk.isInitialized();
print('SDK running: $isRunning');
```

### Android: Permission Issues

**Problem:** App crashes or beacons not detected on Android 12+.

**Solution:**
- ✅ Add all required permissions to `AndroidManifest.xml` (see Platform Setup)
- ✅ Request runtime permissions before starting scan
- ✅ For Android 12+, ensure `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` are granted
- ✅ Add JitPack repository to `settings.gradle.kts`

### State Synchronization Issues

**Problem:** UI shows incorrect state after app reopens from background.

**Solution (Available in v1.1.1+):**
```dart
class MyApp extends StatefulWidget with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncStateWithNative(); // Sync with native SDK state
    }
  }
  
  Future<void> _syncStateWithNative() async {
    final isRunning = await BearoundFlutterSdk.isInitialized();
    // Update UI based on actual SDK state
  }
}
```

### Configuration Not Applied

**Problem:** Scan interval or backup size changes don't take effect.

**Solution:**
- **iOS**: Both settings can be changed at any time
- **Android**: `setBackupSize()` must be called **before** `startScan()`

```dart
// Correct order for Android
await BearoundFlutterSdk.setBackupSize(BackupSize.size40);
await BearoundFlutterSdk.setSyncInterval(SyncInterval.time20);
await BearoundFlutterSdk.startScan('your-token');
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
