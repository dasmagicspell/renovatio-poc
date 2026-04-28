import 'dart:io';
import 'dart:typed_data';

/// Generates silent WAV audio files using pure Dart — no external tools needed.
///
/// Output format: 44100 Hz, mono, 16-bit signed PCM (standard WAV).
class SilenceGenerator {
  static const int _sampleRate = 44100;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;
  static const int _bytesPerSample = _bitsPerSample ~/ 8;

  /// Writes a silent WAV file to [filePath] with the given [duration].
  static Future<void> generate({
    required String filePath,
    required Duration duration,
  }) async {
    final numSamples =
        (_sampleRate * duration.inMilliseconds / 1000).round();
    final dataSize = numSamples * _channels * _bytesPerSample;

    final builder = BytesBuilder(copy: false);
    builder.add(_buildWavHeader(dataSize));
    builder.add(Uint8List(dataSize)); // zero-filled = silence

    await File(filePath).writeAsBytes(builder.toBytes());
  }

  static Uint8List _buildWavHeader(int dataSize) {
    final header = ByteData(44);
    final byteRate = _sampleRate * _channels * _bytesPerSample;
    final blockAlign = _channels * _bytesPerSample;

    _writeAscii(header, 0, 'RIFF');
    header.setUint32(4, 36 + dataSize, Endian.little);
    _writeAscii(header, 8, 'WAVE');
    _writeAscii(header, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // fmt chunk size
    header.setUint16(20, 1, Endian.little);  // PCM audio format
    header.setUint16(22, _channels, Endian.little);
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, _bitsPerSample, Endian.little);
    _writeAscii(header, 36, 'data');
    header.setUint32(40, dataSize, Endian.little);

    return header.buffer.asUint8List();
  }

  static void _writeAscii(ByteData data, int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }
}
