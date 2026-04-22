class Session {
  final String id;
  final String name;
  final String activity;
  final int durationMinutes;
  final String backgroundMusic;
  final String backgroundAmbience;
  final String narrationText;
  final String? narrationVoiceId;
  final DateTime createdAt;

  /// When set with [binauralBeatFrequencyHz], playback uses a per-session
  /// generated clip instead of preset JSON assets.
  final double? binauralBaseFrequencyHz;
  final double? binauralBeatFrequencyHz;

  /// Path under app documents, e.g. `binaural_sessions/<uuid>.mp3`, set at creation
  /// so playback uses the same file name that was written (avoids id/path drift).
  final String? binauralClipRelativePath;

  /// Per-layer playback volumes (0.0–1.0), set during soundscape creation.
  final double binauralVolume;
  final double backgroundMusicVolume;
  final double ambienceVolume;
  final double narrationVolume;

  /// Per-layer enabled flags, set during soundscape creation.
  final bool goalEnabled;
  final bool musicEnabled;
  final bool ambienceEnabled;
  final bool narrationEnabled;

  Session({
    required this.id,
    required this.name,
    required this.activity,
    required this.durationMinutes,
    required this.backgroundMusic,
    required this.backgroundAmbience,
    required this.narrationText,
    this.narrationVoiceId,
    required this.createdAt,
    this.binauralBaseFrequencyHz,
    this.binauralBeatFrequencyHz,
    this.binauralClipRelativePath,
    this.binauralVolume = 0.8,
    this.backgroundMusicVolume = 0.1,
    this.ambienceVolume = 0.1,
    this.narrationVolume = 0.35,
    this.goalEnabled = true,
    this.musicEnabled = true,
    this.ambienceEnabled = true,
    this.narrationEnabled = true,
  });

  bool get hasCustomBinauralClip =>
      binauralBaseFrequencyHz != null && binauralBeatFrequencyHz != null;

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'activity': activity,
      'durationMinutes': durationMinutes,
      'backgroundMusic': backgroundMusic,
      'backgroundAmbience': backgroundAmbience,
      'narrationText': narrationText,
      'narrationVoiceId': narrationVoiceId,
      'createdAt': createdAt.toIso8601String(),
      'binauralBaseFrequencyHz': binauralBaseFrequencyHz,
      'binauralBeatFrequencyHz': binauralBeatFrequencyHz,
      'binauralClipRelativePath': binauralClipRelativePath,
      'binauralVolume': binauralVolume,
      'backgroundMusicVolume': backgroundMusicVolume,
      'ambienceVolume': ambienceVolume,
      'narrationVolume': narrationVolume,
      'goalEnabled': goalEnabled,
      'musicEnabled': musicEnabled,
      'ambienceEnabled': ambienceEnabled,
      'narrationEnabled': narrationEnabled,
    };
  }

  // Create from JSON
  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      name: json['name'] as String,
      activity: json['activity'] as String,
      durationMinutes: json['durationMinutes'] as int,
      backgroundMusic: json['backgroundMusic'] as String,
      backgroundAmbience: json['backgroundAmbience'] as String? ?? 'None',
      narrationText: json['narrationText'] as String? ?? '',
      narrationVoiceId: json['narrationVoiceId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      binauralBaseFrequencyHz: (json['binauralBaseFrequencyHz'] as num?)?.toDouble(),
      binauralBeatFrequencyHz: (json['binauralBeatFrequencyHz'] as num?)?.toDouble(),
      binauralClipRelativePath: json['binauralClipRelativePath'] as String?,
      binauralVolume: (json['binauralVolume'] as num?)?.toDouble() ?? 0.8,
      backgroundMusicVolume: (json['backgroundMusicVolume'] as num?)?.toDouble() ?? 0.1,
      ambienceVolume: (json['ambienceVolume'] as num?)?.toDouble() ?? 0.1,
      narrationVolume: (json['narrationVolume'] as num?)?.toDouble() ?? 0.35,
      goalEnabled: json['goalEnabled'] as bool? ?? true,
      musicEnabled: json['musicEnabled'] as bool? ?? true,
      ambienceEnabled: json['ambienceEnabled'] as bool? ?? true,
      narrationEnabled: json['narrationEnabled'] as bool? ?? true,
    );
  }

  // Format duration for display
  String get formattedDuration {
    if (durationMinutes == 60) {
      return '1 hour';
    }
    if (durationMinutes == 1) {
      return '1 minute';
    }
    return '$durationMinutes minutes';
  }
}

