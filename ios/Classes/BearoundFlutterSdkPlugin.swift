import BearoundSDK
import CoreBluetooth
import CoreLocation
import Flutter
import UIKit

public class BearoundFlutterSdkPlugin: NSObject, FlutterPlugin, BeAroundSDKDelegate, CLLocationManagerDelegate, CBCentralManagerDelegate {
    private let beaconsStreamHandler = EventStreamHandler()
    private let scanningStreamHandler = EventStreamHandler()
    private let errorStreamHandler = EventStreamHandler()
    private let syncLifecycleStreamHandler = EventStreamHandler()
    private let backgroundDetectionStreamHandler = EventStreamHandler()
    private let beaconRegionStreamHandler = EventStreamHandler()
    private let activeScanStreamHandler = EventStreamHandler()
    // v2.5 — Bluetooth "two eyes" (iOS-only).
    private let bluetoothZoneStreamHandler = EventStreamHandler()
    private let bluetoothScanModeStreamHandler = EventStreamHandler()
    // Bluetooth adapter state (both platforms).
    private let bluetoothStateStreamHandler = EventStreamHandler()

    /// Tracks if Flutter explicitly started scanning.
    private var isActiveScan = false

    /// Tracks whether `configure()` has been called from Flutter. Mirrors the
    /// RN bridge — the native SDK keeps configuration state private, so the
    /// bridge tracks it locally.
    // TODO(cleanup): delegate to native instead of reimplementing
    private var configured = false

    /// CLLocationManager for requesting permissions.
    // TODO(cleanup): delegate to native instead of reimplementing
    private var permissionManager: CLLocationManager?
    private var permissionResult: FlutterResult?

    /// Bluetooth eye state — mirrors the iOS native demo's CBCentralManager status.
    // TODO(cleanup): delegate to native instead of reimplementing
    private var btManager: CBCentralManager?
    private var btState: String = "unknown"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "bearound_flutter_sdk",
            binaryMessenger: registrar.messenger()
        )

        let instance = BearoundFlutterSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        let beaconsChannel = FlutterEventChannel(
            name: "bearound_flutter_sdk/beacons",
            binaryMessenger: registrar.messenger()
        )
        beaconsChannel.setStreamHandler(instance.beaconsStreamHandler)

        let scanningChannel = FlutterEventChannel(
            name: "bearound_flutter_sdk/scanning",
            binaryMessenger: registrar.messenger()
        )
        scanningChannel.setStreamHandler(instance.scanningStreamHandler)

        let errorChannel = FlutterEventChannel(
            name: "bearound_flutter_sdk/errors",
            binaryMessenger: registrar.messenger()
        )
        errorChannel.setStreamHandler(instance.errorStreamHandler)

        let syncLifecycleChannel = FlutterEventChannel(
            name: "bearound_flutter_sdk/sync_lifecycle",
            binaryMessenger: registrar.messenger()
        )
        syncLifecycleChannel.setStreamHandler(instance.syncLifecycleStreamHandler)

        let backgroundDetectionChannel = FlutterEventChannel(
            name: "bearound_flutter_sdk/background_detection",
            binaryMessenger: registrar.messenger()
        )
        backgroundDetectionChannel.setStreamHandler(instance.backgroundDetectionStreamHandler)

        let beaconRegionChannel = FlutterEventChannel(
            name: "bearound_flutter_sdk/beacon_region",
            binaryMessenger: registrar.messenger()
        )
        beaconRegionChannel.setStreamHandler(instance.beaconRegionStreamHandler)

        let activeScanChannel = FlutterEventChannel(
            name: "bearound_flutter_sdk/active_scan",
            binaryMessenger: registrar.messenger()
        )
        activeScanChannel.setStreamHandler(instance.activeScanStreamHandler)

        let bluetoothZoneChannel = FlutterEventChannel(
            name: "bearound_flutter_sdk/bluetooth_zone",
            binaryMessenger: registrar.messenger()
        )
        bluetoothZoneChannel.setStreamHandler(instance.bluetoothZoneStreamHandler)

        let bluetoothScanModeChannel = FlutterEventChannel(
            name: "bearound_flutter_sdk/bluetooth_scan_mode",
            binaryMessenger: registrar.messenger()
        )
        bluetoothScanModeChannel.setStreamHandler(instance.bluetoothScanModeStreamHandler)

        let bluetoothStateChannel = FlutterEventChannel(
            name: "bearound_flutter_sdk/bluetooth_state",
            binaryMessenger: registrar.messenger()
        )
        bluetoothStateChannel.setStreamHandler(instance.bluetoothStateStreamHandler)

        // Register as delegate
        BeAroundSDK.shared.delegate = instance

        // Sync isActiveScan with SDK's current state (handles auto-restored scanning).
        instance.isActiveScan = BeAroundSDK.shared.isScanning
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        // MARK: - Configuration
        case "configure":
            let args = call.arguments as? [String: Any]
            guard
                let businessToken = (args?["businessToken"] as? String)?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                !businessToken.isEmpty
            else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "businessToken is required",
                        details: nil
                    )
                )
                return
            }

            let precisionRaw = (args?["scanPrecision"] as? String) ?? "high"
            let maxQueuedValue = (args?["maxQueuedPayloads"] as? NSNumber)?.intValue ?? 100

            let scanPrecision = mapToScanPrecision(precisionRaw)
            let maxQueuedPayloads = mapToMaxQueuedPayloads(maxQueuedValue)

            let wasScanning = BeAroundSDK.shared.isScanning
            if wasScanning {
                BeAroundSDK.shared.stopScanning()
            }

            BeAroundSDK.shared.configure(
                businessToken: businessToken,
                scanPrecision: scanPrecision,
                maxQueuedPayloads: maxQueuedPayloads,
                technology: "flutter"
            )
            BeAroundSDK.shared.delegate = self
            configured = true

            if wasScanning {
                let appState = UIApplication.shared.applicationState
                if appState == .active {
                    NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
                }
                BeAroundSDK.shared.startScanning()
                isActiveScan = true
            } else {
                isActiveScan = false
            }

            result(nil)

        // MARK: - Scanning
        case "startScanning":
            isActiveScan = true
            BeAroundSDK.shared.delegate = self
            let appState = UIApplication.shared.applicationState
            if appState == .active {
                NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
            }
            BeAroundSDK.shared.startScanning()
            result(nil)

        case "stopScanning":
            isActiveScan = false
            BeAroundSDK.shared.stopScanning()
            DispatchQueue.main.async { [weak self] in
                self?.beaconsStreamHandler.eventSink?(["beacons": []])
                self?.scanningStreamHandler.eventSink?(["isScanning": false])
            }
            result(nil)

        case "isScanning":
            result(BeAroundSDK.shared.isScanning)

        // MARK: - User properties
        case "setUserProperties":
            guard let args = call.arguments as? [String: Any] else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENTS",
                        message: "Arguments are invalid",
                        details: nil
                    )
                )
                return
            }
            let rawCustom = args["customProperties"] as? [String: Any] ?? [:]
            var custom: [String: String] = [:]
            rawCustom.forEach { key, value in
                if let stringValue = value as? String {
                    custom[key] = stringValue
                }
            }
            let properties = UserProperties(
                internalId: args["internalId"] as? String,
                email: args["email"] as? String,
                name: args["name"] as? String,
                customProperties: custom
            )
            BeAroundSDK.shared.setUserProperties(properties)
            result(nil)

        case "clearUserProperties":
            BeAroundSDK.shared.clearUserProperties()
            result(nil)

        // MARK: - Push token
        case "setPushToken":
            guard let token = (call.arguments as? [String: Any])?["token"] as? String else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "token is required",
                        details: nil
                    )
                )
                return
            }
            BeAroundSDK.shared.setPushToken(token)
            result(nil)

        // MARK: - Diagnostic getters
        case "getSdkVersion":
            result(BeAroundSDK.version)
        case "getCurrentScanPrecision":
            result(BeAroundSDK.shared.currentScanPrecision?.rawValue ?? "")
        case "getBleDiagnosticInfo":
            result(BeAroundSDK.shared.bleDiagnosticInfo)
        case "getPendingBatchCount":
            result(BeAroundSDK.shared.pendingBatchCount)
        case "isConfigured":
            result(configured)
        case "isLocationAvailable":
            result(BeAroundSDK.isLocationAvailable())
        case "getAuthorizationStatus":
            result(mapAuthorizationStatus(BeAroundSDK.authorizationStatus()))
        case "getBluetoothState":
            ensureBluetoothManager()
            result(btState)

        // MARK: - Permissions
        case "requestPermissions":
            requestLocationPermissions(result: result)
        case "checkPermissions":
            result(checkLocationPermissions())
        case "requestLocationAuthorization":
            let raw = (call.arguments as? String)?.lowercased() ?? "always"
            let level: BeAroundLocationAuthorization = raw == "wheninuse" ? .whenInUse : .always
            DispatchQueue.main.async {
                BeAroundSDK.shared.requestLocationAuthorization(level)
            }
            result(nil)

        // Push/notifications são app-level agora. O SDK nativo removeu a API de
        // notificações da biblioteca, então o bridge não a forwarda mais.

        // MARK: - Persisted log (delegated to the SDK so both iOS and Android share the same store)
        case "getPersistedLog":
            result(BeAroundSDK.shared.getDetectionLogJson())
        case "clearPersistedLog":
            BeAroundSDK.shared.clearDetectionLog()
            result(nil)

        // MARK: - Foreground service scanning (Android-only) — no-ops on iOS
        case "enableForegroundScanning",
             "disableForegroundScanning",
             "setForegroundNotificationContent":
            result(nil)
        case "isForegroundScanningEnabled":
            result(false)

        // MARK: - Backward-compat
        // TODO(cleanup): removable no-op shim — the native SDK no longer has a
        // separate Bluetooth-scanning toggle; kept for older Dart callers.
        case "setBluetoothScanning":
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Permission Handling

    private func requestLocationPermissions(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                result(false)
                return
            }

            guard CLLocationManager.locationServicesEnabled() else {
                result(false)
                return
            }

            DispatchQueue.main.async {
                self.permissionResult = result
                let manager = CLLocationManager()
                self.permissionManager = manager
                manager.delegate = self

                let status: CLAuthorizationStatus
                if #available(iOS 14.0, *) {
                    status = manager.authorizationStatus
                } else {
                    status = CLLocationManager.authorizationStatus()
                }

                switch status {
                case .authorizedAlways, .authorizedWhenInUse:
                    self.permissionResult?(true)
                    self.permissionResult = nil
                    self.permissionManager?.delegate = nil
                    self.permissionManager = nil
                case .notDetermined:
                    manager.requestAlwaysAuthorization()
                case .denied, .restricted:
                    self.permissionResult?(false)
                    self.permissionResult = nil
                    self.permissionManager?.delegate = nil
                    self.permissionManager = nil
                @unknown default:
                    self.permissionResult?(false)
                    self.permissionResult = nil
                    self.permissionManager?.delegate = nil
                    self.permissionManager = nil
                }
            }
        }
    }

    private func checkLocationPermissions() -> Bool {
        let status = currentAuthorizationStatus()
        return status == .authorizedAlways || status == .authorizedWhenInUse
    }

    private func currentAuthorizationStatus() -> CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return CLLocationManager().authorizationStatus
        } else {
            return CLLocationManager.authorizationStatus()
        }
    }

    private func mapAuthorizationStatus(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways: return "always"
        case .authorizedWhenInUse: return "whenInUse"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default: return "unknown"
        }
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if #available(iOS 14.0, *) {
            handleAuthorizationChange(manager.authorizationStatus)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleAuthorizationChange(status)
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        guard status != .notDetermined else { return }

        let granted = status == .authorizedAlways || status == .authorizedWhenInUse
        permissionResult?(granted)
        permissionResult = nil
        permissionManager?.delegate = nil
        permissionManager = nil
    }

    // MARK: - CBCentralManagerDelegate (Bluetooth eye state)

    private func ensureBluetoothManager() {
        if btManager != nil { return }
        let make = {
            self.btManager = CBCentralManager(
                delegate: self,
                queue: nil,
                options: [CBCentralManagerOptionShowPowerAlertKey: false]
            )
        }
        if Thread.isMainThread {
            make()
        } else {
            DispatchQueue.main.sync { make() }
        }
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        btState = mapBluetoothState(central.state)
        DispatchQueue.main.async { [weak self] in
            self?.bluetoothStateStreamHandler.eventSink?(["state": self?.btState ?? "unknown"])
        }
    }

    private func mapBluetoothState(_ state: CBManagerState) -> String {
        switch state {
        case .poweredOn: return "poweredOn"
        case .poweredOff: return "poweredOff"
        case .unauthorized: return "unauthorized"
        case .unsupported: return "unsupported"
        case .resetting: return "resetting"
        case .unknown: return "unknown"
        @unknown default: return "unknown"
        }
    }

    // MARK: - BeAroundSDKDelegate

    public func didUpdateBeacons(_ beacons: [Beacon]) {
        let mapped = beacons.map { mapBeacon($0) }
        DispatchQueue.main.async { [weak self] in
            self?.beaconsStreamHandler.eventSink?(["beacons": mapped])
        }
        if !beacons.isEmpty {
            // Notification posting was removed (push is app-level now). Only the
            // local detection log is recorded here.
            // TODO(cleanup): delegate to native instead of reimplementing
            PersistentLog.append(
                type: "Beacons atualizados",
                detail: "\(beacons.count) beacon(s) detectado(s)"
            )
        }
    }

    private func mapBeacon(_ beacon: Beacon) -> [String: Any] {
        var payload: [String: Any] = [
            "uuid": beacon.uuid.uuidString,
            "major": beacon.major,
            "minor": beacon.minor,
            "rssi": beacon.rssi,
            "proximity": mapProximity(beacon.proximity),
            "accuracy": beacon.accuracy,
            "timestamp": Int(beacon.timestamp.timeIntervalSince1970 * 1000),
            // iOS-only fields for the two-eyes model.
            "discoverySources": beacon.discoverySources.map { mapDiscoverySource($0) },
            "alreadySynced": beacon.alreadySynced,
        ]
        if let metadata = beacon.metadata {
            payload["metadata"] = mapMetadata(metadata)
        }
        if let txPower = beacon.txPower {
            payload["txPower"] = txPower
        }
        if let syncedAt = beacon.syncedAt {
            payload["syncedAt"] = Int(syncedAt.timeIntervalSince1970 * 1000)
        }
        return payload
    }

    private func mapDiscoverySource(_ source: BeaconDiscoverySource) -> String {
        switch source {
        case .serviceUUID: return "serviceUUID"
        case .name: return "name"
        case .coreLocation: return "coreLocation"
        }
    }

    public func didFailWithError(_ error: Error) {
        let payload: [String: Any] = ["message": error.localizedDescription]
        DispatchQueue.main.async { [weak self] in
            self?.errorStreamHandler.eventSink?(payload)
        }
        PersistentLog.append(type: "Erro SDK", detail: error.localizedDescription)
    }

    public func didChangeScanning(isScanning: Bool) {
        self.isActiveScan = isScanning
        DispatchQueue.main.async { [weak self] in
            self?.scanningStreamHandler.eventSink?(["isScanning": isScanning])
        }
    }

    public func willStartSync(beaconCount: Int) {
        let payload: [String: Any] = ["type": "started", "beaconCount": beaconCount]
        DispatchQueue.main.async { [weak self] in
            self?.syncLifecycleStreamHandler.eventSink?(payload)
        }
        // No push for "started" — the SDK only pushes on completion.
    }

    public func didCompleteSync(beaconCount: Int, success: Bool, error: Error?) {
        let payload: [String: Any] = [
            "type": "completed",
            "beaconCount": beaconCount,
            "success": success,
            "error": error?.localizedDescription as Any
        ]
        DispatchQueue.main.async { [weak self] in
            self?.syncLifecycleStreamHandler.eventSink?(payload)
        }
        // Push + persistent log are handled by the SDK's SDKNotifier — no duplication here.
    }

    // v3.0: native signature is (beacons: [Beacon]).
    public func didDetectBeaconInBackground(beacons: [Beacon]) {
        let payload: [String: Any] = ["beaconCount": beacons.count]
        DispatchQueue.main.async { [weak self] in
            self?.backgroundDetectionStreamHandler.eventSink?(payload)
        }
        // SDK already pushed + logged via SDKNotifier.onBackgroundDetection.
    }

    public func didEnterBeaconRegion() {
        DispatchQueue.main.async { [weak self] in
            self?.beaconRegionStreamHandler.eventSink?(["type": "enter"])
        }
        // SDK already pushed + logged via SDKNotifier.onEnterRegion.
    }

    public func didExitBeaconRegion() {
        DispatchQueue.main.async { [weak self] in
            self?.beaconRegionStreamHandler.eventSink?(["type": "exit"])
        }
        // SDK already logged via SDKNotifier.onExitRegion (no push by default).
    }

    public func didChangeActiveScanState(isActive: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.activeScanStreamHandler.eventSink?(["isActive": isActive])
        }
    }

    public func didEnterBluetoothZone() {
        DispatchQueue.main.async { [weak self] in
            self?.bluetoothZoneStreamHandler.eventSink?(["type": "enter"])
        }
        // Bridge only forwards the zone event; push is app-level now.
    }

    public func didExitBluetoothZone() {
        DispatchQueue.main.async { [weak self] in
            self?.bluetoothZoneStreamHandler.eventSink?(["type": "exit"])
        }
        // Log-only by default on exit.
    }

    public func didChangeBluetoothScanMode(_ mode: BluetoothScanMode, nextIdleScanAt: Date?) {
        var payload: [String: Any] = ["mode": mode.rawValue]
        if let next = nextIdleScanAt {
            payload["nextIdleScanAt"] = Int(next.timeIntervalSince1970 * 1000)
        }
        DispatchQueue.main.async { [weak self] in
            self?.bluetoothScanModeStreamHandler.eventSink?(payload)
        }
    }

    // MARK: - Mapping Helpers

    private func mapProximity(_ proximity: BeaconProximity) -> String {
        switch proximity {
        case .immediate: return "immediate"
        case .near: return "near"
        case .far: return "far"
        case .bt: return "bt"
        case .unknown: return "unknown"
        }
    }

    private func mapMetadata(_ metadata: BeaconMetadata) -> [String: Any] {
        var payload: [String: Any] = [
            "firmwareVersion": metadata.firmwareVersion,
            "batteryLevel": metadata.batteryLevel,
            "movements": metadata.movements,
            "temperature": metadata.temperature,
        ]
        if let txPower = metadata.txPower {
            payload["txPower"] = txPower
        }
        if let rssiFromBLE = metadata.rssiFromBLE {
            payload["rssiFromBLE"] = rssiFromBLE
        }
        if let isConnectable = metadata.isConnectable {
            payload["isConnectable"] = isConnectable
        }
        return payload
    }

    private func mapToScanPrecision(_ value: String) -> ScanPrecision {
        switch value.lowercased() {
        case "high": return .high
        case "medium": return .medium
        case "low": return .low
        default: return .high
        }
    }

    private func mapToMaxQueuedPayloads(_ value: Int) -> MaxQueuedPayloads {
        switch value {
        case 50: return .small
        case 100: return .medium
        case 200: return .large
        case 500: return .xlarge
        default: return .medium
        }
    }
}

// MARK: - Persistent log (UserDefaults JSON)
// TODO(cleanup): delegate to native instead of reimplementing — the method
// channel already reads the native detection log; this local store is only
// written to and should be retired once native exposes a write hook.

private enum PersistentLog {
    private static let storageKey = "bearound_flutter_log"
    private static let maxEntries = 500

    static func append(type: String, detail: String) {
        let defaults = UserDefaults.standard
        var arr = (defaults.array(forKey: storageKey) as? [[String: Any]]) ?? []
        let entry: [String: Any] = [
            "id": "\(Date().timeIntervalSince1970)-\(Int.random(in: 0...9999))",
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "state": currentStateTag(),
            "type": type,
            "detail": detail,
        ]
        arr.insert(entry, at: 0)
        if arr.count > maxEntries { arr = Array(arr.prefix(maxEntries)) }
        defaults.set(arr, forKey: storageKey)
    }

    static func readJSON() -> String {
        let arr = (UserDefaults.standard.array(forKey: storageKey) as? [[String: Any]]) ?? []
        guard
            let data = try? JSONSerialization.data(withJSONObject: arr),
            let json = String(data: data, encoding: .utf8)
        else { return "[]" }
        return json
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private static func currentStateTag() -> String {
        let map: (UIApplication.State) -> String = { state in
            switch state {
            case .active: return "foreground"
            case .background: return "background"
            case .inactive: return "closed"
            @unknown default: return "closed"
            }
        }
        if Thread.isMainThread { return map(UIApplication.shared.applicationState) }
        var tag = "closed"
        DispatchQueue.main.sync { tag = map(UIApplication.shared.applicationState) }
        return tag
    }
}

// MARK: - Event Stream Handler

private class EventStreamHandler: NSObject, FlutterStreamHandler {
    var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
