import Flutter
import UIKit
import BearoundSDK

public class BearoundFlutterSdkPlugin: NSObject, FlutterPlugin {
    var detector: Bearound?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "bearound_flutter_sdk", binaryMessenger: registrar.messenger())
        let instance = BearoundFlutterSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
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
            let isDebugEnable = args["isDebugEnable"] as? Bool ?? false
            detector = Bearound.init(clientToken: clientToken, isDebugEnable: isDebugEnable)
            detector?.startServices()
            result(nil)
        case "stop":
            detector?.stopServices()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
