import Flutter
import UIKit
import CoreLocation

@available(iOS 13.0, *)
public class BearoundFlutterSdkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private let tracker = BeaconTracker.shared

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "bearound_flutter_sdk", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "bearound_flutter_sdk_events", binaryMessenger: registrar.messenger())
        let instance = BearoundFlutterSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            let status = CLLocationManager.authorizationStatus()
            if status == .notDetermined {
                result(FlutterError(code: "PERMISSION_NOT_GRANTED", message: "Location permission not granted", details: nil))
                return
            }
            tracker.delegate = self
            tracker.startTracking()
            result(nil)
        case "stop":
            tracker.stopTracking()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        tracker.delegate = self
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

@available(iOS 13.0, *)
extension BearoundFlutterSdkPlugin: BeaconActionsDelegate {
    func updateBeaconList(_ beacon: Beacon) {
        let data: [String: Any] = [
            "uuid": beacon.uuid.uuidString,
            "major": beacon.major,
            "minor": beacon.minor,
            "rssi": beacon.rssi,
            "bluetoothName": beacon.bluetoothName ?? "",
            "bluetoothAddress": beacon.bluetoothAddress ?? "",
            "distanceMeters": beacon.distanceMeters ?? -1,
            "lastSeen": beacon.lastSeen.timeIntervalSince1970
        ]
        eventSink?(["event": "beacon", "beacon": data])
    }
}
