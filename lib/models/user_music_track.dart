class UserMusicTrack {
  final String id;
  final String displayName;

  /// Stored filename inside the `user_music/` directory, e.g. `<uuid>.mp3`.
  final String fileName;
  final DateTime addedAt;

  const UserMusicTrack({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.addedAt,
  });

  /// The value stored in [Session.backgroundMusic] for this track.
  String get sessionKey => 'user:$id';

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'fileName': fileName,
        'addedAt': addedAt.toIso8601String(),
      };

  factory UserMusicTrack.fromJson(Map<String, dynamic> json) => UserMusicTrack(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        fileName: json['fileName'] as String,
        addedAt: DateTime.parse(json['addedAt'] as String),
      );
}
