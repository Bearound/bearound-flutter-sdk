import Flutter
import UIKit
import BearoundSDK

public class BearoundFlutterSdkPlugin: NSObject, FlutterPlugin {
    private var detector: Bearound?

    // Event channels
    private var beaconsEventChannel: FlutterEventChannel?
    private var syncEventChannel: FlutterEventChannel?
    private var regionEventChannel: FlutterEventChannel?

    // Stream handlers
    private var beaconsStreamHandler: BeaconsStreamHandler?
    private var syncStreamHandler: SyncStreamHandler?
    private var regionStreamHandler: RegionStreamHandler?

    // Listener implementations
    private var beaconListener: BeaconListenerImpl?
    private var syncListener: SyncListenerImpl?
    private var regionListener: RegionListenerImpl?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "bearound_flutter_sdk", binaryMessenger: registrar.messenger())
        let instance = BearoundFlutterSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Setup event channels
        instance.setupEventChannels(with: registrar)
    }

    private func setupEventChannels(with registrar: FlutterPluginRegistrar) {
        // Beacons event channel
        beaconsStreamHandler = BeaconsStreamHandler()
        beaconsEventChannel = FlutterEventChannel(
            name: "bearound_flutter_sdk/beacons",
            binaryMessenger: registrar.messenger()
        )
        beaconsEventChannel?.setStreamHandler(beaconsStreamHandler)

        // Sync event channel
        syncStreamHandler = SyncStreamHandler()
        syncEventChannel = FlutterEventChannel(
            name: "bearound_flutter_sdk/sync",
            binaryMessenger: registrar.messenger()
        )
        syncEventChannel?.setStreamHandler(syncStreamHandler)

        // Region event channel
        regionStreamHandler = RegionStreamHandler()
        regionEventChannel = FlutterEventChannel(
            name: "bearound_flutter_sdk/region",
            binaryMessenger: registrar.messenger()
        )
        regionEventChannel?.setStreamHandler(regionStreamHandler)
    }

    @MainActor public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments are invalid", details: nil))
                return
            }
            let clientToken = args["clientToken"] as? String ?? ""
            guard !clientToken.isEmpty else {
                result(FlutterError(code: "INVALID_TOKEN", message: "Client token cannot be empty", details: nil))
                return
            }
            let isDebugEnable = args["debug"] as? Bool ?? false

            detector = Bearound.configure(clientToken: clientToken, isDebugEnable: isDebugEnable)
            
            guard let detector = detector else {
                result(FlutterError(code: "INIT_ERROR", message: "Failed to create Bearound instance", details: nil))
                return
            }

            // Setup listeners BEFORE requesting permissions
            beaconListener = BeaconListenerImpl(streamHandler: beaconsStreamHandler)
            syncListener = SyncListenerImpl(streamHandler: syncStreamHandler)
            regionListener = RegionListenerImpl(streamHandler: regionStreamHandler)

            if let beaconListener = beaconListener {
                detector.addBeaconListener(beaconListener)
            }
            if let syncListener = syncListener {
                detector.addSyncListener(syncListener)
            }
            if let regionListener = regionListener {
                detector.addRegionListener(regionListener)
            }
            
            detector.startServices()
            result(nil)

        case "stop":
            if let beaconListener = beaconListener {
                detector?.removeBeaconListener(beaconListener)
            }
            if let syncListener = syncListener {
                detector?.removeSyncListener(syncListener)
            }
            if let regionListener = regionListener {
                detector?.removeRegionListener(regionListener)
            }

            detector?.stopServices()
            detector = nil
            beaconListener = nil
            syncListener = nil
            regionListener = nil
            result(nil)

        case "isInitialized":
            let isInitialized = detector != nil
            result(isInitialized)

        case "setSyncInterval":
            guard let args = call.arguments as? [String: Any],
                  let intervalName = args["interval"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid interval argument", details: nil))
                return
            }
            if let interval = mapIntervalToNative(intervalName) {
                detector?.setSyncInterval(interval)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_INTERVAL", message: "Invalid interval value: \(intervalName)", details: nil))
            }

        case "setBackupSize":
            guard let args = call.arguments as? [String: Any],
                  let sizeName = args["size"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid size argument", details: nil))
                return
            }
            if let size = mapSizeToNative(sizeName) {
                detector?.setBackupSize(size)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_SIZE", message: "Invalid size value: \(sizeName)", details: nil))
            }

        case "getSyncInterval":
            if let interval = detector?.getSyncInterval() {
                let intervalName = mapIntervalFromNative(interval)
                result(intervalName)
            } else {
                result("time20")
            }

        case "getBackupSize":
            if let size = detector?.getBackupSize() {
                let sizeName = mapSizeFromNative(size)
                result(sizeName)
            } else {
                result("size40")
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Configuration Mapping Methods

    private func mapIntervalToNative(_ intervalName: String) -> SyncInterval? {
        switch intervalName {
        case "time5": return .time5
        case "time10": return .time10
        case "time15": return .time15
        case "time20": return .time20
        case "time25": return .time25
        case "time30": return .time30
        case "time35": return .time35
        case "time40": return .time40
        case "time45": return .time45
        case "time50": return .time50
        case "time55": return .time55
        case "time60": return .time60
        default: return nil
        }
    }

    private func mapSizeToNative(_ sizeName: String) -> BackupSize? {
        switch sizeName {
        case "size5": return .size5
        case "size10": return .size10
        case "size15": return .size15
        case "size20": return .size20
        case "size25": return .size25
        case "size30": return .size30
        case "size35": return .size35
        case "size40": return .size40
        case "size45": return .size45
        case "size50": return .size50
        default: return nil
        }
    }

    private func mapIntervalFromNative(_ interval: SyncInterval) -> String {
        switch interval {
        case .time5: return "time5"
        case .time10: return "time10"
        case .time15: return "time15"
        case .time20: return "time20"
        case .time25: return "time25"
        case .time30: return "time30"
        case .time35: return "time35"
        case .time40: return "time40"
        case .time45: return "time45"
        case .time50: return "time50"
        case .time55: return "time55"
        case .time60: return "time60"
        @unknown default: return "time20"
        }
    }

    private func mapSizeFromNative(_ size: BackupSize) -> String {
        switch size {
        case .size5: return "size5"
        case .size10: return "size10"
        case .size15: return "size15"
        case .size20: return "size20"
        case .size25: return "size25"
        case .size30: return "size30"
        case .size35: return "size35"
        case .size40: return "size40"
        case .size45: return "size45"
        case .size50: return "size50"
        @unknown default: return "size40"
        }
    }
}

// MARK: - Stream Handlers

class BeaconsStreamHandler: NSObject, FlutterStreamHandler {
    var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

class SyncStreamHandler: NSObject, FlutterStreamHandler {
    var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

class RegionStreamHandler: NSObject, FlutterStreamHandler {
    var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

// MARK: - Listener Implementations

class BeaconListenerImpl: NSObject, BeaconListener {
    weak var streamHandler: BeaconsStreamHandler?

    init(streamHandler: BeaconsStreamHandler?) {
        self.streamHandler = streamHandler
    }

    func onBeaconsDetected(_ beacons: [Beacon], eventType: String) {
        DispatchQueue.main.async { [weak self] in
            guard let eventSink = self?.streamHandler?.eventSink else { return }

            let beaconsList: [[String: Any]] = beacons.map { beacon in
                var beaconDict: [String: Any] = [:]

                // Use Mirror to access properties dynamically
                let mirror = Mirror(reflecting: beacon)
                for child in mirror.children {
                    if let label = child.label {
                        switch label {
                        case "uuid":
                            // UUID is Foundation.UUID type, need to convert to String
                            if let value = child.value as? UUID {
                                beaconDict["uuid"] = value.uuidString
                            } else if let value = child.value as? String {
                                beaconDict["uuid"] = value
                            }
                        case "major":
                            // Try both String and Int
                            if let value = child.value as? Int {
                                beaconDict["major"] = value
                            } else if let value = child.value as? String, let intValue = Int(value) {
                                beaconDict["major"] = intValue
                            }
                        case "minor":
                            // Try both String and Int
                            if let value = child.value as? Int {
                                beaconDict["minor"] = value
                            } else if let value = child.value as? String, let intValue = Int(value) {
                                beaconDict["minor"] = intValue
                            }
                        case "rssi":
                            if let value = child.value as? Int {
                                beaconDict["rssi"] = value
                            }
                        case "bluetoothName":
                            // Handle Optional<String>
                            if let value = child.value as? String {
                                beaconDict["bluetoothName"] = value
                            }
                        case "bluetoothAddress":
                            // Handle Optional<String>
                            if let value = child.value as? String {
                                beaconDict["bluetoothAddress"] = value
                            }
                        case "distance", "distanceMeters":
                            // Handle Optional<Float> and convert to Double
                            if let value = child.value as? Double {
                                beaconDict["distanceMeters"] = value
                            } else if let value = child.value as? Float {
                                beaconDict["distanceMeters"] = Double(value)
                            } else {
                                // Try to unwrap Optional<Float>
                                let mirror = Mirror(reflecting: child.value)
                                if mirror.displayStyle == .optional,
                                   let first = mirror.children.first,
                                   let floatValue = first.value as? Float {
                                    beaconDict["distanceMeters"] = Double(floatValue)
                                }
                            }
                        case "lastSeen":
                            if let value = child.value as? Date {
                                beaconDict["lastSeen"] = Int(value.timeIntervalSince1970 * 1000)
                            }
                        default:
                            break
                        }
                    }
                }

                return beaconDict
            }

            let eventData: [String: Any] = [
                "type": "beaconsDetected",
                "beacons": beaconsList,
                "eventType": eventType.uppercased()
            ]

            eventSink(eventData)
        }
    }
}

class SyncListenerImpl: NSObject, SyncListener {
    weak var streamHandler: SyncStreamHandler?

    init(streamHandler: SyncStreamHandler?) {
        self.streamHandler = streamHandler
    }

    func onSyncSuccess(eventType: String, beaconCount: Int, message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let eventSink = self?.streamHandler?.eventSink else { return }

            let eventData: [String: Any] = [
                "type": "syncSuccess",
                "eventType": eventType,
                "beaconsCount": beaconCount,
                "message": message
            ]

            eventSink(eventData)
        }
    }

    func onSyncError(eventType: String, beaconCount: Int, errorCode: Int?, errorMessage: String) {
        DispatchQueue.main.async { [weak self] in
            guard let eventSink = self?.streamHandler?.eventSink else { return }

            var eventData: [String: Any] = [
                "type": "syncError",
                "eventType": eventType,
                "beaconsCount": beaconCount,
                "errorMessage": errorMessage
            ]

            if let errorCode = errorCode {
                eventData["errorCode"] = errorCode
            }

            eventSink(eventData)
        }
    }
}

class RegionListenerImpl: NSObject, RegionListener {
    weak var streamHandler: RegionStreamHandler?

    init(streamHandler: RegionStreamHandler?) {
        self.streamHandler = streamHandler
    }

    func onRegionEnter(regionName: String) {
        DispatchQueue.main.async { [weak self] in
            guard let eventSink = self?.streamHandler?.eventSink else { return }

            let eventData: [String: Any] = [
                "type": "beaconRegionEnter",
                "regionName": regionName
            ]

            eventSink(eventData)
        }
    }

    func onRegionExit(regionName: String) {
        DispatchQueue.main.async { [weak self] in
            guard let eventSink = self?.streamHandler?.eventSink else { return }

            let eventData: [String: Any] = [
                "type": "beaconRegionExit",
                "regionName": regionName
            ]

            eventSink(eventData)
        }
    }
}
