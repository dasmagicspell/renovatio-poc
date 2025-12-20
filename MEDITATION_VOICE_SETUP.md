# Meditation Voice Setup - Automatic Selection

## Overview ✅

The service automatically selects a **meditation-style voice** (calm, soothing voice) suitable for affirmations and guided meditation. It intelligently chooses from available voices based on priority.

## How It Works

### Automatic Voice Selection
The service uses a priority list to find the best meditation voice:

1. **Clara** - Calm, soothing (replacement for Nicole)
2. **Nicole** - Legacy meditation voice (deprecated Feb 2026, automatically routes to Clara)
3. **Rachel** - Calm, soothing
4. **Bella** - Soft, warm
5. **Antoni** - Deep, calm male

The service will automatically select the first available voice from this list.

### Benefits
- ✅ **Future-proof**: Automatically adapts when voices are deprecated
- ✅ **Flexible**: Works with any meditation-style voice
- ✅ **No hardcoding**: Doesn't depend on specific voice IDs
- ✅ **Smart fallback**: Uses best available option

## Usage

### Basic Usage (Recommended)
```dart
// Initialize the service
ElevenLabsService.initialize('YOUR_API_KEY');

// Optionally prefetch meditation voice ID (recommended)
await ElevenLabsService.prefetchMeditationVoice();

// Generate narration - will automatically use a meditation-style voice
final filePath = await ElevenLabsService.generateMeditationNarration(
  text: widget.session.narrationText,
);
```

### Manual Voice Selection (Optional)
If you want to use a specific voice:

```dart
// Find a specific voice
final claraVoice = await ElevenLabsService.findVoiceByName('Clara');
if (claraVoice != null) {
  // Use specific voice
  final filePath = await ElevenLabsService.generateMeditationNarration(
    text: widget.session.narrationText,
    voiceId: claraVoice.voiceId,
  );
}
```

### Manual Voice ID Setup (Advanced)
If you want to set a specific meditation voice ID:

```dart
// Get voice ID from ElevenLabs website: Voices > Copy voice ID
ElevenLabsService.setMeditationVoiceId('YOUR_VOICE_ID_HERE');
```

## Integration in session_details_page.dart

### Update Initialization
```dart
void _initializeElevenLabsService() {
  try {
    const apiKey = 'YOUR_ELEVENLABS_API_KEY';
    ElevenLabsService.initialize(apiKey);
    
    // Prefetch meditation voice ID (optional but recommended)
    ElevenLabsService.prefetchMeditationVoice().then((_) {
      print('Meditation voice ready');
    }).catchError((e) {
      print('Could not prefetch meditation voice: $e');
    });
    
    print('ElevenLabsService initialized for TTS');
  } catch (e) {
    print('Error initializing ElevenLabsService: $e');
  }
}
```

### Update _loadNarration() Method
```dart
// Generate narration audio using ElevenLabs TTS with meditation-style voice
final generatedFilePath = await ElevenLabsService.generateMeditationNarration(
  text: widget.session.narrationText,
  // voiceId is optional - will automatically select a meditation voice
);
```

## Voice Selection Process

1. **First Call**: When `generateMeditationNarration()` is called without a `voiceId`
2. **Check Cache**: Looks for cached meditation voice ID
3. **Fetch Voices**: If not cached, fetches all available voices from API
4. **Priority Search**: Searches for voices in priority order (Clara → Nicole → Rachel → Bella → Antoni)
5. **Select First Match**: Uses the first available voice from the priority list
6. **Cache Result**: Stores the selected voice ID for future use
7. **Generate**: Uses the selected voice to generate speech

## Customizing Meditation Voices

### Add Your Own Meditation Voice
Edit `lib/services/elevenlabs_service.dart`:

```dart
static const List<String> _meditationVoiceNames = [
  'Clara',    // Your preferred voice
  'Nicole',   // Legacy
  'Rachel',   // Calm, soothing
  'Bella',    // Soft, warm
  'Antoni',   // Deep, calm male
  'YourVoice', // Add your custom voice here
];
```

### Change Priority Order
Reorder the list to change which voice is selected first:

```dart
static const List<String> _meditationVoiceNames = [
  'Bella',    // Now Bella is first priority
  'Clara',
  'Rachel',
  // ...
];
```

## Testing

### Test Voice Selection
```dart
// Test meditation voice selection
final voiceId = await ElevenLabsService.getMeditationVoiceId();
print('Selected meditation voice ID: $voiceId');

// Test generation
final testFile = await ElevenLabsService.generateMeditationNarration(
  text: 'This is a test narration using a meditation-style voice.',
);
print('Generated file: $testFile');
```

### Test Specific Voice
```dart
// Test with a specific voice
final claraVoice = await ElevenLabsService.findVoiceByName('Clara');
if (claraVoice != null) {
  final filePath = await ElevenLabsService.generateMeditationNarration(
    text: 'Test with Clara voice',
    voiceId: claraVoice.voiceId,
  );
}
```

## Cache Management

### Clear Cache (Force Re-selection)
```dart
// Clear the cached meditation voice
ElevenLabsService.clearMeditationVoiceCache();

// Next call will re-fetch and select a voice
final voiceId = await ElevenLabsService.getMeditationVoiceId();
```

### Check Current Voice
```dart
// Get currently cached voice ID
final voiceId = await ElevenLabsService.getMeditationVoiceId();
print('Current meditation voice: $voiceId');
```

## Error Handling

The service includes robust error handling:

```dart
try {
  final filePath = await ElevenLabsService.generateMeditationNarration(
    text: widget.session.narrationText,
  );
  // Success
} catch (e) {
  // Handle errors:
  // - API key issues
  // - Network problems
  // - No voices available
  print('Error: $e');
}
```

## Summary

✅ **Automatically selects meditation-style voices**  
✅ **Future-proof (adapts to voice changes)**  
✅ **No hardcoded voice dependencies**  
✅ **Smart priority-based selection**  
✅ **Easy to customize**  
✅ **Works seamlessly with existing code**

The service will always use a calm, soothing voice suitable for meditation and affirmations, automatically adapting to changes in ElevenLabs' voice library.
