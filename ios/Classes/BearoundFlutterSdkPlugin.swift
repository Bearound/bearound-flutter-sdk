import BearoundSDK
import CoreLocation
import Flutter
import UIKit

public class BearoundFlutterSdkPlugin: NSObject, FlutterPlugin, BeAroundSDKDelegate, CLLocationManagerDelegate {
    private let beaconsStreamHandler = EventStreamHandler()
    private let scanningStreamHandler = EventStreamHandler()
    private let errorStreamHandler = EventStreamHandler()
    private let syncLifecycleStreamHandler = EventStreamHandler()
    private let backgroundDetectionStreamHandler = EventStreamHandler()
    
    /// Tracks if Flutter explicitly started scanning
    private var isActiveScan = false
    
    /// CLLocationManager for requesting permissions (like React Native)
    private var permissionManager: CLLocationManager?
    private var permissionResult: FlutterResult?

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

        // Register as delegate
        BeAroundSDK.shared.delegate = instance
        
        // Sync isActiveScan with SDK's current state (handles auto-restored scanning)
        instance.isActiveScan = BeAroundSDK.shared.isScanning
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
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

            let foregroundSeconds = (args?["foregroundScanInterval"] as? NSNumber)?.intValue ?? 15
            let backgroundSeconds = (args?["backgroundScanInterval"] as? NSNumber)?.intValue ?? 30
            let maxQueuedValue = (args?["maxQueuedPayloads"] as? NSNumber)?.intValue ?? 100

            // Map Int values to native iOS enums
            let foregroundInterval = mapToForegroundScanInterval(foregroundSeconds)
            let backgroundInterval = mapToBackgroundScanInterval(backgroundSeconds)
            let maxQueuedPayloads = mapToMaxQueuedPayloads(maxQueuedValue)

            // FIX: If SDK was already scanning (auto-restored), stop it first
            // so the new configuration takes effect
            let wasScanning = BeAroundSDK.shared.isScanning
            if wasScanning {
                BeAroundSDK.shared.stopScanning()
            }

            BeAroundSDK.shared.configure(
                businessToken: businessToken,
                foregroundScanInterval: foregroundInterval,
                backgroundScanInterval: backgroundInterval,
                maxQueuedPayloads: maxQueuedPayloads
            )
            BeAroundSDK.shared.delegate = self
            
            // If SDK was scanning before, restart with new configuration
            if wasScanning {
                // Force correct foreground state
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

        case "startScanning":
            isActiveScan = true
            BeAroundSDK.shared.delegate = self
            
            // WORKAROUND: Force SDK to recognize correct foreground state
            // This ensures BeaconManager.isInForeground is correctly set
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

        case "setBluetoothScanning":
            // v2.2.1: Bluetooth scanning is now automatic - method deprecated
            result(nil)

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

        case "requestPermissions":
            requestLocationPermissions(result: result)

        case "checkPermissions":
            let granted = checkLocationPermissions()
            result(granted)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Permission Handling (same as React Native)
    
    /// Request location permissions using CLLocationManager directly
    /// This calls requestAlwaysAuthorization() like the iOS native and React Native SDKs
    private func requestLocationPermissions(result: @escaping FlutterResult) {
        // Check location services on a background queue to avoid blocking the main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                result(false)
                return
            }
            
            guard CLLocationManager.locationServicesEnabled() else {
                result(false)
                return
            }
            
            // Now move to main queue for UI-related location manager setup
            DispatchQueue.main.async {
                // Use a CLLocationManager instance and rely on delegate callback to avoid synchronous status checks on main thread
                self.permissionResult = result
                let manager = CLLocationManager()
                self.permissionManager = manager
                manager.delegate = self

                // Determine current status using manager (iOS 14+) or class method for earlier versions
                let status: CLAuthorizationStatus
                if #available(iOS 14.0, *) {
                    status = manager.authorizationStatus
                } else {
                    status = CLLocationManager.authorizationStatus()
                }

                switch status {
                case .authorizedAlways, .authorizedWhenInUse:
                    // Already authorized
                    self.permissionResult?(true)
                    self.permissionResult = nil
                    self.permissionManager?.delegate = nil
                    self.permissionManager = nil
                case .notDetermined:
                    // Request "Always" authorization; result will be delivered via delegate
                    manager.requestAlwaysAuthorization()
                case .denied, .restricted:
                    // Cannot request again; return false
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
    
    /// Check current location permission status
    private func checkLocationPermissions() -> Bool {
        let status = currentAuthorizationStatus()
        return status == .authorizedAlways || status == .authorizedWhenInUse
    }
    
    /// Get current authorization status
    private func currentAuthorizationStatus() -> CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return CLLocationManager().authorizationStatus
        } else {
            return CLLocationManager.authorizationStatus()
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

    // MARK: - BeAroundSDKDelegate

    public func didUpdateBeacons(_ beacons: [Beacon]) {
        let mapped = beacons.map { beacon -> [String: Any] in
            var payload: [String: Any] = [
                "uuid": beacon.uuid.uuidString,
                "major": beacon.major,
                "minor": beacon.minor,
                "rssi": beacon.rssi,
                "proximity": mapProximity(beacon.proximity),
                "accuracy": beacon.accuracy,
                "timestamp": Int(beacon.timestamp.timeIntervalSince1970 * 1000),
            ]

            if let metadata = beacon.metadata {
                payload["metadata"] = mapMetadata(metadata)
            }
            if let txPower = beacon.txPower {
                payload["txPower"] = txPower
            }

            return payload
        }

        DispatchQueue.main.async { [weak self] in
            self?.beaconsStreamHandler.eventSink?(["beacons": mapped])
        }
    }

    public func didFailWithError(_ error: Error) {
        // FIX: Always forward errors to Flutter
        let payload: [String: Any] = [
            "message": error.localizedDescription
        ]
        DispatchQueue.main.async { [weak self] in
            self?.errorStreamHandler.eventSink?(payload)
        }
    }

    public func didChangeScanning(isScanning: Bool) {
        self.isActiveScan = isScanning
        
        DispatchQueue.main.async { [weak self] in
            self?.scanningStreamHandler.eventSink?(["isScanning": isScanning])
        }
    }

    public func willStartSync(beaconCount: Int) {
        let payload: [String: Any] = [
            "type": "started",
            "beaconCount": beaconCount
        ]
        DispatchQueue.main.async { [weak self] in
            self?.syncLifecycleStreamHandler.eventSink?(payload)
        }
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
    }
    
    public func didDetectBeaconInBackground(beaconCount: Int) {
        let payload: [String: Any] = [
            "beaconCount": beaconCount
        ]
        DispatchQueue.main.async { [weak self] in
            self?.backgroundDetectionStreamHandler.eventSink?(payload)
        }
    }

    // MARK: - Mapping Helpers

    private func mapProximity(_ proximity: CLProximity) -> String {
        switch proximity {
        case .immediate:
            return "immediate"
        case .near:
            return "near"
        case .far:
            return "far"
        case .unknown:
            return "unknown"
        @unknown default:
            return "unknown"
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

    private func mapToForegroundScanInterval(_ seconds: Int) -> ForegroundScanInterval {
        switch seconds {
        case 5: return .seconds5
        case 10: return .seconds10
        case 15: return .seconds15
        case 20: return .seconds20
        case 25: return .seconds25
        case 30: return .seconds30
        case 35: return .seconds35
        case 40: return .seconds40
        case 45: return .seconds45
        case 50: return .seconds50
        case 55: return .seconds55
        case 60: return .seconds60
        default: return .seconds15  // Default fallback
        }
    }

    private func mapToBackgroundScanInterval(_ seconds: Int) -> BackgroundScanInterval {
        switch seconds {
        case 15: return .seconds15
        case 30: return .seconds30
        case 60: return .seconds60
        case 90: return .seconds90
        case 120: return .seconds120
        default: return .seconds30  // Default fallback
        }
    }

    private func mapToMaxQueuedPayloads(_ value: Int) -> MaxQueuedPayloads {
        switch value {
        case 50: return .small
        case 100: return .medium
        case 200: return .large
        case 500: return .xlarge
        default: return .medium  // Default fallback
        }
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
