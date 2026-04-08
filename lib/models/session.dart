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
    );
  }

  // Format duration for display
  String get formattedDuration {
    if (durationMinutes == 60) {
      return '1 hour';
    } else {
      return '$durationMinutes minutes';
    }
  }
}

