# ElevenLabs TTS Integration Plan

## Overview
This document outlines the plan to integrate ElevenLabs Text-to-Speech API for generating narration audio in the Renovatio app.

## Why ElevenLabs?
- **Higher Quality**: More natural-sounding voices compared to OpenAI TTS
- **Better for Meditation**: Offers voices specifically tuned for calm, soothing narration
- **More Voice Options**: Wide variety of voices with different characteristics
- **Flexible Settings**: Fine-tune stability, similarity, and style for optimal results
- **Cost Effective**: Competitive pricing for TTS generation

## Integration Steps

### Step 1: Get ElevenLabs API Key
1. Sign up at https://elevenlabs.io
2. Navigate to your profile settings
3. Copy your API key
4. Add it to your app configuration (see Step 3)

### Step 2: Add Dependencies
The existing `dio` package is already in use, so no additional dependencies needed.

### Step 3: Initialize ElevenLabs Service
Update `main.dart` or `session_details_page.dart` to initialize the service:

```dart
import 'services/elevenlabs_service.dart';

// In your initialization code:
ElevenLabsService.initialize('YOUR_ELEVENLABS_API_KEY');
```

### Step 4: Update Session Details Page
Modify `session_details_page.dart` to use ElevenLabs instead of ChatGPTService:

**Current Code (using OpenAI):**
```dart
final generatedFilePath = await ChatGPTService.generateAudioWithTTS(
  prompt: widget.session.narrationText,
  sessionId: widget.session.id,
  voice: 'alloy',
  model: 'tts-1',
);
```

**New Code (using ElevenLabs):**
```dart
final generatedFilePath = await ElevenLabsService.generateMeditationNarration(
  text: widget.session.narrationText,
  voiceId: ElevenLabsService.getDefaultMeditationVoiceId(), // or custom voice
);
```

### Step 5: Handle File Format Differences
ElevenLabs returns MP3 by default, while the current code expects WAV. The service handles this automatically, but you may need to update the audio player if it doesn't support MP3.

## Code Changes Required

### File: `lib/session_details_page.dart`

**Change 1: Import Statement**
```dart
// Remove or keep for other features:
// import 'chatgpt_service.dart';

// Add:
import 'services/elevenlabs_service.dart';
```

**Change 2: Initialization (in initState or _initializeChatGPTService)**
```dart
void _initializeElevenLabsService() {
  // Get API key from environment or config
  const apiKey = 'YOUR_ELEVENLABS_API_KEY'; // TODO: Move to secure storage
  ElevenLabsService.initialize(apiKey);
  print('ElevenLabsService initialized for TTS');
}
```

**Change 3: Update _loadNarration() method**
Replace the ChatGPTService call with ElevenLabsService:

```dart
// Generate narration audio using ElevenLabs TTS
final generatedFilePath = await ElevenLabsService.generateMeditationNarration(
  text: widget.session.narrationText,
  voiceId: ElevenLabsService.getDefaultMeditationVoiceId(), // or null for default
);
```

## Voice Selection Options

### Option 1: Use Default Meditation Voice
```dart
ElevenLabsService.generateMeditationNarration(
  text: widget.session.narrationText,
); // Uses default calm voice
```

### Option 2: Let User Choose Voice
```dart
// In new_session_page.dart, add voice selection dropdown
String? _selectedVoiceId;

// In session_details_page.dart
ElevenLabsService.generateMeditationNarration(
  text: widget.session.narrationText,
  voiceId: widget.session.selectedVoiceId, // Store in Session model
);
```

### Option 3: Use Recommended Voices
```dart
final voices = ElevenLabsService.getRecommendedVoices();
// 'Rachel' - Calm, soothing (best for meditation)
// 'Bella' - Soft, warm
// 'Antoni' - Deep, calm male
```

## Configuration Options

### For Meditation/Relaxation (Default)
- **Stability**: 0.6 (higher = more consistent)
- **Similarity Boost**: 0.8 (higher = more natural)
- **Style**: 0.2 (slight variation)
- **Output Format**: MP3 192kbps (high quality)

### For Custom Settings
```dart
ElevenLabsService.generateSpeech(
  text: widget.session.narrationText,
  voiceId: '21m00Tcm4TlvDq8ikWAM', // Rachel
  stability: 0.7, // More stable
  similarityBoost: 0.9, // More natural
  style: 0.1, // Less variation
  outputFormat: 'mp3_44100_192', // High quality
);
```

## API Key Management

### Option 1: Environment Variables (Recommended)
Create a `.env` file:
```
ELEVENLABS_API_KEY=your_api_key_here
```

Use `flutter_dotenv` package to load it.

### Option 2: Secure Storage
Store API key in secure storage (flutter_secure_storage) and load on app start.

### Option 3: Configuration File
Create `lib/config/api_keys.dart`:
```dart
class ApiKeys {
  static const String elevenLabs = 'YOUR_API_KEY';
  // Don't commit this file to git!
}
```

## Testing Checklist

- [ ] API key is correctly initialized
- [ ] Narration text is sent to ElevenLabs API
- [ ] Audio file is generated and saved
- [ ] Audio file plays correctly in the app
- [ ] File format (MP3) is supported by audio player
- [ ] Error handling works for API failures
- [ ] Voice quality is suitable for meditation
- [ ] File caching works (doesn't regenerate if exists)

## Migration Path

### Phase 1: Add ElevenLabs Service (Current)
- ✅ Create `elevenlabs_service.dart`
- ✅ Add initialization code
- ⏳ Update session_details_page.dart

### Phase 2: Replace OpenAI TTS
- ⏳ Update `_loadNarration()` method
- ⏳ Test with sample narration text
- ⏳ Verify audio quality

### Phase 3: Optional Enhancements
- ⏳ Add voice selection UI
- ⏳ Add voice preview functionality
- ⏳ Store user voice preferences
- ⏳ Add voice settings customization

## Cost Considerations

ElevenLabs pricing (as of 2024):
- Free tier: 10,000 characters/month
- Starter: $5/month for 30,000 characters
- Creator: $22/month for 100,000 characters

For a meditation app with ~500 words per session:
- ~2,500 characters per session
- Free tier: ~4 sessions/month
- Starter: ~12 sessions/month
- Creator: ~40 sessions/month

## Troubleshooting

### Issue: API returns 401 Unauthorized
**Solution**: Check API key is correct and properly initialized

### Issue: Audio file doesn't play
**Solution**: Verify audio player supports MP3 format (just_audio does support MP3)

### Issue: Voice sounds robotic
**Solution**: Adjust stability (lower) and similarity_boost (higher) settings

### Issue: File format not supported
**Solution**: Change outputFormat to 'pcm_44100' or 'wav' if needed

## Next Steps

1. Get ElevenLabs API key
2. Update `session_details_page.dart` to use ElevenLabsService
3. Test with sample narration text
4. Adjust voice settings if needed
5. Consider adding voice selection UI for users
