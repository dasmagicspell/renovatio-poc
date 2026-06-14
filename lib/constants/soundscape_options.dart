/// Shared soundscape option lists used by session creation and settings.
class SoundscapeOptions {
  SoundscapeOptions._();

  static const Map<String, String> activityBand = {
    'Sleep': 'Delta',
    'Pain Relief': 'Delta',
    'Meditate': 'Theta',
    'Anxiety Relief': 'Theta',
    'Creativity': 'Theta',
    'Relax': 'Alpha',
    'Study': 'Alpha',
    'Light Focus': 'Alpha',
    'Exercise': 'Beta',
    'Focus': 'Beta',
    'Energy Boost': 'Gamma',
  };

  static const List<String> bundledMusic = [
    'None',
    'Classical Music',
    'Piano Instrumental',
    'Acoustic Guitar',
  ];

  static const List<String> bundledAmbience = [
    'None',
    'Forest',
    'Ocean Waves',
    'Rain',
    'Birds Chirping',
  ];

  static List<String> get activities => activityBand.keys.toList();

  static String bandForActivity(String activity) =>
      activityBand[activity] ?? 'Alpha';
}
