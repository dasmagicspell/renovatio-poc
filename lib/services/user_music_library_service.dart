import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/user_music_track.dart';

/// Manages user-uploaded background music files.
///
/// Files are stored under `<appDocuments>/user_music/<uuid>.<ext>`.
/// The track registry is persisted to `<appDocuments>/user_music_library.json`.
///
/// [Session.backgroundMusic] stores the [UserMusicTrack.sessionKey] (e.g.
/// `"user:<uuid>"`) to distinguish user tracks from bundled asset names.
class UserMusicLibraryService {
  static const _libraryFileName = 'user_music_library.json';
  static const _musicSubdir = 'user_music';

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static Future<File> _libraryFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_libraryFileName');
  }

  static Future<Directory> _musicDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final musicDir = Directory('${dir.path}/$_musicSubdir');
    if (!await musicDir.exists()) await musicDir.create(recursive: true);
    return musicDir;
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

  /// Returns all saved user tracks, sorted oldest-first.
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
      print('Error loading user music library: $e');
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

    final musicDir = await _musicDir();
    await File(sourceFilePath).copy('${musicDir.path}/$fileName');

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
    final musicDir = await _musicDir();
    final path = '${musicDir.path}/${track.fileName}';
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

    final musicDir = await _musicDir();
    final file = File('${musicDir.path}/${target.fileName}');
    if (await file.exists()) await file.delete();

    tracks.removeWhere((t) => t.id == trackId);
    await _saveAllTracks(tracks);
  }

  /// Renames [trackId] to [newName] and returns the updated track, or null
  /// if the track doesn't exist.
  static Future<UserMusicTrack?> renameTrack(
    String trackId,
    String newName,
  ) async {
    final tracks = await getAllTracks();
    final idx = tracks.indexWhere((t) => t.id == trackId);
    if (idx == -1) return null;

    final updated = UserMusicTrack(
      id: tracks[idx].id,
      displayName: newName,
      fileName: tracks[idx].fileName,
      addedAt: tracks[idx].addedAt,
    );
    tracks[idx] = updated;
    await _saveAllTracks(tracks);
    return updated;
  }

  /// Returns how many sessions in [allSessionMusicKeys] reference [trackId].
  ///
  /// Pass `sessions.map((s) => s.backgroundMusic).toList()` as the argument.
  static int countSessionsUsing(
    String trackId,
    List<String> allSessionMusicKeys,
  ) {
    final key = 'user:$trackId';
    return allSessionMusicKeys.where((k) => k == key).length;
  }

  /// Parses the track ID out of a session music key like `"user:<uuid>"`.
  /// Returns null if [key] is not a user track key.
  static String? trackIdFromKey(String key) {
    if (!key.startsWith('user:')) return null;
    return key.substring('user:'.length);
  }

  /// Returns true if [key] represents a user-uploaded track.
  static bool isUserTrackKey(String key) => key.startsWith('user:');
}
