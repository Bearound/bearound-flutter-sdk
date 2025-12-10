import Flutter
import UIKit
import BearoundSDK

public class BearoundFlutterSdkPlugin: NSObject, FlutterPlugin {
    var detector: Bearound?

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

            detector = Bearound(clientToken: clientToken, isDebugEnable: isDebugEnable)
            
            detector?.requestPermissions()

            // Setup listeners
            beaconListener = BeaconListenerImpl(streamHandler: beaconsStreamHandler)
            syncListener = SyncListenerImpl(streamHandler: syncStreamHandler)
            regionListener = RegionListenerImpl(streamHandler: regionStreamHandler)

            if let beaconListener = beaconListener {
                detector?.addBeaconListener(beaconListener)
            }
            if let syncListener = syncListener {
                detector?.addSyncListener(syncListener)
            }
            if let regionListener = regionListener {
                detector?.addRegionListener(regionListener)
            }

            detector?.startServices()
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
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - Stream Handlers

class BeaconsStreamHandler: NSObject, FlutterStreamHandler {
    var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        print("[BearoundFlutterSdk] Beacons event channel started listening")
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        print("[BearoundFlutterSdk] Beacons event channel cancelled")
        return nil
    }
}

class SyncStreamHandler: NSObject, FlutterStreamHandler {
    var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        print("[BearoundFlutterSdk] Sync event channel started listening")
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        print("[BearoundFlutterSdk] Sync event channel cancelled")
        return nil
    }
}

class RegionStreamHandler: NSObject, FlutterStreamHandler {
    var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        print("[BearoundFlutterSdk] Region event channel started listening")
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        print("[BearoundFlutterSdk] Region event channel cancelled")
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

                // Debug: Print all mirror properties
                let mirror = Mirror(reflecting: beacon)
                print("[BearoundFlutterSdk] Beacon mirror properties:")
                for child in mirror.children {
                    print("  - \(child.label ?? "no label"): \(type(of: child.value)) = \(child.value)")
                }

                // Use Mirror to access properties dynamically
                for child in mirror.children {
                    if let label = child.label {
                        switch label {
                        case "uuid":
                            // UUID is Foundation.UUID type, need to convert to String
                            if let value = child.value as? UUID {
                                beaconDict["uuid"] = value.uuidString
                                print("[BearoundFlutterSdk] UUID captured: \(value.uuidString)")
                            } else if let value = child.value as? String {
                                beaconDict["uuid"] = value
                                print("[BearoundFlutterSdk] UUID captured as String: \(value)")
                            } else {
                                print("[BearoundFlutterSdk] UUID failed to cast, type: \(type(of: child.value))")
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

                print("[BearoundFlutterSdk] Final beaconDict: \(beaconDict)")
                return beaconDict
            }

            let eventData: [String: Any] = [
                "type": "beaconsDetected",
                "beacons": beaconsList,
                "eventType": eventType.uppercased()
            ]

            eventSink(eventData)
            print("[BearoundFlutterSdk] Sent beacon event: \(eventType) with \(beacons.count) beacons")
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
            print("[BearoundFlutterSdk] Sync success: \(eventType), count: \(beaconCount)")
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
            print("[BearoundFlutterSdk] Sync error: \(errorMessage)")
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
            print("[BearoundFlutterSdk] Region enter: \(regionName)")
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
            print("[BearoundFlutterSdk] Region exit: \(regionName)")
        }
    }
}
