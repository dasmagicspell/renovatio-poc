import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/binaural_preset.dart';
import '../models/session.dart';
import 'ffmpeg_executor.dart';

class BinauralAudioGenerator {
  static const int _durationSeconds = 2700; // 45 minutes (default for activities not in short list)
  static const int _shortDurationSeconds = 30; // 30 seconds for loopable activities
  /// Loop length for per-session soundscapes (matches [generateSessionBinauralClip] default).
  static const int sessionLoopDurationSeconds = 30;
  static const int _sampleRate = 44100;
  static const String _audioFormat = 'mp3';
  
  // Activities that should use 30-second loopable files (all activities)
  static const Set<String> _shortDurationActivities = {
    'relax',
    'sleep',
    'exercise',
    'meditate',
    'focus',
    'study',
    'anxiety relief',
    'energy boost',
  };
  
  /// Get duration for a specific activity
  static int _getDurationForActivity(String activityName) {
    final activityNameLower = activityName.toLowerCase();
    if (_shortDurationActivities.contains(activityNameLower)) {
      return _shortDurationSeconds;
    }
    return _durationSeconds;
  }
  
  /// Generate binaural audio files for an activity
  /// Returns a map of preset names to file paths
  static Future<Map<String, String>> generateAudioForActivity({
    required String activityName,
    required Map<String, BinauralPreset> presets,
    Function(String preset, String status)? onProgress,
  }) async {
    final results = <String, String>{};
    final activityNameLower = activityName.toLowerCase();
    final duration = _getDurationForActivity(activityName);
    
    // Get documents directory
    final documentsDir = await getApplicationDocumentsDirectory();
    final binauralDir = Directory('${documentsDir.path}/binaural/$activityNameLower');
    
    // Create directory if it doesn't exist
    if (!await binauralDir.exists()) {
      await binauralDir.create(recursive: true);
    }
    
    // Generate audio for each preset (base, increase, decrease)
    for (var entry in presets.entries) {
      final presetName = entry.key; // base, increase, or decrease
      final preset = entry.value;
      
      onProgress?.call(presetName, 'Generating...');
      
      final fileName = '${activityNameLower}_$presetName.$_audioFormat';
      final outputPath = '${binauralDir.path}/$fileName';
      
      try {
        final success = await _generateBinauralAudio(
          leftFrequency: preset.leftFrequency.toDouble(),
          rightFrequency: preset.rightFrequency.toDouble(),
          outputPath: outputPath,
          durationSeconds: duration,
        );
        
        if (success) {
          results[presetName] = outputPath;
          onProgress?.call(presetName, 'Completed');
        } else {
          onProgress?.call(presetName, 'Failed');
        }
      } catch (e) {
        print('Error generating audio for $presetName: $e');
        onProgress?.call(presetName, 'Error: $e');
      }
    }
    
    return results;
  }

  static const String _sessionBinauralSubdir = 'binaural_sessions';

  /// Relative path under app documents: `binaural_sessions/<sessionId>.mp3`.
  /// Use the same [sessionId] as [Session.id] and [generateSessionBinauralClip].
  static String relativePathForSessionBinauralClip(String sessionId) =>
      '$_sessionBinauralSubdir/$sessionId.$_audioFormat';

  /// Path to the looped MP3 for a [Session] created with custom base/beat frequencies.
  static Future<String> sessionBinauralClipFilePath(String sessionId) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${documentsDir.path}/$_sessionBinauralSubdir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return '${dir.path}/$sessionId.$_audioFormat';
  }

  /// Resolves the absolute path to the session binaural clip on disk.
  /// Prefers [Session.binauralClipRelativePath] when set (saved at creation time).
  static Future<String> absolutePathForSessionBinauralClip(Session session) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final rel = session.binauralClipRelativePath?.trim();
    if (rel != null && rel.isNotEmpty) {
      return '${documentsDir.path}/$rel';
    }
    if (session.hasCustomBinauralClip) {
      return sessionBinauralClipFilePath(session.id);
    }
    throw StateError('Session has no custom binaural clip path');
  }

  /// Generates a short stereo binaural clip (left = [baseFrequencyHz], right = base + beat)
  /// for playback during a session; file name is tied to [sessionId].
  static Future<bool> generateSessionBinauralClip({
    required String sessionId,
    required double baseFrequencyHz,
    required double beatFrequencyHz,
    int durationSeconds = sessionLoopDurationSeconds,
  }) async {
    final outputPath = await sessionBinauralClipFilePath(sessionId);
    return _generateBinauralAudio(
      leftFrequency: baseFrequencyHz,
      rightFrequency: baseFrequencyHz + beatFrequencyHz,
      outputPath: outputPath,
      durationSeconds: durationSeconds,
    );
  }
  
  /// Generate a single binaural audio file using FFmpeg
  /// For seamless looping, the duration should be an exact number of cycles
  /// Sine waves naturally loop seamlessly if the duration is a multiple of the period
  static Future<bool> _generateBinauralAudio({
    required double leftFrequency,
    required double rightFrequency,
    required String outputPath,
    required int durationSeconds,
  }) async {
    try {
      // FFmpeg command to generate binaural beats:
      // - Generate two sine waves (left and right channels)
      // - Merge them into a stereo audio file
      // - Encode as MP3: -f mp3 forces the muxer; -c:a libmp3lame (needs ffmpeg_kit with GPL/audio)
      // - For seamless looping, we ensure the sine waves complete full cycles
      
      final leftF = leftFrequency.toString();
      final rightF = rightFrequency.toString();
      final command = 
          '-f lavfi -i "sine=frequency=$leftF:duration=$durationSeconds:sample_rate=$_sampleRate" '
          '-f lavfi -i "sine=frequency=$rightF:duration=$durationSeconds:sample_rate=$_sampleRate" '
          '-filter_complex "[0:a][1:a]amerge=inputs=2,channelmap=0|1[out]" '
          '-map "[out]" '
          '-ar $_sampleRate '
          '-ac 2 '
          '-c:a libmp3lame -b:a 192k -f mp3 '
          '-y '
          '"$outputPath"';
      
      print('FFmpeg command: $command');
      print('Generating ${durationSeconds}s audio file (will loop seamlessly)');
      
      final result = await FFmpegExecutor.execute(command);

      if (result.isSuccess) {
        // Verify file was created
        final file = File(outputPath);
        if (await file.exists()) {
          final fileSize = await file.length();
          final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
          print('Audio file generated successfully: $outputPath (${fileSizeMB} MB)');
          return true;
        } else {
          print('Error: File was not created at $outputPath');
          return false;
        }
      } else {
        print('FFmpeg error: ${result.output}');
        return false;
      }
    } catch (e) {
      print('Exception generating binaural audio: $e');
      return false;
    }
  }
  
  /// Get the directory path where binaural audio files are stored
  static Future<String> getBinauralAudioDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    return '${documentsDir.path}/binaural';
  }
  
  /// Get the full path to a generated audio file
  static Future<String?> getAudioFilePath({
    required String activityName,
    required String presetName,
  }) async {
    final activityNameLower = activityName.toLowerCase();
    final documentsDir = await getApplicationDocumentsDirectory();
    final filePath = '${documentsDir.path}/binaural/$activityNameLower/${activityNameLower}_$presetName.$_audioFormat';
    
    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }
    return null;
  }
  
  /// Check if audio files exist for an activity
  static Future<bool> audioFilesExist(String activityName) async {
    final activityNameLower = activityName.toLowerCase();
    final documentsDir = await getApplicationDocumentsDirectory();
    final binauralDir = Directory('${documentsDir.path}/binaural/$activityNameLower');
    
    if (!await binauralDir.exists()) {
      return false;
    }
    
    // Check if all three preset files exist
    final presets = ['base', 'increase', 'decrease'];
    for (final preset in presets) {
      final filePath = '${binauralDir.path}/${activityNameLower}_$preset.$_audioFormat';
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }
    }
    
    return true;
  }
}

