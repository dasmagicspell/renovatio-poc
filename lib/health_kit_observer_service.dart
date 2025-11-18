import 'package:flutter/services.dart';

class HealthKitObserverService {
  static const MethodChannel _channel = MethodChannel('health_kit_observer');
  
  // Callbacks for different events
  static Function(List<Map<String, dynamic>>)? onHeartRateData;
  static Function(bool)? onAuthorizationGranted;
  static Function()? onAuthorizationDenied;
  static Function()? onObserverStarted;
  static Function()? onObserverStopped;
  static Function(String)? onError;
  
  static bool _isInitialized = false;
  
  /// Initialize the observer service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    _channel.setMethodCallHandler(_handleMethodCall);
    _isInitialized = true;
  }
  
  /// Handle method calls from Swift
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onHeartRateData':
        print("📱 Flutter: Received heart rate data from Swift: ${call.arguments}");
        print("📱 Flutter: Type of call.arguments: ${call.arguments.runtimeType}");
        
        try {
          // Handle the wrapped data format: {timestamp: ..., data: [...]}
          if (call.arguments is Map<String, dynamic>) {
            final args = call.arguments as Map<String, dynamic>;
            final data = List<Map<String, dynamic>>.from(args['data'] ?? []);
            print("📱 Flutter: Parsed ${data.length} heart rate readings from wrapped format");
            onHeartRateData?.call(data);
          } else if (call.arguments is List) {
            // Handle direct array format - convert Object? maps to String, dynamic maps
            final rawList = call.arguments as List;
            final data = rawList.map((item) {
              if (item is Map) {
                return Map<String, dynamic>.from(item);
              } else {
                throw Exception('Invalid item type: ${item.runtimeType}');
              }
            }).toList();
            print("📱 Flutter: Parsed ${data.length} heart rate readings from direct format");
            onHeartRateData?.call(data);
          } else {
            print("❌ Flutter: Unexpected data format: ${call.arguments.runtimeType}");
          }
        } catch (e) {
          print("❌ Flutter: Error parsing heart rate data: $e");
          print("❌ Flutter: Raw arguments: ${call.arguments}");
        }
        break;
        
      case 'onAuthorizationGranted':
        onAuthorizationGranted?.call(true);
        break;
        
      case 'onAuthorizationDenied':
        onAuthorizationDenied?.call();
        break;
        
      case 'onObserverStarted':
        onObserverStarted?.call();
        break;
        
      case 'onObserverStopped':
        onObserverStopped?.call();
        break;
        
        
      case 'onError':
        final error = call.arguments['error'] as String;
        onError?.call(error);
        break;
        
      default:
        print('Unknown method call: ${call.method}');
    }
  }
  
  /// Request HealthKit authorization
  static Future<void> requestAuthorization() async {
    try {
      await _channel.invokeMethod('requestAuthorization');
    } catch (e) {
      print('Error requesting authorization: $e');
    }
  }
  
  /// Start the heart rate observer
  static Future<void> startObserver() async {
    try {
      await _channel.invokeMethod('startObserver');
    } catch (e) {
      print('Error starting observer: $e');
    }
  }
  
  /// Stop the heart rate observer
  static Future<void> stopObserver() async {
    try {
      await _channel.invokeMethod('stopObserver');
    } catch (e) {
      print('Error stopping observer: $e');
    }
  }
  
  /// Manually fetch heart rate data now
  static Future<void> fetchDataNow() async {
    try {
      await _channel.invokeMethod('fetchDataNow');
    } catch (e) {
      print('Error fetching data now: $e');
    }
  }
  
  
  /// Set up callbacks for different events
  static void setCallbacks({
    Function(List<Map<String, dynamic>>)? onHeartRateDataCallback,
    Function(bool)? onAuthorizationGrantedCallback,
    Function()? onAuthorizationDeniedCallback,
    Function()? onObserverStartedCallback,
    Function()? onObserverStoppedCallback,
    Function(String)? onErrorCallback,
  }) {
    onHeartRateData = onHeartRateDataCallback;
    onAuthorizationGranted = onAuthorizationGrantedCallback;
    onAuthorizationDenied = onAuthorizationDeniedCallback;
    onObserverStarted = onObserverStartedCallback;
    onObserverStopped = onObserverStoppedCallback;
    onError = onErrorCallback;
  }
  
  /// Clear all callbacks
  static void clearCallbacks() {
    onHeartRateData = null;
    onAuthorizationGranted = null;
    onAuthorizationDenied = null;
    onObserverStarted = null;
    onObserverStopped = null;
    onError = null;
  }
}
