/// Beat frequency (Hz) for each goal, matching the labels shown in [NewSessionPage].
class BinauralGoalFrequencies {
  BinauralGoalFrequencies._();

  static const Map<String, double> _goalToBeatHz = {
    'Deep Sleep': 1,
    'Sleep': 2,
    'Deep Meditation': 2,
    'Pain Relief': 2,
    'Meditate': 6,
    'Anxiety Relief': 6,
    'Creativity': 6,
    'Relax': 10,
    'Study': 10,
    'Light Focus': 10,
    'Exercise': 20,
    'Focus': 20,
    'Energy Boost': 40,
  };

  /// Returns the binaural beat frequency in Hz for the selected goal name.
  static double beatHzForGoal(String goal) =>
      _goalToBeatHz[goal] ?? 10.0;
}
