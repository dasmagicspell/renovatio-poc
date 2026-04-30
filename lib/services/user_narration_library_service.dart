import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/user_music_track.dart';

/// Manages user-uploaded narration audio files.
///
/// Files are stored under `<appDocuments>/user_narration/<uuid>.<ext>`.
/// The track registry is persisted to `<appDocuments>/user_narration_library.json`.
///
/// [Session.narrationAudioKey] stores the [UserNarrationLibraryService.sessionKey]
/// (e.g. `"user_narration:<uuid>"`) to use the uploaded file instead of
/// generating TTS via ElevenLabs.
class UserNarrationLibraryService {
  static const _libraryFileName = 'user_narration_library.json';
  static const _narrationSubdir = 'user_narration';
  static const _keyPrefix = 'user_narration:';

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static Future<File> _libraryFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_libraryFileName');
  }

  static Future<Directory> _narrationDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final narrationDir = Directory('${dir.path}/$_narrationSubdir');
    if (!await narrationDir.exists()) await narrationDir.create(recursive: true);
    return narrationDir;
  }

  static Future<void> _saveAllTracks(List<UserMusicTrack> tracks) async {
    final file = await _libraryFile();
    await file.writeAsString(
      json.encode(tracks.map((t) => t.toJson()).toList()),
    );
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the session key for a given track ID.
  static String sessionKey(String trackId) => '$_keyPrefix$trackId';

  /// Returns true if [key] represents a user-uploaded narration track.
  static bool isUserTrackKey(String key) => key.startsWith(_keyPrefix);

  /// Parses the track ID out of a narration key like `"user_narration:<uuid>"`.
  /// Returns null if [key] is not a user narration track key.
  static String? trackIdFromKey(String key) {
    if (!isUserTrackKey(key)) return null;
    return key.substring(_keyPrefix.length);
  }

  /// Returns all saved user narration tracks, sorted oldest-first.
  static Future<List<UserMusicTrack>> getAllTracks() async {
    try {
      final file = await _libraryFile();
      if (!await file.exists()) return [];
      final contents = await file.readAsString();
      if (contents.isEmpty) return [];
      final list = json.decode(contents) as List<dynamic>;
      return list
          .map((e) => UserMusicTrack.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading user narration library: $e');
      return [];
    }
  }

  /// Returns a single track by [trackId], or null if not found.
  static Future<UserMusicTrack?> getTrackById(String trackId) async {
    final tracks = await getAllTracks();
    try {
      return tracks.firstWhere((t) => t.id == trackId);
    } catch (_) {
      return null;
    }
  }

  /// Copies [sourceFilePath] into app storage and registers the track.
  ///
  /// The file is renamed to `<uuid>.<ext>` to avoid collisions.
  /// Returns the newly created [UserMusicTrack].
  static Future<UserMusicTrack> addTrack({
    required String sourceFilePath,
    required String displayName,
  }) async {
    final id = const Uuid().v4();
    final dotIndex = sourceFilePath.lastIndexOf('.');
    final ext = dotIndex != -1 ? sourceFilePath.substring(dotIndex) : '.mp3';
    final fileName = '$id$ext';

    final narrationDir = await _narrationDir();
    await File(sourceFilePath).copy('${narrationDir.path}/$fileName');

    final track = UserMusicTrack(
      id: id,
      displayName: displayName,
      fileName: fileName,
      addedAt: DateTime.now(),
    );

    final tracks = await getAllTracks();
    tracks.add(track);
    await _saveAllTracks(tracks);

    return track;
  }

  /// Returns the absolute path to [trackId]'s audio file, or null if the
  /// track or its file cannot be found.
  static Future<String?> resolveFilePath(String trackId) async {
    final track = await getTrackById(trackId);
    if (track == null) return null;
    final narrationDir = await _narrationDir();
    final path = '${narrationDir.path}/${track.fileName}';
    if (!await File(path).exists()) return null;
    return path;
  }

  /// Deletes the track from the registry and removes its file from disk.
  static Future<void> deleteTrack(String trackId) async {
    final tracks = await getAllTracks();
    UserMusicTrack? target;
    try {
      target = tracks.firstWhere((t) => t.id == trackId);
    } catch (_) {
      return;
    }

    final narrationDir = await _narrationDir();
    final file = File('${narrationDir.path}/${target.fileName}');
    if (await file.exists()) await file.delete();

    tracks.removeWhere((t) => t.id == trackId);
    await _saveAllTracks(tracks);
  }

  /// Returns how many sessions in [allSessionNarrationKeys] reference [trackId].
  ///
  /// Pass `sessions.map((s) => s.narrationAudioKey ?? '').toList()` as the argument.
  static int countSessionsUsing(
    String trackId,
    List<String> allSessionNarrationKeys,
  ) {
    final key = sessionKey(trackId);
    return allSessionNarrationKeys.where((k) => k == key).length;
  }
}
