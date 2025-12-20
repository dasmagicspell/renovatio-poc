class BinauralPreset {
  final String label;
  final int beatFrequency;
  final int leftFrequency;
  final int rightFrequency;
  final String effect;

  BinauralPreset({
    required this.label,
    required this.beatFrequency,
    required this.leftFrequency,
    required this.rightFrequency,
    required this.effect,
  });

  factory BinauralPreset.fromJson(Map<String, dynamic> json) {
    return BinauralPreset(
      label: json['label'] as String,
      beatFrequency: json['beatFrequency'] as int,
      leftFrequency: json['leftFrequency'] as int,
      rightFrequency: json['rightFrequency'] as int,
      effect: json['effect'] as String,
    );
  }
}

class BinauralActivity {
  final String activity;
  final String description;
  final Map<String, BinauralPreset> presets;

  BinauralActivity({
    required this.activity,
    required this.description,
    required this.presets,
  });

  factory BinauralActivity.fromJson(Map<String, dynamic> json) {
    final presetsJson = json['presets'] as Map<String, dynamic>;
    final presets = presetsJson.map((key, value) {
      return MapEntry(key, BinauralPreset.fromJson(value as Map<String, dynamic>));
    });

    return BinauralActivity(
      activity: json['activity'] as String,
      description: json['description'] as String,
      presets: presets,
    );
  }
}

