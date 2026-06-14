import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/soundscape_defaults.dart';

class SoundscapeDefaultsService {
  static const String _fileName = 'soundscape_defaults.json';

  static Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  static Future<SoundscapeDefaults> getDefaults() async {
    try {
      final file = await _getFile();

      if (!await file.exists()) {
        return SoundscapeDefaults.standard;
      }

      final contents = await file.readAsString();
      if (contents.isEmpty) {
        return SoundscapeDefaults.standard;
      }

      final json = jsonDecode(contents) as Map<String, dynamic>;
      return SoundscapeDefaults.fromJson(json);
    } catch (e) {
      print('Error loading soundscape defaults: $e');
      return SoundscapeDefaults.standard;
    }
  }

  static Future<void> saveDefaults(SoundscapeDefaults defaults) async {
    try {
      final file = await _getFile();
      await file.writeAsString(jsonEncode(defaults.toJson()));
    } catch (e) {
      print('Error saving soundscape defaults: $e');
      rethrow;
    }
  }
}
