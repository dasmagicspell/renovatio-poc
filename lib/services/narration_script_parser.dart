/// A single segment of a parsed narration script.
abstract class NarrationSegment {}

/// A segment containing text to be converted to speech.
class TextNarrationSegment extends NarrationSegment {
  final String text;
  TextNarrationSegment(this.text);
}

/// A segment representing a silent pause.
class PauseNarrationSegment extends NarrationSegment {
  final Duration duration;
  PauseNarrationSegment(this.duration);
}

/// Parses a narration script that uses [pause:Xs] markup into an ordered list
/// of [TextNarrationSegment] and [PauseNarrationSegment].
///
/// Example input:
///   "Take a deep breath. [pause:4s] And exhale slowly. [pause:6s] Relax."
///
/// Produces:
///   TextNarrationSegment("Take a deep breath.")
///   PauseNarrationSegment(4 seconds)
///   TextNarrationSegment("And exhale slowly.")
///   PauseNarrationSegment(6 seconds)
///   TextNarrationSegment("Relax.")
class NarrationScriptParser {
  static final _pausePattern =
      RegExp(r'\[pause:(\d+(?:\.\d+)?)s\]', caseSensitive: false);

  static List<NarrationSegment> parse(String script) {
    final segments = <NarrationSegment>[];
    int lastIndex = 0;

    for (final match in _pausePattern.allMatches(script)) {
      final textBefore = script.substring(lastIndex, match.start).trim();
      if (textBefore.isNotEmpty) {
        segments.add(TextNarrationSegment(textBefore));
      }
      final seconds = double.parse(match.group(1)!);
      segments.add(PauseNarrationSegment(
        Duration(milliseconds: (seconds * 1000).round()),
      ));
      lastIndex = match.end;
    }

    final trailing = script.substring(lastIndex).trim();
    if (trailing.isNotEmpty) {
      segments.add(TextNarrationSegment(trailing));
    }

    return segments;
  }
}
