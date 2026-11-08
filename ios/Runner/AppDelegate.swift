import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Pide a iOS el token de APNs desde el arranque, sin depender de que el
    // plugin de Firebase lo haga (es idempotente: llamarlo dos veces es seguro).
    application.registerForRemoteNotifications()
    print("🍏 APNs nativo: registerForRemoteNotifications() llamado")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Diagnóstico de push: iOS informa aquí si el registro con APNs funcionó o
  // por qué falló (entitlement, red, perfil...). Se delega siempre en super
  // para que firebase_messaging reciba el token.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    print("🍏 APNs nativo: token recibido (\(deviceToken.count) bytes)")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ APNs nativo: el registro falló: \(error.localizedDescription) | \(error)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
