import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class FFmpegExecutionResult {
  final bool isSuccess;
  final int? exitCode;
  final String output;

  const FFmpegExecutionResult({
    required this.isSuccess,
    this.exitCode,
    this.output = '',
  });
}

class FFmpegExecutor {
  static Future<FFmpegExecutionResult> execute(String command) async {
    // ffmpeg_kit_flutter_new does not implement Windows/Linux channels.
    if (Platform.isWindows || Platform.isLinux) {
      return _executeWithSystemFfmpeg(command);
    }

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    final logs = await session.getLogs();
    final output = logs.map((log) => log.getMessage()).join('\n');

    return FFmpegExecutionResult(
      isSuccess: ReturnCode.isSuccess(returnCode),
      exitCode: returnCode?.getValue(),
      output: output,
    );
  }

  static Future<FFmpegExecutionResult> _executeWithSystemFfmpeg(
    String command,
  ) async {
    try {
      final args = _splitCommandArgs(command);
      final result = await Process.run(
        'ffmpeg',
        args,
        runInShell: true,
      );

      final stdoutText = result.stdout?.toString() ?? '';
      final stderrText = result.stderr?.toString() ?? '';
      final combinedOutput = [stdoutText, stderrText]
          .where((text) => text.isNotEmpty)
          .join('\n');

      return FFmpegExecutionResult(
        isSuccess: result.exitCode == 0,
        exitCode: result.exitCode,
        output: combinedOutput,
      );
    } on ProcessException catch (e) {
      return FFmpegExecutionResult(
        isSuccess: false,
        output:
            'FFmpeg executable was not found. Install ffmpeg and make sure it is in PATH. Original error: $e',
      );
    }
  }

  static List<String> _splitCommandArgs(String command) {
    final args = <String>[];
    final current = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < command.length; i++) {
      final char = command[i];

      if (char == '"') {
        inQuotes = !inQuotes;
        continue;
      }

      if (char == ' ' && !inQuotes) {
        if (current.isNotEmpty) {
          args.add(current.toString());
          current.clear();
        }
        continue;
      }

      current.write(char);
    }

    if (current.isNotEmpty) {
      args.add(current.toString());
    }

    return args;
  }
}
