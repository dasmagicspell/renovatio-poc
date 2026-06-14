import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/user_profile.dart';

class UserProfileService {
  static const String _fileName = 'user_profile.json';

  static Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  static Future<UserProfile> getProfile() async {
    try {
      final file = await _getFile();

      if (!await file.exists()) {
        return const UserProfile();
      }

      final contents = await file.readAsString();
      if (contents.isEmpty) {
        return const UserProfile();
      }

      final json = jsonDecode(contents) as Map<String, dynamic>;
      return UserProfile.fromJson(json);
    } catch (e) {
      print('Error loading user profile: $e');
      return const UserProfile();
    }
  }

  static Future<void> saveProfile(UserProfile profile) async {
    try {
      final file = await _getFile();
      await file.writeAsString(jsonEncode(profile.toJson()));
    } catch (e) {
      print('Error saving user profile: $e');
      rethrow;
    }
  }
}
