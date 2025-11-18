import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'health_kit_observer_service.dart';

class HeartRateService {
  static final Health _health = Health();
  
  // Health data types we want to read
  static const List<HealthDataType> _types = [
    HealthDataType.HEART_RATE,
  ];
  
  // Observer callbacks
  static Function(List<HeartRateData>)? _onNewHeartRateData;
  static Function(String)? _onObserverError;
  
  // Observer state
  static bool _isObserverActive = false;
  
  /// Check if HealthKit is available on this device
  static Future<bool> isHealthDataAvailable() async {
    try {
      // For now, assume health data is available on iOS
      // The health package will handle the actual availability check
      return true;
    } catch (e) {
      print('Error checking health data availability: $e');
      return false;
    }
  }
  
  /// Request permissions to read heart rate data
  static Future<bool> requestPermissions() async {
    try {
      // Request HealthKit permissions
      bool requested = await _health.requestAuthorization(_types);
      
      if (!requested) {
        return false;
      }
      
      return true;
    } catch (e) {
      print('Error requesting health permissions: $e');
      return false;
    }
  }
  
  /// Get heart rate data for the last hour
  static Future<List<HeartRateData>> getHeartRateLastHour() async {
    try {
      // Check if health data is available
      bool isAvailable = await isHealthDataAvailable();
      if (!isAvailable) {
        throw Exception('Health data is not available on this device');
      }
      
      // Request permissions
      bool hasPermission = await requestPermissions();
      if (!hasPermission) {
        throw Exception('Health permissions not granted');
      }
      
      // Calculate time range (last hour)
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      
      // Fetch heart rate data
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        startTime: oneHourAgo,
        endTime: now,
        types: _types,
      );
      
      // Remove duplicates
      healthData = _health.removeDuplicates(healthData);
      
      // Convert to our HeartRateData model
      List<HeartRateData> heartRateData = healthData
          .where((data) => data.type == HealthDataType.HEART_RATE)
          .map((data) => HeartRateData(
                value: (data.value as NumericHealthValue).numericValue.toDouble(),
                dateTime: data.dateFrom,
                unit: data.unitString,
              ))
          .toList();
      
      // Sort by date (most recent first)
      heartRateData.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      
      return heartRateData;
    } catch (e) {
      print('Error fetching heart rate data: $e');
      rethrow;
    }
  }
  
  /// Get heart rate data for a custom time range
  static Future<List<HeartRateData>> getHeartRateData(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // Check if health data is available
      bool isAvailable = await isHealthDataAvailable();
      if (!isAvailable) {
        throw Exception('Health data is not available on this device');
      }
      
      // Request permissions
      bool hasPermission = await requestPermissions();
      if (!hasPermission) {
        throw Exception('Health permissions not granted');
      }
      
      // Fetch heart rate data
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        startTime: startDate,
        endTime: endDate,
        types: _types,
      );
      
      // Remove duplicates
      healthData = _health.removeDuplicates(healthData);
      
      // Convert to our HeartRateData model
      List<HeartRateData> heartRateData = healthData
          .where((data) => data.type == HealthDataType.HEART_RATE)
          .map((data) => HeartRateData(
                value: (data.value as NumericHealthValue).numericValue.toDouble(),
                dateTime: data.dateFrom,
                unit: data.unitString,
              ))
          .toList();
      
      // Sort by date (most recent first)
      heartRateData.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      
      return heartRateData;
    } catch (e) {
      print('Error fetching heart rate data: $e');
      rethrow;
    }
  }
  
  // MARK: - Observer Methods
  
  /// Initialize the HealthKit observer
  static Future<void> initializeObserver() async {
    await HealthKitObserverService.initialize();
    
    // Set up callbacks
    HealthKitObserverService.setCallbacks(
      onHeartRateDataCallback: _handleNewHeartRateData,
      onAuthorizationGrantedCallback: _handleAuthorizationGranted,
      onAuthorizationDeniedCallback: _handleAuthorizationDenied,
      onObserverStartedCallback: _handleObserverStarted,
      onObserverStoppedCallback: _handleObserverStopped,
      onErrorCallback: _handleObserverError,
    );
  }
  
  /// Start the heart rate observer
  static Future<void> startObserver() async {
    if (_isObserverActive) return;
    
    try {
      await HealthKitObserverService.requestAuthorization();
      await HealthKitObserverService.startObserver();
      _isObserverActive = true;
    } catch (e) {
      print('Error starting observer: $e');
      _onObserverError?.call(e.toString());
    }
  }
  
  /// Stop the heart rate observer
  static Future<void> stopObserver() async {
    if (!_isObserverActive) return;
    
    try {
      await HealthKitObserverService.stopObserver();
      _isObserverActive = false;
    } catch (e) {
      print('Error stopping observer: $e');
      _onObserverError?.call(e.toString());
    }
  }
  
  /// Manually fetch heart rate data now
  static Future<void> fetchDataNow() async {
    try {
      await HealthKitObserverService.fetchDataNow();
    } catch (e) {
      print('Error fetching data now: $e');
      _onObserverError?.call(e.toString());
    }
  }
  
  
  /// Set callbacks for observer events
  static void setObserverCallbacks({
    Function(List<HeartRateData>)? onNewHeartRateData,
    Function(String)? onObserverError,
  }) {
    _onNewHeartRateData = onNewHeartRateData;
    _onObserverError = onObserverError;
  }
  
  /// Get current observer state
  static bool get isObserverActive => _isObserverActive;
  
  // MARK: - Observer Event Handlers
  
  static void _handleNewHeartRateData(List<Map<String, dynamic>> data) {
    print("🔄 HeartRateService: Processing ${data.length} heart rate readings");
    try {
      final heartRateData = data.map((item) {
        print("   Processing item: $item");
        // Parse UTC datetime and convert to local time
        final utcDateTime = DateTime.parse(item['dateTime']);
        final localDateTime = utcDateTime.toLocal();
        print("   UTC: ${utcDateTime.toIso8601String()} -> Local: ${localDateTime.toIso8601String()}");
        
        return HeartRateData(
          value: (item['value'] as num).toDouble(),
          dateTime: localDateTime,
          unit: item['unit'] as String,
        );
      }).toList();
      
      print("🔄 HeartRateService: Successfully parsed ${heartRateData.length} readings, calling callback");
      _onNewHeartRateData?.call(heartRateData);
    } catch (e) {
      print('❌ Error parsing heart rate data: $e');
      _onObserverError?.call('Error parsing heart rate data: $e');
    }
  }
  
  static void _handleAuthorizationGranted(bool granted) {
    print('HealthKit authorization granted: $granted');
  }
  
  static void _handleAuthorizationDenied() {
    print('HealthKit authorization denied');
    _onObserverError?.call('HealthKit authorization denied');
  }
  
  static void _handleObserverStarted() {
    print('🚀 Flutter: Heart rate observer started successfully');
    _isObserverActive = true;
  }
  
  static void _handleObserverStopped() {
    print('🛑 Flutter: Heart rate observer stopped');
    _isObserverActive = false;
  }
  
  
  static void _handleObserverError(String error) {
    print('Observer error: $error');
    _onObserverError?.call(error);
  }
}

/// Model class for heart rate data
class HeartRateData {
  final double value;
  final DateTime dateTime;
  final String unit;
  
  HeartRateData({
    required this.value,
    required this.dateTime,
    required this.unit,
  });
  
  /// Get formatted time string
  String get formattedTime {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
  
  /// Get formatted date string
  String get formattedDate {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    return '$day/$month/$year';
  }
  
  /// Get heart rate zone based on age (assuming 30 years old for demo)
  HeartRateZone get heartRateZone {
    // Simplified heart rate zones (assuming max HR = 220 - age)
    const int assumedAge = 30;
    const int maxHeartRate = 220 - assumedAge; // 190 BPM
    
    if (value < maxHeartRate * 0.5) {
      return HeartRateZone.resting;
    } else if (value < maxHeartRate * 0.6) {
      return HeartRateZone.fatBurn;
    } else if (value < maxHeartRate * 0.7) {
      return HeartRateZone.cardio;
    } else if (value < maxHeartRate * 0.8) {
      return HeartRateZone.peak;
    } else {
      return HeartRateZone.maximum;
    }
  }
}

/// Heart rate zones
enum HeartRateZone {
  resting,
  fatBurn,
  cardio,
  peak,
  maximum,
}

extension HeartRateZoneExtension on HeartRateZone {
  String get name {
    switch (this) {
      case HeartRateZone.resting:
        return 'Resting';
      case HeartRateZone.fatBurn:
        return 'Fat Burn';
      case HeartRateZone.cardio:
        return 'Cardio';
      case HeartRateZone.peak:
        return 'Peak';
      case HeartRateZone.maximum:
        return 'Maximum';
    }
  }
  
  String get description {
    switch (this) {
      case HeartRateZone.resting:
        return 'Recovery and rest';
      case HeartRateZone.fatBurn:
        return 'Fat burning zone';
      case HeartRateZone.cardio:
        return 'Cardiovascular fitness';
      case HeartRateZone.peak:
        return 'High intensity';
      case HeartRateZone.maximum:
        return 'Maximum effort';
    }
  }
  
  Color get color {
    switch (this) {
      case HeartRateZone.resting:
        return Colors.blue;
      case HeartRateZone.fatBurn:
        return Colors.green;
      case HeartRateZone.cardio:
        return Colors.orange;
      case HeartRateZone.peak:
        return Colors.red;
      case HeartRateZone.maximum:
        return Colors.purple;
    }
  }
}
