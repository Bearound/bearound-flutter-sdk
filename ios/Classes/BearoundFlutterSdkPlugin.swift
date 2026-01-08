import BearoundSDK
import CoreLocation
import Flutter
import UIKit

public class BearoundFlutterSdkPlugin: NSObject, FlutterPlugin, BeAroundSDKDelegate {
    private let beaconsStreamHandler = EventStreamHandler()
    private let syncStreamHandler = EventStreamHandler()
    private let scanningStreamHandler = EventStreamHandler()
    private let errorStreamHandler = EventStreamHandler()
    private var isActiveScan = false

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

        let syncChannel = FlutterEventChannel(
            name: "bearound_flutter_sdk/sync",
            binaryMessenger: registrar.messenger()
        )
        syncChannel.setStreamHandler(instance.syncStreamHandler)

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

        BeAroundSDK.shared.delegate = instance
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "configure":
            let args = call.arguments as? [String: Any]
            guard
                let businessToken = (args?["businessToken"] as? String)?.trimmingCharacters(
                    in: .whitespacesAndNewlines),
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

            let syncInterval = (args?["syncInterval"] as? NSNumber)?.doubleValue ?? 30
            let enableBluetoothScanning = args?["enableBluetoothScanning"] as? Bool ?? false
            let enablePeriodicScanning = args?["enablePeriodicScanning"] as? Bool ?? true

            BeAroundSDK.shared.configure(
                businessToken: businessToken,
                syncInterval: syncInterval,
                enableBluetoothScanning: enableBluetoothScanning,
                enablePeriodicScanning: enablePeriodicScanning
            )
            BeAroundSDK.shared.delegate = self
            result(nil)

        case "startScanning":
            isActiveScan = true
            BeAroundSDK.shared.delegate = self
            BeAroundSDK.shared.startScanning()
            result(nil)

        case "stopScanning":
            isActiveScan = false
            BeAroundSDK.shared.stopScanning()
            DispatchQueue.main.async { [weak self] in
                self?.beaconsStreamHandler.eventSink?(["beacons": []])
                self?.syncStreamHandler.eventSink?([
                    "secondsUntilNextSync": 0,
                    "isRanging": false,
                ])
                self?.scanningStreamHandler.eventSink?(["isScanning": false])
            }
            result(nil)

        case "isScanning":
            result(BeAroundSDK.shared.isScanning)

        case "setBluetoothScanning":
            let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
            BeAroundSDK.shared.setBluetoothScanning(enabled: enabled)
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

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func didUpdateBeacons(_ beacons: [Beacon]) {
        guard isActiveScan else { return }
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
        guard isActiveScan else { return }
        let payload: [String: Any] = [
            "message": error.localizedDescription
        ]
        DispatchQueue.main.async { [weak self] in
            self?.errorStreamHandler.eventSink?(payload)
        }
    }

    public func didChangeScanning(isScanning: Bool) {
        isActiveScan = isScanning
        DispatchQueue.main.async { [weak self] in
            self?.scanningStreamHandler.eventSink?(["isScanning": isScanning])
        }
    }

    public func didUpdateSyncStatus(secondsUntilNextSync: Int, isRanging: Bool) {
        guard isActiveScan else { return }
        let payload: [String: Any] = [
            "secondsUntilNextSync": secondsUntilNextSync,
            "isRanging": isRanging,
        ]
        DispatchQueue.main.async { [weak self] in
            self?.syncStreamHandler.eventSink?(payload)
        }
    }

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
}

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
