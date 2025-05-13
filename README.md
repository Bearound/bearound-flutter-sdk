# 🐻 Bearound SDKs Documentation

Official SDKs for integrating Bearound's secure BLE beacon detection and indoor location technology.

## 🟡 bearound-flutter-sdk

Flutter plugin with unified Dart APIs for BLE beacon detection.

### 📦 Installation

Add to pubspec.yaml:

```yaml
dependencies:
  bearound_flutter_sdk: ^1.0.0
```

Then run:

```bash
flutter pub get
```

### ⚙️ Required Permissions

Android:
- android.permission.BLUETOOTH
- android.permission.ACCESS_FINE_LOCATION
- android.permission.BLUETOOTH_SCAN (API 31+)

iOS:
- NSBluetoothAlwaysUsageDescription
- NSLocationWhenInUseUsageDescription

### 🚀 Features

- BLE beacon scanning
- Real-time Dart stream of beacon events
- Unified cross-platform implementation
- Null-safety

### 🛠️ Usage

```dart
import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart'

BearoundFlutterSdk.startScan()

BearoundFlutterSdk.beaconStream.listen((beacon) {
  print("Beacon ${beacon.id} at ${beacon.distance}m")
})
```

### 📄 License

MIT © Bearound
