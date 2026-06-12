import Flutter
import UIKit
import BearoundSDK

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register BGTask handlers before launch completes (required by BGTaskScheduler) and
    // touch the SDK so a terminated/background relaunch auto-restores config + re-arms
    // region monitoring synchronously.
    BeAroundSDK.shared.registerBackgroundTasks()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Background URLSession: iOS relaunches the app to deliver completed beacon-upload
  // transfers. Forward to the SDK so it finalizes the pending upload(s) and calls the
  // system completion handler — required for terminated-state ingest delivery.
  override func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    NSLog("[Runner] handleEventsForBackgroundURLSession: %@", identifier)
    BeAroundSDK.shared.handleBackgroundURLSessionEvents(
      identifier: identifier,
      completionHandler: completionHandler
    )
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
