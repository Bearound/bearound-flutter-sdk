# 🐻 Bearound SDKs Documentation

Official SDKs for integrating Bearound's secure BLE beacon detection and indoor location technology.

---

## 🟡 bearound-flutter-sdk

Flutter plugin with unified Dart APIs for BLE beacon detection.

### 📦 Installation

Add to **pubspec.yaml**:

```yaml
dependencies:
  bearound_flutter_sdk: ^1.0.0
```

Then run:

```bash
flutter pub get
```

---

## ⚙️ Requirements

- **Minimum SDK**: 21 (Android 5.0 Lollipop)
- **Minimun** iOS 13
- **Bluetooth LE** must be enabled on the device

### ⚙️ Required Permissions

**Android** (add to `android/app/src/main/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" /> <!-- API 31+ -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

**iOS** (add to **Info.plist**):

```xml
<key>UIBackgroundModes</key>
<array>
  <string>bluetooth-central</string>
  <string>location</string>
</array>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Usamos sua localização para detectar beacons mesmo em segundo plano.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Precisamos da sua localização para identificar beacons próximos.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Precisamos da sua localização para identificar beacons próximos mesmo em segundo plano.</string>
<key>NSUserTrackingUsageDescription</key>
<string>Precisamos de permissão para usar o IDFA em iOS 14+.</string>
```

> **Nota:** Requer iOS 15.0 ou superior devido à APIs de rastreamento e Bluetooth em background.

---

### 🚀 Features

* BLE beacon scanning
* Real-time Dart stream of beacon events (`List<Beacon>`)
* Unified cross-platform implementation
* Null-safety
* Background scanning (Android foreground service, iOS background modes)

---

### 🛠️ Usage

```dart
import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BeaconHomePage(),
    );
  }
}

class BeaconHomePage extends StatefulWidget {
  @override
  _BeaconHomePageState createState() => _BeaconHomePageState();
}

class _BeaconHomePageState extends State<BeaconHomePage> {
  StreamSubscription<List<Beacon>>? _sub;

  @override
  void initState() {
    super.initState();
    // Solicita permissões primeiro
    BearoundFlutterSdk.requestPermissions().then((granted) {
      if (granted) _startScan();
    });
  }

  void _startScan() {
    BearoundFlutterSdk.startScan(debug: true);
    _sub = BearoundFlutterSdk.beaconStream.listen((beacons) {
      beacons.forEach((b) {
        print('UUID: ${b.uuid}, RSSI: ${b.rssi}, Dist: \${b.distanceMeters}m');
      });
    });
  }

  void _stopScan() {
    _sub?.cancel();
    BearoundFlutterSdk.stopScan();
  }

  @override
  void dispose() {
    _stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bearound Flutter SDK Example')),
      body: Center(child: Text('Aguardando beacons...')),
    );
  }
}
```

---

### 📄 License

MIT © Bearound
