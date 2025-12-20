import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/session.dart';
import '../heart_rate_service.dart';
import 'config_service.dart';

class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  
  /// Get API key from environment variables
  static String get _apiKey {
    final key = ConfigService.openAIApiKey;
    if (key == null) {
      throw Exception('OpenAI API key not configured. Please set OPENAI_API_KEY in .env file');
    }
    return key;
  }
  
  /// Get the best available model (GPT-5 if available, otherwise GPT-4)
  static Future<String> _getBestModel() async {
    // Try GPT-5 first, fallback to GPT-4
    // Note: GPT-5 may not be available yet, so we'll use gpt-4-turbo-preview or gpt-4
    return 'gpt-4-turbo-preview'; // or 'gpt-4' if turbo is not available
  }
  
  /// Analyze heart rate changes during the session
  static Future<String> analyzeHeartRateChanges({
    required Session session,
    required List<HeartRateData> heartRateData,
    required Duration elapsedTime,
    required DateTime sessionStartTime,
  }) async {
    try {
      final model = await _getBestModel();
      
      // Build the prompt
      final prompt = _buildPrompt(session, heartRateData, elapsedTime, sessionStartTime);
      
      // Make the API request
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a health and wellness AI assistant specializing in analyzing heart rate patterns during meditation, relaxation, and binaural audio soundscapes. Provide clear, concise, and actionable insights.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.7,
          'max_tokens': 500,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return content;
      } else {
        print('OpenAI API error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to get AI analysis: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calling OpenAI API: $e');
      rethrow;
    }
  }
  
  /// Build the prompt for heart rate analysis
  static String _buildPrompt(
    Session session,
    List<HeartRateData> heartRateData,
    Duration elapsedTime,
    DateTime sessionStartTime,
  ) {
    final elapsedMinutes = elapsedTime.inMinutes;
    final elapsedSeconds = elapsedTime.inSeconds % 60;
    
    // Format heart rate data with time since session start
    final heartRateList = heartRateData.take(20).map((data) {
      final timeSinceStart = data.dateTime.difference(sessionStartTime);
      final minutesSinceStart = timeSinceStart.inMinutes;
      final secondsSinceStart = timeSinceStart.inSeconds % 60;
      final timeString = minutesSinceStart > 0 
          ? '${minutesSinceStart}m ${secondsSinceStart}s'
          : '${secondsSinceStart}s';
      return '${data.value.toStringAsFixed(0)} BPM at ${data.formattedTime} (${timeString} into soundscape)';
    }).join('\n');
    
    // Calculate initial heart rate (oldest reading)
    final initialHeartRate = heartRateData.isNotEmpty 
        ? heartRateData.last.value 
        : null;
    
    // Calculate current heart rate (newest reading)
    final currentHeartRate = heartRateData.isNotEmpty 
        ? heartRateData.first.value 
        : null;
    
    // Calculate average heart rate
    final averageHeartRate = heartRateData.isNotEmpty
        ? heartRateData.map((d) => d.value).reduce((a, b) => a + b) / heartRateData.length
        : null;
    
    return '''
Analyze the heart rate data from a binaural audio soundscape and provide insights on whether the user's heart rate has changed since the soundscape started.

**Soundscape Details:**
- Soundscape Name: ${session.name}
- Activity Type: ${session.activity}
- Planned Duration: ${session.durationMinutes} minutes
- Time Elapsed: ${elapsedMinutes} minutes ${elapsedSeconds} seconds
- Background Music: ${session.backgroundMusic}

**Heart Rate Data (Last 20 readings, newest first):**
$heartRateList

**Summary Statistics:**
${initialHeartRate != null ? '- Initial Heart Rate: ${initialHeartRate.toStringAsFixed(0)} BPM' : '- Initial Heart Rate: Not available'}
${currentHeartRate != null ? '- Current Heart Rate: ${currentHeartRate.toStringAsFixed(0)} BPM' : '- Current Heart Rate: Not available'}
${averageHeartRate != null ? '- Average Heart Rate: ${averageHeartRate.toStringAsFixed(0)} BPM' : '- Average Heart Rate: Not available'}
${initialHeartRate != null && currentHeartRate != null ? '- Change: ${(currentHeartRate - initialHeartRate).toStringAsFixed(0)} BPM (${currentHeartRate > initialHeartRate ? '+' : ''}${((currentHeartRate - initialHeartRate) / initialHeartRate * 100).toStringAsFixed(1)}%)' : ''}

**Analysis Request:**
Please analyze:
1. Has the user's heart rate changed significantly since the soundscape started?
2. What is the overall trend (increasing, decreasing, or stable)?
3. Is the heart rate pattern consistent with the intended activity (${session.activity})?
4. Are there any notable patterns or anomalies in the data?
5. Provide a brief recommendation based on the analysis.

Keep your response concise (2-3 sentences per point) and focus on actionable insights.
''';
  }
}

