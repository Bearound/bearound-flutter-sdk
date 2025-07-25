import Flutter
import UIKit
import BearoundSDK

public class BearoundFlutterSdkPlugin: NSObject, FlutterPlugin {
    var detector: BeaconDetector?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "bearound_flutter_sdk", binaryMessenger: registrar.messenger())
        let instance = BearoundFlutterSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            detector = BeaconDetector.shared
            detector?.startScanning { beacon in
                print("Detected beacon: \(beacon)")
            }
            result(nil)
        case "stop":
            detector?.stopScanning()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
