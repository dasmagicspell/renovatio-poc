import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class ChatGPTService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  static String? _apiKey;
  
  static final Dio _dio = Dio();
  
  /// Initialize the service with your API key
  static void initialize(String apiKey) {
    _apiKey = apiKey;
    _dio.options.baseUrl = _baseUrl;
    _dio.options.headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
  }
  
  /// Generate audio using a more realistic approach with actual TTS
  static Future<String?> generateAudioWithTTS({
    required String prompt,
    required String sessionId,
    String voice = 'alloy',
    String model = 'tts-1',
  }) async {
    if (_apiKey == null) {
      throw Exception('ChatGPT API key not initialized');
    }
    
    try {
      // Use OpenAI's TTS API
      final response = await _dio.post(
        '/audio/speech',
        data: {
          'model': model,
          'input': prompt,
          'voice': voice,
          'response_format': 'wav',
          'speed': 0.7,
          'instructions': 'Speak slowly, softly, and calmly. Use a gentle, reassuring tone suitable for affirmations.',
        },
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );
      
      if (response.statusCode == 200) {
        // Save the audio file
        final directory = await getApplicationDocumentsDirectory();
        final audioDir = Directory('${directory.path}/generated_audio');
        if (!await audioDir.exists()) {
          await audioDir.create(recursive: true);
        }
        
        final fileName = 'session_${sessionId}_${DateTime.now().millisecondsSinceEpoch}.wav';
        final filePath = '${audioDir.path}/$fileName';
        
        final file = File(filePath);
        await file.writeAsBytes(response.data);
        
        return filePath;
      } else {
        throw Exception('Failed to generate audio: ${response.statusMessage}');
      }
    } catch (e) {
      print('Error generating audio with TTS: $e');
      return null;
    }
  }
  
  /// Generate audio directly from prompt using ChatGPT TTS
  static Future<String?> generateAudioWithScript({
    required String prompt,
    required String sessionId,
    String voice = 'alloy',
    String model = 'tts-1',
  }) async {
    if (_apiKey == null) {
      throw Exception('ChatGPT API key not initialized');
    }
    
    try {
      // Generate audio directly from the prompt
      final audioResponse = await _dio.post(
        '/audio/speech',
        data: {
          'model': 'gpt-4o-mini-tts',
          'input': prompt,
          'voice': voice,
          'response_format': 'wav'
        },
        options: Options(responseType: ResponseType.bytes)
      );
      
      if (audioResponse.statusCode == 200) {
        // Save the audio file directly
        final directory = await getApplicationDocumentsDirectory();
        final audioDir = Directory('${directory.path}/generated_audio');
        if (!await audioDir.exists()) {
          await audioDir.create(recursive: true);
        }
        
        final fileName = 'session_${sessionId}_${DateTime.now().millisecondsSinceEpoch}.wav';
        final filePath = '${audioDir.path}/$fileName';
        
        final file = File(filePath);
        await file.writeAsBytes(audioResponse.data);
        
        return filePath;
      } else {
        throw Exception('Failed to generate audio: ${audioResponse.statusMessage}');
      }
    } catch (e) {
      print('Error generating audio with script: $e');
      return null;
    }
  }
  
  /// Get available voices
  static List<String> getAvailableVoices() {
    return ['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer'];
  }
  
  /// Get available models
  static List<String> getAvailableModels() {
    return ['tts-1', 'tts-1-hd'];
  }

  /// Generate a guided narration script for the New Session page.
  static Future<String?> generateNarrationScript({
    String? activity,
    required int durationMinutes,
    String? sessionName,
  }) async {
    if (_apiKey == null) {
      throw Exception('ChatGPT API key not initialized');
    }

    try {
      final sessionNameLine =
          (sessionName != null && sessionName.trim().isNotEmpty)
              ? 'Session title: ${sessionName.trim()}'
              : 'Session title: (not provided)';
      final goalLine =
          (activity != null && activity.trim().isNotEmpty)
              ? 'Goal/activity: ${activity.trim()}'
              : null;

      final prompt = '''
Create a calm, supportive guided narration script for a wellness soundscape session.

${goalLine ?? ''}
Duration: $durationMinutes minutes
$sessionNameLine

Rules:
- Return only the final narration script in SSML (Speech Synthesis Markup Language) format. Add a 10-second pause between each sentence.
- Do not include headings, labels, notes, markdown, JSON, or code fences.
- Do not include surrounding quotation marks.
- Keep the tone gentle, grounded, and easy to follow.
- Write in second person ("you").
- Include natural pauses by using short sentences.
- Keep the length appropriate for roughly $durationMinutes minutes when narrated slowly.
''';

      final response = await _dio.post(
        '/chat/completions',
        data: {
          // Use a chat-completions compatible model.
          'model': 'gpt-5-mini',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You write meditation and relaxation narration scripts. '
                      'Output strictly plain script text only.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 1.0,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to generate narration script.');
      }

      final rawContent = response.data['choices']?[0]?['message']?['content'];
      if (rawContent is! String) {
        return null;
      }

      return _sanitizeGeneratedScript(rawContent);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final details = e.response?.data;
      print(
        'Error generating narration script: '
        'status=$status, message=${e.message}, response=$details',
      );
      return null;
    } catch (e) {
      print('Error generating narration script: $e');
      return null;
    }
  }

  static String _sanitizeGeneratedScript(String input) {
    var output = input.trim();

    if (output.startsWith('```')) {
      output = output.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      output = output.replaceFirst(RegExp(r'```$'), '');
      output = output.trim();
    }

    if (output.startsWith('"') && output.endsWith('"') && output.length >= 2) {
      output = output.substring(1, output.length - 1).trim();
    }

    return output;
  }

  /// Generate binaural audio configuration JSON based on activity prompt
  static Future<Map<String, dynamic>?> generateBinauralConfig({
    required String prompt,
    required String sessionId,
    required String sessionTitle,
    required String frequencyRange,
  }) async {
    if (_apiKey == null) {
      throw Exception('ChatGPT API key not initialized');
    }

    try {
      print('🤖 Loading JSON schema...');
      // Load the JSON schema
      final schemaString = await rootBundle.loadString('lib/schemas/binaural_audio_schema.json');

      print('📝 Preparing AI prompt for session: $sessionTitle');
      // Create the AI prompt with schema instructions
      final aiPrompt = '''
You are an expert in binaural audio generation and brainwave entrainment. Based on the following activity prompt, generate a JSON configuration that follows the provided schema exactly.

Activity Prompt: $prompt
Session ID: $sessionId
Session Title: $sessionTitle
Frequency Range: $frequencyRange

Please generate a JSON configuration that:
1. Follows the exact schema structure provided below
2. Uses appropriate binaural beat frequencies for the specified frequency range
3. Sets reasonable audio parameters for a 5-minute session
4. Includes appropriate ambient sounds based on the activity type
5. Sets proper fade-in/fade-out times
6. Includes safety limits for audio levels

JSON Schema to follow:
$schemaString

Return ONLY the JSON configuration, no additional text or explanation.
''';

      print('🚀 Sending request to ChatGPT API...');
      final response = await _dio.post(
        '/chat/completions',
        data: {
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': 'You are an expert in binaural audio generation. Generate JSON configurations that follow the provided schema exactly.'
            },
            {
              'role': 'user',
              'content': aiPrompt
            }
          ],
          'temperature': 0.3,
          'max_tokens': 2000,
        },
      );

      if (response.statusCode == 200) {
        print('✅ Received response from ChatGPT API');
        final content = response.data['choices'][0]['message']['content'];
        
        print('🔧 Processing AI response...');
        // Clean the response to extract only JSON
        String jsonString = content.trim();
        if (jsonString.startsWith('```json')) {
          jsonString = jsonString.substring(7);
        }
        if (jsonString.startsWith('```')) {
          jsonString = jsonString.substring(3);
        }
        if (jsonString.endsWith('```')) {
          jsonString = jsonString.substring(0, jsonString.length - 3);
        }
        
        print('📋 Parsing JSON configuration...');
        final config = json.decode(jsonString) as Map<String, dynamic>;
        
        print('✔️ Validating configuration against schema...');
        // Validate that the config follows the schema structure
        if (_validateConfig(config)) {
          print('🎉 AI configuration generated successfully!');
          return config;
        } else {
          print('❌ Generated config does not follow the required schema');
          throw Exception('Generated config does not follow the required schema');
        }
      } else {
        print('❌ ChatGPT API error: ${response.statusMessage}');
        throw Exception('Failed to generate config: ${response.statusMessage}');
      }
    } catch (e) {
      print('Error generating binaural config: $e');
      return null;
    }
  }

  /// Validate that the generated config follows the required schema
  static bool _validateConfig(Map<String, dynamic> config) {
    // Basic validation - check for required fields
    final requiredFields = [
      'version', 'intent', 'duration_sec', 'sample_rate_hz', 
      'master_gain', 'binaural', 'envelope', 'ambience', 
      'safety', 'metadata'
    ];
    
    for (final field in requiredFields) {
      if (!config.containsKey(field)) {
        print('Missing required field: $field');
        return false;
      }
    }
    
    // Validate binaural section
    if (config['binaural'] is! Map<String, dynamic>) {
      print('Invalid binaural section');
      return false;
    }
    
    final binaural = config['binaural'] as Map<String, dynamic>;
    if (!binaural.containsKey('mode') || !binaural.containsKey('carrier_wave')) {
      print('Missing required binaural fields');
      return false;
    }
    
    return true;
  }
}
