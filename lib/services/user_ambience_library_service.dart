import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/user_music_track.dart';

/// Manages user-uploaded background ambience files.
///
/// Files are stored under `<appDocuments>/user_ambience/<uuid>.<ext>`.
/// The track registry is persisted to `<appDocuments>/user_ambience_library.json`.
///
/// [Session.backgroundAmbience] stores the [UserAmbienceLibraryService.sessionKey]
/// (e.g. `"user_ambience:<uuid>"`) to distinguish user tracks from bundled asset names.
class UserAmbienceLibraryService {
  static const _libraryFileName = 'user_ambience_library.json';
  static const _ambienceSubdir = 'user_ambience';
  static const _keyPrefix = 'user_ambience:';

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static Future<File> _libraryFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_libraryFileName');
  }

  static Future<Directory> _ambienceDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final ambienceDir = Directory('${dir.path}/$_ambienceSubdir');
    if (!await ambienceDir.exists()) await ambienceDir.create(recursive: true);
    return ambienceDir;
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

  /// Returns true if [key] represents a user-uploaded ambience track.
  static bool isUserTrackKey(String key) => key.startsWith(_keyPrefix);

  /// Parses the track ID out of a session ambience key like `"user_ambience:<uuid>"`.
  /// Returns null if [key] is not a user ambience track key.
  static String? trackIdFromKey(String key) {
    if (!isUserTrackKey(key)) return null;
    return key.substring(_keyPrefix.length);
  }

  /// Returns all saved user ambience tracks, sorted oldest-first.
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
      debugPrint('Error loading user ambience library: $e');
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

    final ambienceDir = await _ambienceDir();
    await File(sourceFilePath).copy('${ambienceDir.path}/$fileName');

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
    final ambienceDir = await _ambienceDir();
    final path = '${ambienceDir.path}/${track.fileName}';
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

    final ambienceDir = await _ambienceDir();
    final file = File('${ambienceDir.path}/${target.fileName}');
    if (await file.exists()) await file.delete();

    tracks.removeWhere((t) => t.id == trackId);
    await _saveAllTracks(tracks);
  }

  /// Returns how many sessions in [allSessionAmbienceKeys] reference [trackId].
  ///
  /// Pass `sessions.map((s) => s.backgroundAmbience).toList()` as the argument.
  static int countSessionsUsing(
    String trackId,
    List<String> allSessionAmbienceKeys,
  ) {
    final key = sessionKey(trackId);
    return allSessionAmbienceKeys.where((k) => k == key).length;
  }
}
