class SoundscapeDefaults {
  final String? activity;
  final double durationMinutes;
  final double binauralVolume;
  final double musicVolume;
  final double ambienceVolume;
  final double narrationVolume;
  final String? backgroundMusic;
  final String? backgroundAmbience;
  final String? narrationVoiceId;
  final String? narrationVoiceName;

  const SoundscapeDefaults({
    this.activity,
    this.durationMinutes = 15.0,
    this.binauralVolume = 0.8,
    this.musicVolume = 0.1,
    this.ambienceVolume = 0.1,
    this.narrationVolume = 0.35,
    this.backgroundMusic,
    this.backgroundAmbience,
    this.narrationVoiceId,
    this.narrationVoiceName,
  });

  static const SoundscapeDefaults standard = SoundscapeDefaults();

  Map<String, dynamic> toJson() => {
        'activity': activity,
        'durationMinutes': durationMinutes,
        'binauralVolume': binauralVolume,
        'musicVolume': musicVolume,
        'ambienceVolume': ambienceVolume,
        'narrationVolume': narrationVolume,
        'backgroundMusic': backgroundMusic,
        'backgroundAmbience': backgroundAmbience,
        'narrationVoiceId': narrationVoiceId,
        'narrationVoiceName': narrationVoiceName,
      };

  factory SoundscapeDefaults.fromJson(Map<String, dynamic> json) {
    return SoundscapeDefaults(
      activity: json['activity'] as String?,
      durationMinutes: (json['durationMinutes'] as num?)?.toDouble() ?? 15.0,
      binauralVolume: (json['binauralVolume'] as num?)?.toDouble() ?? 0.8,
      musicVolume: (json['musicVolume'] as num?)?.toDouble() ?? 0.1,
      ambienceVolume: (json['ambienceVolume'] as num?)?.toDouble() ?? 0.1,
      narrationVolume: (json['narrationVolume'] as num?)?.toDouble() ?? 0.35,
      backgroundMusic: json['backgroundMusic'] as String?,
      backgroundAmbience: json['backgroundAmbience'] as String?,
      narrationVoiceId: json['narrationVoiceId'] as String?,
      narrationVoiceName: json['narrationVoiceName'] as String?,
    );
  }

  SoundscapeDefaults copyWith({
    String? activity,
    double? durationMinutes,
    double? binauralVolume,
    double? musicVolume,
    double? ambienceVolume,
    double? narrationVolume,
    String? backgroundMusic,
    String? backgroundAmbience,
    String? narrationVoiceId,
    String? narrationVoiceName,
    bool clearActivity = false,
    bool clearBackgroundMusic = false,
    bool clearBackgroundAmbience = false,
    bool clearNarrationVoice = false,
  }) {
    return SoundscapeDefaults(
      activity: clearActivity ? null : (activity ?? this.activity),
      durationMinutes: durationMinutes ?? this.durationMinutes,
      binauralVolume: binauralVolume ?? this.binauralVolume,
      musicVolume: musicVolume ?? this.musicVolume,
      ambienceVolume: ambienceVolume ?? this.ambienceVolume,
      narrationVolume: narrationVolume ?? this.narrationVolume,
      backgroundMusic: clearBackgroundMusic
          ? null
          : (backgroundMusic ?? this.backgroundMusic),
      backgroundAmbience: clearBackgroundAmbience
          ? null
          : (backgroundAmbience ?? this.backgroundAmbience),
      narrationVoiceId: clearNarrationVoice
          ? null
          : (narrationVoiceId ?? this.narrationVoiceId),
      narrationVoiceName: clearNarrationVoice
          ? null
          : (narrationVoiceName ?? this.narrationVoiceName),
    );
  }
}
