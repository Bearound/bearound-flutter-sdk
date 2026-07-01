import Flutter
import UIKit
import BearoundSDK
import ObjectiveC
import UserNotifications

// Workaround: Flutter 3.44.2 crasha no iOS 26 ao criar o ProMotion touch-rate VSync client
// porque o task runner é nil em viewDidLoad. Swizzle pra no-op (penalidade: sem correção de
// touch-rate em telas ProMotion). Reintroduzido com a volta ao modo legado (storyboard cria
// o FlutterViewController), onde esse caminho é exercido.
private func patchFlutterProMotionCrash() {
  guard #available(iOS 26, *) else { return }
  let sel = NSSelectorFromString("createTouchRateCorrectionVSyncClientIfNeeded")
  guard let method = class_getInstanceMethod(FlutterViewController.self, sel) else { return }
  let noop: @convention(block) (AnyObject) -> Void = { _ in }
  method_setImplementation(method, imp_implementationWithBlock(noop))
}

// UIScene desativada (ver _UIApplicationSceneManifest no Info.plist): voltamos ao ciclo de
// vida legado do AppDelegate para que os eventos de background do UIApplicationDelegate
// (silent push wakeup, region/BLE state restoration, background fetch) voltem a ser
// entregues — exatamente como o app nativo BeAroundScan. Sem FlutterImplicitEngineDelegate;
// registro clássico de plugins via GeneratedPluginRegistrant.register(with: self).
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    patchFlutterProMotionCrash()
    GeneratedPluginRegistrant.register(with: self)

    BeAroundSDK.shared.registerBackgroundTasks()
    // Silent push: registra no APNs para o servidor poder acordar o app em background.
    // (O SDK também faz auto-capture do token via swizzle; chamar aqui é idempotente e
    // espelha o AppDelegate do nativo.)
    application.registerForRemoteNotifications()

    // App relançado em background por evento de região/Bluetooth com o app MORTO
    // (state restoration) — espelha o nativo, que notifica "App Reativado".
    if launchOptions?[.location] != nil {
      NSLog("[Runner] App relançado por LOCATION (region entry)")
      Self.notifyAppRelaunched()
    }
    if launchOptions?[.bluetoothCentrals] != nil {
      NSLog("[Runner] App relançado por BLUETOOTH (state restoration)")
      Self.notifyAppRelaunched()
    }

    // Notificações: autorização + delegate para exibir banner em foreground (willPresent).
    // O silent push do Bearound é tratado pelo swizzle do SDK → didCompletePushScan no
    // plugin (que dispara a notificação local), igual ao BeaconViewModel do nativo.
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      NSLog("[Runner] Notif auth granted=%d error=%@", granted ? 1 : 0, error?.localizedDescription ?? "nil")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Notificação de relançamento em background — replica notifyAppRelaunchedInBackground do nativo.
  private static func notifyAppRelaunched() {
    let content = UNMutableNotificationContent()
    content.title = "App Reativado"
    content.body = "BeAroundSDK detectou região de beacons em segundo plano"
    content.sound = .default
    UNUserNotificationCenter.current().add(
      UNNotificationRequest(
        identifier: "bearound.relaunch.\(Int(Date().timeIntervalSince1970))",
        content: content,
        trigger: nil
      )
    )
  }

  // Background fetch: o SO acorda o app periodicamente para um refresh — espelha o nativo.
  override func application(
    _ application: UIApplication,
    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    NSLog("[Runner] Background fetch triggered")
    BeAroundSDK.shared.performBackgroundFetch { success in
      completionHandler(success ? .newData : .noData)
    }
  }

  // Background URLSession: iOS relança o app para entregar uploads de beacon concluídos.
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

  // APNs token: o SDK auto-captura via swizzle (PushTokenAutoCapture), que preserva e
  // encadeia este override. Mantido só para logar o token e validar a entrega.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    NSLog("[Runner] APNs token: %@", token)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[Runner] APNs register FAILED: %@", error.localizedDescription)
  }

  // WORKAROUND do bug do FlutterAppDelegate com silent push (flutter#155479 / #52895):
  // o FlutterAppDelegate NÃO implementa application(_:didReceiveRemoteNotification:fetchCompletionHandler:)
  // como método real — usa dynamic forwarding (kSelectorsHandledByPlugins) e responde "não respondo"
  // no respondsToSelector: a menos que um PLUGIN registrado o implemente. Resultado: o iOS descarta
  // o silent push e NÃO acorda o app suspenso, e o swizzle do SDK não tem método concreto onde operar.
  // A variante DEPRECATED abaixo (sem fetchCompletionHandler) NÃO está na lista de sequestro do Flutter,
  // então chega ao app e ACORDA mesmo suspenso. Replicamos aqui o fluxo do swizzle do SDK, chamando-o
  // direto — é o que o app nativo BeAroundScan obtém via swizzle (que no Flutter não funciona).
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any]
  ) {
    guard userInfo["bearound"] != nil else { return }
    NSLog("[Runner] Silent push Bearound recebido (variante deprecated) — scan + sync")
    BeAroundSDK.shared.performBackgroundBLERefreshAndSync(
      bleScanDuration: 10.0, trigger: "silent_push"
    ) { ingestStarted in
      let info = BeAroundSDK.shared.lastBackgroundScanInfo
      let found = info?.beaconsFound ?? 0
      let pending = info?.pendingBatches ?? 0
      NSLog(
        "[Runner] Silent push handled: beacons=%d ingest=%d pending=%d",
        found, ingestStarted ? 1 : 0, pending
      )
      DispatchQueue.main.async {
        BeAroundSDK.shared.delegate?.didCompletePushScan(
          beaconsFound: found, ingestStarted: ingestStarted, pendingBatches: pending
        )
      }
    }
  }

  // Exibe o banner mesmo com o app em foreground (push normal/alert). Em background,
  // o iOS já mostra o alert sozinho.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    NSLog("[Runner] willPresent push em foreground: %@", notification.request.content.title)
    completionHandler([.banner, .sound])
  }
}
