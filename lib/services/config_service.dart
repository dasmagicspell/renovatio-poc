import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service for managing configuration and API keys from environment variables
class ConfigService {
  /// Get OpenAI API key from environment variables
  static String? get openAIApiKey {
    final key = dotenv.env['OPENAI_API_KEY'];
    if (key == null || key.isEmpty || key == 'your_openai_api_key_here') {
      print('⚠️ Warning: OPENAI_API_KEY not found in .env file');
      return null;
    }
    return key;
  }
  
  /// Get ElevenLabs API key from environment variables
  static String? get elevenLabsApiKey {
    final key = dotenv.env['ELEVENLABS_API_KEY'];
    if (key == null || key.isEmpty || key == 'your_elevenlabs_api_key_here') {
      print('⚠️ Warning: ELEVENLABS_API_KEY not found in .env file');
      return null;
    }
    return key;
  }
  
  /// Check if all required API keys are configured
  static bool get areApiKeysConfigured {
    return openAIApiKey != null && elevenLabsApiKey != null;
  }
  
  /// Validate that API keys are configured, throw exception if not
  static void validateApiKeys() {
    if (!areApiKeysConfigured) {
      throw Exception(
        'API keys not configured. Please create a .env file with OPENAI_API_KEY and ELEVENLABS_API_KEY.\n'
        'See env.example for reference.'
      );
    }
  }
}
