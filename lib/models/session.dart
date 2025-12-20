class Session {
  final String id;
  final String name;
  final String activity;
  final int durationMinutes;
  final String backgroundMusic;
  final String backgroundAmbience;
  final String narrationText;
  final DateTime createdAt;

  Session({
    required this.id,
    required this.name,
    required this.activity,
    required this.durationMinutes,
    required this.backgroundMusic,
    required this.backgroundAmbience,
    required this.narrationText,
    required this.createdAt,
  });

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
      'createdAt': createdAt.toIso8601String(),
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
      createdAt: DateTime.parse(json['createdAt'] as String),
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

