/// The allowed beat-frequency range for a brainwave band.
class BandRange {
  final String name;
  final double minHz;
  final double maxHz;

  const BandRange({
    required this.name,
    required this.minHz,
    required this.maxHz,
  });

  /// Number of 0.5 Hz steps across this range (for Slider divisions).
  int get divisions => ((maxHz - minHz) / 0.5).round();
}

/// Beat frequency defaults and band ranges for each goal.
class BinauralGoalFrequencies {
  BinauralGoalFrequencies._();

  // Default beat Hz used when a goal is first selected.
  static const Map<String, double> _goalDefaultHz = {
    'Deep Sleep': 1.0,
    'Sleep': 2.0,
    'Deep Meditation': 2.0,
    'Pain Relief': 2.0,
    'Meditate': 6.0,
    'Anxiety Relief': 6.0,
    'Creativity': 6.0,
    'Relax': 10.0,
    'Study': 10.0,
    'Light Focus': 10.0,
    'Exercise': 20.0,
    'Focus': 20.0,
    'Energy Boost': 40.0,
  };

  static const Map<String, String> _goalToBand = {
    'Deep Sleep': 'Delta',
    'Sleep': 'Delta',
    'Deep Meditation': 'Delta',
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

  static const Map<String, BandRange> _bandRanges = {
    'Delta': BandRange(name: 'Delta', minHz: 0.5, maxHz: 4.0),
    'Theta': BandRange(name: 'Theta', minHz: 4.0, maxHz: 8.0),
    'Alpha': BandRange(name: 'Alpha', minHz: 8.0, maxHz: 13.0),
    'Beta':  BandRange(name: 'Beta',  minHz: 13.0, maxHz: 30.0),
    'Gamma': BandRange(name: 'Gamma', minHz: 30.0, maxHz: 100.0),
  };

  /// Default beat frequency for the given goal (used when goal is first selected).
  static double defaultBeatHzForGoal(String goal) =>
      _goalDefaultHz[goal] ?? 10.0;

  /// Kept for backward compatibility — same as [defaultBeatHzForGoal].
  static double beatHzForGoal(String goal) => defaultBeatHzForGoal(goal);

  /// Brainwave band name for the given goal (e.g. "Theta").
  static String bandNameForGoal(String goal) =>
      _goalToBand[goal] ?? 'Alpha';

  /// Allowed beat-frequency range for the given goal's brainwave band.
  static BandRange bandRangeForGoal(String goal) {
    final band = _goalToBand[goal] ?? 'Alpha';
    return _bandRanges[band]!;
  }
}
