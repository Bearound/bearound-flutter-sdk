import Flutter
import UIKit
import BearoundSDK

public class BearoundFlutterSdkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, BearoundEventDelegate {
    var detector: Bearound?
    var eventSink: FlutterEventSink?

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
            detector = Bearound.init(clientToken: "", isDebugEnable: true)
            detector?.eventDelegate = self
            detector?.startServices()
            result(nil)
        case "stop":
            detector?.stopServices()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - FlutterStreamHandler
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    // MARK: - BearoundEventDelegate
    public func didUpdateBeacon(_ beacon: Beacon) {
        let beaconDict: [String: Any] = [
            "uuid": beacon.uuid.uuidString,
            "major": beacon.major,
            "minor": beacon.minor,
            "rssi": beacon.rssi,
            "bluetoothName": beacon.bluetoothName ?? "",
            "bluetoothAddress": beacon.bluetoothAddress ?? "",
            "distanceMeters": beacon.distanceMeters ?? 0.0,
            "lastSeen": beacon.lastSeen.timeIntervalSince1970
        ]
        eventSink?(["beacon": beaconDict])
    }
}
