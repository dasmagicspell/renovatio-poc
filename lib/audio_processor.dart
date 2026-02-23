import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class AudioProcessor {
  static Future<String?> mergeAudioTracks({
    required List<String> inputFiles,
    required List<double> volumes,
    required List<double> speeds,
    required List<double> pitches,
    required String outputFileName,
  }) async {
    List<String> tempFiles = [];
    
    try {
      // Copy asset files to temp directory
      tempFiles = await _copyAssetsToTemp(inputFiles);
      
      // Get the documents directory for output
      final directory = await getApplicationDocumentsDirectory();
      final outputPath = '${directory.path}/$outputFileName';
      
      // Build FFmpeg command for merging tracks with effects
      String command = _buildFFmpegCommand(
        inputFiles: tempFiles,
        volumes: volumes,
        speeds: speeds,
        pitches: pitches,
        outputPath: outputPath,
      );
      
      print('FFmpeg command: $command');
      
      // Execute FFmpeg command
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        print('Audio merge successful: $outputPath');
        return outputPath;
      } else {
        final logs = await session.getLogs();
        print('FFmpeg error: ${logs.map((log) => log.getMessage()).join('\n')}');
        return null;
      }
    } catch (e) {
      print('Error merging audio tracks: $e');
      return null;
    } finally {
      // Clean up temp files
      await _cleanupTempFiles(tempFiles);
    }
  }
  
  static Future<List<String>> _copyAssetsToTemp(List<String> assetPaths) async {
    List<String> tempFiles = [];
    
    try {
      // Get temp directory
      final tempDir = await getTemporaryDirectory();
      
      for (int i = 0; i < assetPaths.length; i++) {
        final assetPath = assetPaths[i];
        final fileName = 'temp_audio_$i${_getFileExtension(assetPath)}';
        final tempFile = File('${tempDir.path}/$fileName');
        
        // Copy asset to temp file
        final byteData = await rootBundle.load(assetPath);
        await tempFile.writeAsBytes(byteData.buffer.asUint8List());
        
        tempFiles.add(tempFile.path);
        print('Copied asset to temp: ${tempFile.path}');
      }
      
      return tempFiles;
    } catch (e) {
      print('Error copying assets to temp: $e');
      // Clean up any partially created temp files
      await _cleanupTempFiles(tempFiles);
      rethrow;
    }
  }
  
  static String _getFileExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot != -1 && lastDot < filePath.length - 1) {
      return filePath.substring(lastDot);
    }
    return '.m4a'; // Default extension (better for your use case)
  }
  
  static Future<void> _cleanupTempFiles(List<String> tempFiles) async {
    for (String tempFile in tempFiles) {
      try {
        final file = File(tempFile);
        if (await file.exists()) {
          await file.delete();
          print('Cleaned up temp file: $tempFile');
        }
      } catch (e) {
        print('Error cleaning up temp file $tempFile: $e');
      }
    }
  }
  
  static String _buildFFmpegCommand({
    required List<String> inputFiles,
    required List<double> volumes,
    required List<double> speeds,
    required List<double> pitches,
    required String outputPath,
  }) {
    // Start building the command
    String command = '';
    
    // Add all input files first
    for (int i = 0; i < inputFiles.length; i++) {
      command += '-i "${inputFiles[i]}" ';
    }
    
    // Build filter complex with effects
    command += '-filter_complex "';
    
    // Apply effects to each track
    for (int i = 0; i < inputFiles.length; i++) {
      double volume = volumes[i].clamp(0.0, 10.0); // Clamp volume to reasonable range
      double speed = speeds[i].clamp(0.25, 4.0);   // Clamp speed to reasonable range
      double pitch = pitches[i].clamp(0.5, 2.0);   // Clamp pitch to reasonable range
      
      // Use atempo for speed and asetrate for pitch
      // atempo range is 0.5 to 2.0, so we need to handle larger values
      String tempoFilter = '';
      if (speed > 2.0) {
        // For speeds > 2.0, chain multiple atempo filters
        int tempoChains = (speed / 2.0).ceil();
        for (int j = 0; j < tempoChains; j++) {
          double currentTempo = j == tempoChains - 1 ? speed / (2.0 * tempoChains) : 2.0;
          tempoFilter += 'atempo=$currentTempo,';
        }
      } else if (speed < 0.5) {
        // For speeds < 0.5, chain multiple atempo filters
        int tempoChains = (0.5 / speed).ceil();
        for (int j = 0; j < tempoChains; j++) {
          double currentTempo = j == tempoChains - 1 ? speed * tempoChains : 0.5;
          tempoFilter += 'atempo=$currentTempo,';
        }
      } else {
        tempoFilter = 'atempo=$speed,';
      }
      
      // Apply volume, speed, and pitch to each track
      command += '[${i}:a]volume=$volume,${tempoFilter}asetrate=44100*$pitch[track$i];';
    }
    
    // Mix all processed tracks together
    for (int i = 0; i < inputFiles.length; i++) {
      command += '[track$i]';
    }
    command += 'amix=inputs=${inputFiles.length}:duration=longest[out]" ';
    
    // Output settings
    command += '-map "[out]" -c:a aac -b:a 192k "$outputPath"';
    
    return command;
  }
  
  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }
  
  static Future<List<String>> getOutputFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync()
          .where((file) => file.path.endsWith('.mp3') || file.path.endsWith('.wav') || file.path.endsWith('.m4a'))
          .map((file) => file.path)
          .toList();
      return files;
    } catch (e) {
      print('Error getting output files: $e');
      return [];
    }
  }
  
  /// Export merged audio tracks with duration limit and MP3 output
  /// [inputFiles] - List of audio file paths (can be temp files or regular files)
  /// [volumes] - Volume levels for each track (0.0-1.0)
  /// [speeds] - Speed multipliers for each track
  /// [pitches] - Pitch multipliers for each track (not used in this version)
  /// [durationSeconds] - Target duration in seconds (longer tracks will be cut, shorter will loop)
  /// [outputFileName] - Name for the output file
  static Future<String?> exportMergedAudio({
    required List<String> inputFiles,
    required List<double> volumes,
    required List<double> speeds,
    required List<double> pitches,
    required int durationSeconds,
    required String outputFileName,
  }) async {
    if (inputFiles.isEmpty) {
      throw Exception('No input files provided');
    }
    
    if (inputFiles.length != volumes.length || 
        inputFiles.length != speeds.length || 
        inputFiles.length != pitches.length) {
      throw Exception('Input files and settings arrays must have the same length');
    }
    
    List<String> tempFiles = [];
    
    try {
      // Copy files to temp if they're assets, otherwise use as-is
      tempFiles = await _prepareFilesForExport(inputFiles);
      
      // Output goes to app's documents directory (sandboxed, not user-browsable by default):
      // - iOS: /var/mobile/Containers/Data/Application/{UUID}/Documents/
      // - Android: /data/data/{package}/app_flutter/ or similar app-specific path
      // Use Share after export so the user can save to Files / Downloads or share elsewhere.
      final directory = await getApplicationDocumentsDirectory();
      final outputPath = '${directory.path}/$outputFileName';
      
      // Build FFmpeg command for merging with duration control
      String command = _buildExportFFmpegCommand(
        inputFiles: tempFiles,
        volumes: volumes,
        speeds: speeds,
        pitches: pitches,
        durationSeconds: durationSeconds,
        outputPath: outputPath,
      );
      
      print('FFmpeg export command: $command');
      
      // Execute FFmpeg command
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        // Verify file was created
        final file = File(outputPath);
        if (await file.exists()) {
          final fileSize = await file.length();
          print('✅ Audio export successful: $outputPath (${fileSize} bytes)');
          return outputPath;
        } else {
          print('❌ Export file was not created at $outputPath');
          return null;
        }
      } else {
        final logs = await session.getLogs();
        final errorLogs = logs.map((log) => log.getMessage()).join('\n');
        print('❌ FFmpeg export error: $errorLogs');
        return null;
      }
    } catch (e) {
      print('❌ Error exporting audio: $e');
      return null;
    } finally {
      // Clean up temp files (only if we created them)
      await _cleanupTempFiles(tempFiles);
    }
  }
  
  /// Prepare files for export - copy assets to temp, use regular files as-is
  static Future<List<String>> _prepareFilesForExport(List<String> filePaths) async {
    List<String> preparedFiles = [];
    final tempDir = await getTemporaryDirectory();
    
    for (int i = 0; i < filePaths.length; i++) {
      final filePath = filePaths[i];
      final file = File(filePath);
      
      // If file exists and is not an asset path, use it directly
      if (await file.exists() && !filePath.startsWith('assets/')) {
        preparedFiles.add(filePath);
        print('Using existing file: $filePath');
      } else {
        // Try to load as asset and copy to temp
        try {
          final byteData = await rootBundle.load(filePath);
          final fileName = 'export_audio_$i${_getFileExtension(filePath)}';
          final tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(byteData.buffer.asUint8List());
          preparedFiles.add(tempFile.path);
          print('Copied asset to temp: ${tempFile.path}');
        } catch (e) {
          // If it's not an asset, try as regular file
          if (await file.exists()) {
            preparedFiles.add(filePath);
          } else {
            throw Exception('File not found: $filePath');
          }
        }
      }
    }
    
    return preparedFiles;
  }
  
  /// Build FFmpeg command for export with duration control and MP3 output
  static String _buildExportFFmpegCommand({
    required List<String> inputFiles,
    required List<double> volumes,
    required List<double> speeds,
    required List<double> pitches,
    required int durationSeconds,
    required String outputPath,
  }) {
    String command = '';
    
    // Add all input files
    for (int i = 0; i < inputFiles.length; i++) {
      command += '-i "${inputFiles[i]}" ';
    }
    
    // Build filter complex
    command += '-filter_complex "';
    
    // Process each track: apply volume, speed, and loop/cut to duration
    for (int i = 0; i < inputFiles.length; i++) {
      double volume = volumes[i].clamp(0.0, 10.0);
      double speed = speeds[i].clamp(0.25, 4.0);
      
      // Build tempo filter for speed
      String tempoFilter = '';
      if (speed > 2.0) {
        int tempoChains = (speed / 2.0).ceil();
        for (int j = 0; j < tempoChains; j++) {
          double currentTempo = j == tempoChains - 1 ? speed / (2.0 * tempoChains) : 2.0;
          tempoFilter += 'atempo=$currentTempo,';
        }
      } else if (speed < 0.5) {
        int tempoChains = (0.5 / speed).ceil();
        for (int j = 0; j < tempoChains; j++) {
          double currentTempo = j == tempoChains - 1 ? speed * tempoChains : 0.5;
          tempoFilter += 'atempo=$currentTempo,';
        }
      } else {
        tempoFilter = 'atempo=$speed,';
      }
      
      // Apply volume and speed, then loop/cut to exact duration
      // aloop=loop=-1:size=2e+09 loops the audio, then atrim cuts to exact duration
      command += '[${i}:a]volume=$volume,${tempoFilter}aloop=loop=-1:size=2e+09,atrim=0:$durationSeconds[track$i];';
    }
    
    // Mix all processed tracks together
    for (int i = 0; i < inputFiles.length; i++) {
      command += '[track$i]';
    }
    command += 'amix=inputs=${inputFiles.length}:duration=first:dropout_transition=2[out]" ';
    
    // Output settings - MP3 format
    command += '-map "[out]" -c:a libmp3lame -b:a 192k -ar 44100 "$outputPath"';
    
    return command;
  }
}
