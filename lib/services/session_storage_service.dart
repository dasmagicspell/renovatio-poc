import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/session.dart';

class SessionStorageService {
  static const String _fileName = 'sessions.json';
  
  /// Get the file path for storing sessions
  static Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }
  
  /// Save a session to local storage
  static Future<void> saveSession(Session session) async {
    try {
      final sessions = await getAllSessions();
      sessions.add(session);
      await _saveAllSessions(sessions);
    } catch (e) {
      print('Error saving session: $e');
      rethrow;
    }
  }
  
  /// Get all saved sessions
  static Future<List<Session>> getAllSessions() async {
    try {
      final file = await _getFile();
      
      if (!await file.exists()) {
        return [];
      }
      
      final contents = await file.readAsString();
      if (contents.isEmpty) {
        return [];
      }
      
      final List<dynamic> jsonList = json.decode(contents);
      return jsonList.map((json) => Session.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error loading sessions: $e');
      return [];
    }
  }
  
  /// Save all sessions to file
  static Future<void> _saveAllSessions(List<Session> sessions) async {
    try {
      final file = await _getFile();
      final jsonList = sessions.map((session) => session.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      print('Error saving all sessions: $e');
      rethrow;
    }
  }
  
  /// Delete a session by ID
  static Future<void> deleteSession(String sessionId) async {
    try {
      final sessions = await getAllSessions();
      sessions.removeWhere((session) => session.id == sessionId);
      await _saveAllSessions(sessions);
    } catch (e) {
      print('Error deleting session: $e');
      rethrow;
    }
  }
  
  /// Get a session by ID
  static Future<Session?> getSessionById(String sessionId) async {
    try {
      final sessions = await getAllSessions();
      return sessions.firstWhere(
        (session) => session.id == sessionId,
        orElse: () => throw Exception('Session not found'),
      );
    } catch (e) {
      return null;
    }
  }
}

