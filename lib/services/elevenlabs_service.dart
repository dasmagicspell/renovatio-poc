import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'narration_script_parser.dart';
import 'silence_generator.dart';
import 'ffmpeg_executor.dart';

/// Result returned by [ElevenLabsService.generateSegmentedNarration].
class NarrationGenerationResult {
  /// Ordered segment file paths for [ConcatenatingAudioSource] playback.
  final List<String> segmentPaths;

  /// Single merged MP3 file for export. Null if ffmpeg stitching failed.
  final String? mergedPath;

  const NarrationGenerationResult({
    required this.segmentPaths,
    this.mergedPath,
  });
}

/// Service for ElevenLabs Text-to-Speech API
/// Documentation: https://docs.elevenlabs.io/api-reference/text-to-speech
class ElevenLabsService {
  static const String _baseUrl = 'https://api.elevenlabs.io/v1';
  static String? _apiKey;
  
  static final Dio _dio = Dio();
  
  /// Initialize the service with your ElevenLabs API key
  static void initialize(String apiKey) {
    if (apiKey.isEmpty || apiKey == 'YOUR_ELEVENLABS_API_KEY') {
      throw Exception('Invalid API key. Please provide a valid ElevenLabs API key.');
    }
    
    _apiKey = apiKey;
    _dio.options.baseUrl = _baseUrl;
    _dio.options.headers = {
      'xi-api-key': apiKey,
      'Content-Type': 'application/json',
    };
    
    print('✅ ElevenLabsService initialized with API key: ${apiKey.substring(0, 10)}...');
  }
  
  /// Verify the API key is valid by making a test request
  static Future<bool> verifyApiKey() async {
    if (_apiKey == null) {
      throw Exception('API key not initialized');
    }
    
    try {
      final response = await _dio.get(
        '/user',
        options: Options(
          headers: {
            'xi-api-key': _apiKey!,
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        print('✅ API key verified successfully');
        return true;
      }
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        print('❌ API key verification failed: Invalid API key');
        return false;
      }
      print('⚠️ API key verification error: ${e.message}');
      return false;
    } catch (e) {
      print('❌ API key verification error: $e');
      return false;
    }
  }
  
  /// Prefetch meditation voice ID (recommended to call after initialize)
  /// This will cache the meditation voice ID so it's ready for use
  /// Automatically selects the best available meditation-style voice
  static Future<void> prefetchMeditationVoice() async {
    try {
      await getMeditationVoiceId();
      print('✅ Meditation voice ID prefetched and cached');
    } catch (e) {
      print('⚠️ Could not prefetch meditation voice ID: $e');
      print('   You can set it manually using setMeditationVoiceId() or get it from the ElevenLabs website');
    }
  }
  
  /// Get available voices from ElevenLabs
  /// [includeLegacy] - Set to true to include legacy voices like Nicole (default: true)
  static Future<List<ElevenLabsVoice>> getVoices({bool includeLegacy = true}) async {
    if (_apiKey == null) {
      throw Exception('ElevenLabs API key not initialized');
    }
    
    try {
      final response = await _dio.get(
        '/voices',
        queryParameters: includeLegacy ? {'show_legacy': true} : null,
        options: Options(
          headers: {
            'xi-api-key': _apiKey!,
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        final voices = (response.data['voices'] as List)
            .map((v) => ElevenLabsVoice.fromJson(v))
            .toList();
            
        return voices;
      } else {
        throw Exception('Failed to get voices: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      print('❌ Error getting ElevenLabs voices: ${e.message}');
      if (e.response != null) {
        print('Response status: ${e.response?.statusCode}');
        print('Response data: ${e.response?.data}');
        
        if (e.response?.statusCode == 401) {
          throw Exception('Unauthorized: Invalid API key. Please check your ElevenLabs API key.');
        }
      }
      rethrow;
    } catch (e) {
      print('Error getting ElevenLabs voices: $e');
      rethrow;
    }
  }
  
  /// Find a voice by name (case-insensitive)
  /// Useful for finding specific voices like "Nicole"
  static Future<ElevenLabsVoice?> findVoiceByName(String voiceName, {bool includeLegacy = true}) async {
    try {
      final voices = await getVoices(includeLegacy: includeLegacy);
      final voice = voices.firstWhere(
        (v) => v.name.toLowerCase() == voiceName.toLowerCase(),
        orElse: () => throw Exception('Voice not found'),
      );
      return voice;
    } catch (e) {
      print('Error finding voice "$voiceName": $e');
      return null;
    }
  }
  
  /// Generate speech from text using ElevenLabs TTS
  /// 
  /// [text] - The text to convert to speech
  /// [voiceId] - The voice ID to use (required)
  /// [modelId] - The model to use (default: 'eleven_monolingual_v1')
  /// [stability] - Stability setting (0.0-1.0, default: 0.5)
  /// [similarityBoost] - Similarity boost (0.0-1.0, default: 0.75)
  /// [style] - Style setting (0.0-1.0, default: 0.0)
  /// [useSpeakerBoost] - Enable speaker boost (default: true)
  /// [outputFormat] - Output format (default: 'mp3_44100_128')
  /// 
  /// Output format tiers:
  /// - All tiers: 'mp3_44100_128', 'pcm_16000', 'pcm_22050', 'pcm_24000', 'pcm_44100', 'ulaw_8000'
  /// - Creator tier+: 'mp3_44100_192', 'mp3_44100_224'
  /// 
  /// Note: Using formats not available for your tier will result in a 403 error.
  static Future<String?> generateSpeech({
    required String text,
    String? voiceId,
    String modelId = 'eleven_monolingual_v2',
    double stability = 0.5,
    double similarityBoost = 0.75,
    double style = 0.0,
    bool useSpeakerBoost = true,
    String outputFormat = 'mp3_44100_128',
  }) async {
    if (_apiKey == null) {
      throw Exception('ElevenLabs API key not initialized');
    }
    
    // Use provided voice ID (should be set by caller, e.g., Nicole for meditation)
    if (voiceId == null) {
      throw Exception('Voice ID is required. Use generateMeditationNarration() for default Nicole voice, or provide a voiceId.');
    }
    final selectedVoiceId = voiceId;
    
    try {
      final response = await _dio.post(
        '/text-to-speech/$selectedVoiceId',
        data: {
          'text': text,
          // 'model_id': modelId, // not working so commented out
          'output_format': outputFormat,
          'voice_settings': {
            'stability': stability,
            'similarity_boost': similarityBoost,
            'style': style,
            'use_speaker_boost': useSpeakerBoost,
            'speed': 0.7,
          },
        },
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'xi-api-key': _apiKey!,
            'Accept': 'audio/mpeg', // For MP3 format
          },
        ),
        /*queryParameters: {
          'output_format': outputFormat,
        },*/
      );
      
      if (response.statusCode == 200) {
        // Save the audio file
        final directory = await getApplicationDocumentsDirectory();
        final audioDir = Directory('${directory.path}/generated_audio');
        if (!await audioDir.exists()) {
          await audioDir.create(recursive: true);
        }
        
        // Determine file extension based on output format
        final extension = outputFormat.startsWith('mp3') 
            ? 'mp3' 
            : outputFormat.startsWith('pcm') 
                ? 'pcm' 
                : 'wav';
        
        final fileName = 'narration_${DateTime.now().millisecondsSinceEpoch}.$extension';
        final filePath = '${audioDir.path}/$fileName';
        
        final file = File(filePath);
        await file.writeAsBytes(response.data);
        
        print('✅ ElevenLabs TTS: Audio generated successfully at $filePath');
        return filePath;
      } else {
        throw Exception('Failed to generate speech: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      print('❌ Error generating speech with ElevenLabs: ${e.message}');
      if (e.response != null) {
        print('Response status: ${e.response?.statusCode}');
        
        // Decode error response
        String errorMessage = 'Unknown error';
        try {
          if (e.response?.data is List<int>) {
            // Response is bytes, decode it
            final decoded = utf8.decode(e.response!.data as List<int>);
            final errorJson = json.decode(decoded);
            if (errorJson is Map && errorJson.containsKey('detail')) {
              final detail = errorJson['detail'];
              if (detail is Map && detail.containsKey('message')) {
                errorMessage = detail['message'] as String;
              } else if (detail is Map && detail.containsKey('status')) {
                errorMessage = detail['status'] as String;
              }
            }
          } else if (e.response?.data is Map) {
            final errorJson = e.response!.data as Map;
            if (errorJson.containsKey('detail')) {
              final detail = errorJson['detail'];
              if (detail is Map && detail.containsKey('message')) {
                errorMessage = detail['message'] as String;
              }
            }
          }
        } catch (decodeError) {
          print('Could not decode error response: $decodeError');
        }
        
        print('Error message: $errorMessage');
        
        if (e.response?.statusCode == 401) {
          throw Exception('Unauthorized: Invalid API key. Please check your ElevenLabs API key.');
        } else if (e.response?.statusCode == 403) {
          throw Exception('Forbidden: $errorMessage\n\nThis usually means your account tier doesn\'t support the requested feature. Try using a lower quality output format.');
        } else if (e.response?.statusCode == 429) {
          throw Exception('Rate limit exceeded: You have reached your ElevenLabs API usage limit.');
        } else {
          throw Exception('API Error (${e.response?.statusCode}): $errorMessage');
        }
      }
      rethrow;
    } catch (e) {
      print('❌ Error generating speech with ElevenLabs: $e');
      rethrow;
    }
  }
  
  /// Generate speech optimized for meditation/relaxation narration
  /// Automatically selects a meditation-style voice (calm, soothing voice suitable for affirmations)
  /// Uses settings tuned for calm, soothing voice
  static Future<String?> generateMeditationNarration({
    required String text,
    String? voiceId,
  }) async {
    // If no voice ID provided, automatically select a meditation-style voice
    String? selectedVoiceId = voiceId;
    
    if (selectedVoiceId == null) {
      try {
        // Automatically get a meditation-style voice (will use cache if available)
        selectedVoiceId = await getMeditationVoiceId();
      } catch (e) {
        print('❌ Could not get meditation voice ID: $e');
        throw Exception('Meditation voice not available. Please check your API key and connection.');
      }
    }
    
    // Use mp3_44100_128 which is available for all tiers
    // mp3_44100_192 requires Creator tier or above
    return generateSpeech(
      text: text,
      voiceId: selectedVoiceId,
      modelId: 'eleven_monolingual_v2',
      stability: 0.6, // Higher stability for consistent, calm voice
      similarityBoost: 0.8, // Higher similarity for natural voice
      style: 0.2, // Slight style for gentle variation
      useSpeakerBoost: true,
      outputFormat: 'mp3_44100_128', // Available for all account tiers
    );
  }
  
  /// Parses [narrationScript] for [pause:Xs] markup, then generates ElevenLabs
  /// TTS audio for each text segment sequentially (with a 1-second gap between
  /// API calls) and writes a silent WAV file for each pause segment.
  ///
  /// Results are cached on disk keyed by [sessionId] + [narrationHash] +
  /// [voiceId]. Subsequent calls with the same key return the cached files
  /// without hitting the API.
  ///
  /// Returns a [NarrationGenerationResult] with segment paths for playback and
  /// a merged MP3 path for export, or `null` if generation fails entirely.
  static Future<NarrationGenerationResult?> generateSegmentedNarration({
    required String narrationScript,
    required String sessionId,
    required String narrationHash,
    String? voiceId,
  }) async {
    if (_apiKey == null) {
      throw Exception('ElevenLabs API key not initialized');
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final voiceSuffix = voiceId != null ? '_$voiceId' : '';
      final segmentDir = Directory(
        '${directory.path}/generated_audio'
        '/narration_${sessionId}_$narrationHash$voiceSuffix',
      );
      final manifestFile = File('${segmentDir.path}/manifest.json');

      // Return cached result if manifest and all segment files still exist.
      if (await manifestFile.exists()) {
        try {
          final manifest =
              json.decode(await manifestFile.readAsString()) as Map;
          final cachedPaths = List<String>.from(manifest['segments'] as List);
          final existChecks =
              await Future.wait(cachedPaths.map((p) => File(p).exists()));
          if (existChecks.every((e) => e)) {
            final cachedMerged = manifest['merged'] as String?;
            final mergedExists = cachedMerged != null &&
                await File(cachedMerged).exists();
            print('✅ Narration: using ${cachedPaths.length} cached segments');
            return NarrationGenerationResult(
              segmentPaths: cachedPaths,
              mergedPath: mergedExists ? cachedMerged : null,
            );
          }
        } catch (_) {
          // Corrupt manifest — regenerate.
        }
      }

      final segments = NarrationScriptParser.parse(narrationScript);
      if (segments.isEmpty) return null;

      if (!await segmentDir.exists()) {
        await segmentDir.create(recursive: true);
      }

      // Resolve voice once before the sequential loop.
      final resolvedVoiceId = voiceId ?? await getMeditationVoiceId();

      // Generate segments one at a time. TTS requests wait 1 second after
      // each API call to stay within ElevenLabs' rate limits.
      // Silence segments are pure Dart and do not count against the delay.
      final orderedPaths = <String>[];
      bool firstApiCall = true;

      for (int i = 0; i < segments.length; i++) {
        final segment = segments[i];
        String? result;

        if (segment is TextNarrationSegment) {
          if (!firstApiCall) {
            await Future.delayed(const Duration(seconds: 1));
          }
          result = await _generateTextSegment(
            text: segment.text,
            voiceId: resolvedVoiceId,
            filePath: '${segmentDir.path}/seg_$i.mp3',
            index: i,
          );
          firstApiCall = false;
        } else if (segment is PauseNarrationSegment) {
          result = await _generateSilenceSegment(
            duration: segment.duration,
            filePath: '${segmentDir.path}/seg_$i.wav',
            index: i,
          );
        }

        if (result == null) {
          print('❌ Narration: segment $i failed — aborting.');
          return null;
        }
        orderedPaths.add(result);
      }

      // Stitch all segments into one merged MP3 for export.
      final mergedPath = await _stitchSegments(
        segmentPaths: orderedPaths,
        outputPath: '${segmentDir.path}/merged.mp3',
      );

      // Persist manifest (includes merged path if stitching succeeded).
      await manifestFile.writeAsString(
        json.encode({
          'version': 1,
          'segments': orderedPaths,
          if (mergedPath != null) 'merged': mergedPath,
        }),
      );

      print('✅ Narration: generated ${orderedPaths.length} segments');
      return NarrationGenerationResult(
        segmentPaths: orderedPaths,
        mergedPath: mergedPath,
      );
    } catch (e) {
      print('❌ Error generating segmented narration: $e');
      rethrow;
    }
  }

  static Future<String?> _generateTextSegment({
    required String text,
    required String voiceId,
    required String filePath,
    required int index,
  }) async {
    final file = File(filePath);
    if (await file.exists()) {
      print('  Segment $index: cached text segment');
      return filePath;
    }
    try {
      final tempPath = await generateSpeech(
        text: text,
        voiceId: voiceId,
        stability: 0.6,
        similarityBoost: 0.8,
        style: 0.2,
        useSpeakerBoost: true,
        outputFormat: 'mp3_44100_128',
      );
      if (tempPath == null) return null;
      await File(tempPath).copy(filePath);
      try {
        await File(tempPath).delete();
      } catch (_) {}
      print('  Segment $index: text segment generated');
      return filePath;
    } catch (e) {
      print('  Segment $index: failed — $e');
      return null;
    }
  }

  static Future<String?> _generateSilenceSegment({
    required Duration duration,
    required String filePath,
    required int index,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        await SilenceGenerator.generate(filePath: filePath, duration: duration);
      }
      print('  Segment $index: pause (${duration.inMilliseconds} ms)');
      return filePath;
    } catch (e) {
      print('  Segment $index: silence failed — $e');
      return null;
    }
  }

  /// Concatenates [segmentPaths] in order into a single MP3 at [outputPath]
  /// using ffmpeg's concat demuxer. Returns [outputPath] on success, null on failure.
  static Future<String?> _stitchSegments({
    required List<String> segmentPaths,
    required String outputPath,
  }) async {
    try {
      // The concat demuxer requires a text file listing the inputs.
      final concatListPath = '${outputPath}_concat_list.txt';
      final concatContent = segmentPaths
          .map((p) => "file '${p.replaceAll("'", r"\'")}'")
          .join('\n');
      await File(concatListPath).writeAsString(concatContent);

      final command =
          '-f concat -safe 0 -i "$concatListPath" -c:a libmp3lame -q:a 4 "$outputPath"';
      final result = await FFmpegExecutor.execute(command);

      try {
        await File(concatListPath).delete();
      } catch (_) {}

      if (result.isSuccess) {
        print('✅ Narration segments stitched → $outputPath');
        return outputPath;
      } else {
        print('❌ Narration stitch failed: ${result.output}');
        return null;
      }
    } catch (e) {
      print('❌ Error stitching narration segments: $e');
      return null;
    }
  }

  // Cached meditation voice ID (will be fetched on first use)
  static String? _cachedMeditationVoiceId;
  
  /// List of voice names that are suitable for meditation/relaxation
  /// These are calm, soothing voices perfect for affirmations and guided meditation
  static const List<String> _meditationVoiceNames = [
    'Kristen - Calm, Comforting, Meditative',
  ];
  
  /// Get a meditation-style voice ID (calm, soothing voice suitable for affirmations)
  /// Automatically selects the best available meditation voice from the API
  /// Priority: Clara > Nicole > Rachel > Bella > Antoni
  static Future<String> getMeditationVoiceId() async {
    // If we have a cached meditation voice ID, use it
    if (_cachedMeditationVoiceId != null) {
      return _cachedMeditationVoiceId!;
    }
    
    try {
      // Fetch all available voices (including legacy)
      final voices = await getVoices(includeLegacy: true);
      
      // Try to find a meditation voice in priority order
      for (final voiceName in _meditationVoiceNames) {
        final voice = voices.firstWhere(
          (v) => v.name.toLowerCase() == voiceName.toLowerCase(),
          orElse: () => throw Exception('Voice not found'),
        );
        
        _cachedMeditationVoiceId = voice.voiceId;
        print('✅ Selected meditation voice: ${voice.name} (ID: ${voice.voiceId})');
        return voice.voiceId;
      }
      
      // If no meditation voice found, use the first available voice as fallback
      if (voices.isNotEmpty) {
        _cachedMeditationVoiceId = voices.first.voiceId;
        print('⚠️ No preferred meditation voice found, using: ${voices.first.name}');
        return voices.first.voiceId;
      }
      
      throw Exception('No voices available from ElevenLabs API');
    } catch (e) {
      print('❌ Error finding meditation voice: $e');
      rethrow;
    }
  }
  
  /// Manually set the meditation voice ID (useful if you have a specific preference)
  /// You can get voice IDs from ElevenLabs website: Voices > Copy voice ID
  static void setMeditationVoiceId(String voiceId) {
    _cachedMeditationVoiceId = voiceId;
    print('✅ Meditation voice ID set manually: $voiceId');
  }
  
  /// Clear the cached meditation voice ID (forces re-fetch on next use)
  static void clearMeditationVoiceCache() {
    _cachedMeditationVoiceId = null;
    print('✅ Meditation voice cache cleared');
  }
  
  /// Get available voice IDs for different use cases
  /// Note: Voice IDs may change, use findVoiceByName() for dynamic lookup
  /// For meditation voices, use getMeditationVoiceId() which automatically selects the best option
  static Map<String, String> getRecommendedVoices() {
    return {
      // Meditation voices (automatically selected by getMeditationVoiceId())
      'Clara': 'Use getMeditationVoiceId()', // Calm, soothing (replacement for Nicole)
      'Nicole': 'Use getMeditationVoiceId()', // Legacy meditation voice (deprecated Feb 2026)
      'Rachel': '21m00Tcm4TlvDq8ikWAM', // Calm, soothing
      'Bella': 'EXAVITQu4vr4xnSDxMaL', // Soft, warm
      'Antoni': 'ErXwobaYiN019PkySvjV', // Deep, calm male
      'Kristen - Calm, Comforting, Meditative': '21m00Tcm4TlvDq8ikWAM', // Calm, soothing
      // Other voices
      'Domi': 'AZnzlk1XvdvUeBnXmlld', // Strong, confident
      'Elli': 'MF3mGyEYCl7XYWbV9V6O', // Young, cheerful
      'Josh': 'TxGEqnHWrfWFTfGW9XjX', // Deep, authoritative
      'Arnold': 'VR6AewLTigWG4xSOukaG', // Deep, calm
      'Adam': 'pNInz6obpgDQGcFmaJgB', // Deep, clear
      'Sam': 'yoZ06aMxZJJbMf3OFTGL', // Deep, warm
    };
  }
}

/// Model class for ElevenLabs voice
class ElevenLabsVoice {
  final String voiceId;
  final String name;
  final String? previewUrl;
  final String? category;
  final Map<String, dynamic>? settings;
  
  ElevenLabsVoice({
    required this.voiceId,
    required this.name,
    this.previewUrl,
    this.category,
    this.settings,
  });
  
  factory ElevenLabsVoice.fromJson(Map<String, dynamic> json) {
    return ElevenLabsVoice(
      voiceId: json['voice_id'] as String,
      name: json['name'] as String,
      previewUrl: json['preview_url'] as String?,
      category: json['category'] as String?,
      settings: json['settings'] as Map<String, dynamic>?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'voice_id': voiceId,
      'name': name,
      'preview_url': previewUrl,
      'category': category,
      'settings': settings,
    };
  }
}
