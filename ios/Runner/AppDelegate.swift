import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DvcrLiveActivityNativeSync") {
      LiveActivityFcmSync.registerChannel(registrar: registrar)
    }
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    let liveUpdated = LiveActivityFcmSync.apply(userInfo: userInfo)
    super.application(application, didReceiveRemoteNotification: userInfo) { result in
      completionHandler(liveUpdated ? .newData : result)
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    _ = LiveActivityFcmSync.apply(userInfo: userInfo)
    if #available(iOS 16.1, *) {
      Task {
        if await LiveActivityFcmSync.shouldSuppressVisibleBanner(userInfo: userInfo) {
          completionHandler([])
          return
        }
        super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
      }
      return
    }
    super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
  }
}
