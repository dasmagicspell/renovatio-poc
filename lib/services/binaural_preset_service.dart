import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/binaural_preset.dart';

class BinauralPresetService {
  static const String _jsonPath = 'assets/json/binaural-audio-presets.json';
  
  static List<BinauralActivity>? _cachedActivities;
  
  /// Load all binaural audio activities from JSON
  static Future<List<BinauralActivity>> loadActivities() async {
    if (_cachedActivities != null) {
      return _cachedActivities!;
    }
    
    try {
      final String jsonString = await rootBundle.loadString(_jsonPath);
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      
      _cachedActivities = jsonList.map((json) {
        return BinauralActivity.fromJson(json as Map<String, dynamic>);
      }).toList();
      
      return _cachedActivities!;
    } catch (e) {
      print('Error loading binaural presets: $e');
      return [];
    }
  }
  
  /// Clear cache (useful for reloading)
  static void clearCache() {
    _cachedActivities = null;
  }
}

