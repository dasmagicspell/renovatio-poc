import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var healthKitObserver: HealthKitObserver?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Set up HealthKit observer channel
    setupHealthKitChannel()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupHealthKitChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    
    let channel = FlutterMethodChannel(
      name: "health_kit_observer",
      binaryMessenger: controller.binaryMessenger
    )
    
    healthKitObserver = HealthKitObserver(channel: channel)
    
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleMethodCall(call: call, result: result)
    }
  }
  
  private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestAuthorization":
      healthKitObserver?.requestAuthorization()
      result(nil)
      
    case "startObserver":
      healthKitObserver?.startHeartRateObserver()
      result(nil)
      
    case "stopObserver":
      healthKitObserver?.stopHeartRateObserver()
      result(nil)
      
    case "fetchDataNow":
      healthKitObserver?.fetchHeartRateDataNow()
      result(nil)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
