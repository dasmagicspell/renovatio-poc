import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import '../models/binaural_preset.dart';

class BinauralAudioGenerator {
  static const int _durationSeconds = 2700; // 45 minutes
  static const int _sampleRate = 44100;
  static const String _audioFormat = 'wav';
  
  /// Generate binaural audio files for an activity
  /// Returns a map of preset names to file paths
  static Future<Map<String, String>> generateAudioForActivity({
    required String activityName,
    required Map<String, BinauralPreset> presets,
    Function(String preset, String status)? onProgress,
  }) async {
    final results = <String, String>{};
    final activityNameLower = activityName.toLowerCase();
    
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
          leftFrequency: preset.leftFrequency,
          rightFrequency: preset.rightFrequency,
          outputPath: outputPath,
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
  
  /// Generate a single binaural audio file using FFmpeg
  static Future<bool> _generateBinauralAudio({
    required int leftFrequency,
    required int rightFrequency,
    required String outputPath,
  }) async {
    try {
      // FFmpeg command to generate binaural beats:
      // - Generate two sine waves (left and right channels)
      // - Merge them into a stereo audio file
      // - Set sample rate to 44100 Hz, 16-bit, WAV format
      
      final command = 
          '-f lavfi -i "sine=frequency=$leftFrequency:duration=$_durationSeconds:sample_rate=$_sampleRate" '
          '-f lavfi -i "sine=frequency=$rightFrequency:duration=$_durationSeconds:sample_rate=$_sampleRate" '
          '-filter_complex "[0:a][1:a]amerge=inputs=2,channelmap=0|1[out]" '
          '-map "[out]" '
          '-ar $_sampleRate '
          '-ac 2 '
          '-sample_fmt s16 '
          '-y '
          '"$outputPath"';
      
      print('FFmpeg command: $command');
      
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        // Verify file was created
        final file = File(outputPath);
        if (await file.exists()) {
          final fileSize = await file.length();
          print('Audio file generated successfully: $outputPath (${fileSize} bytes)');
          return true;
        } else {
          print('Error: File was not created at $outputPath');
          return false;
        }
      } else {
        final logs = await session.getLogs();
        final errorLogs = logs.map((log) => log.getMessage()).join('\n');
        print('FFmpeg error: $errorLogs');
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

