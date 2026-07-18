import Flutter
import UIKit
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let cookieChannel = FlutterMethodChannel(name: "com.topluyo/cookie_manager",
                                              binaryMessenger: controller.binaryMessenger)
    cookieChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "flushCookies" {
          if #available(iOS 11.0, *) {
              // Reading cookies forces WKWebsiteDataStore to sync its internal state
              WKWebsiteDataStore.default().httpCookieStore.getAllCookies { _ in
                  result(nil)
              }
          } else {
              result(nil)
          }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
