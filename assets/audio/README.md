# Audio Files Directory

This directory contains the audio files for the multi-track audio player.

## Adding Audio Files

To add your audio files, place them in this directory and update the file paths in `lib/audio_player_page.dart`:

1. Add your audio files to this directory (e.g., `track1.mp3`, `track2.mp3`, etc.)
2. Update the `_audioFiles` list in `lib/audio_player_page.dart` with your actual file paths
3. Update the `_trackNames` list with descriptive names for your tracks

## Supported Formats

The audio player supports common audio formats including:
- MP3
- WAV
- M4A
- AAC

## Example File Structure

```
assets/audio/
├── track1.mp3
├── track2.mp3
├── track3.mp3
└── track4.mp3
```

## Remote Audio Files

For remote audio files, you can replace the file paths with URLs:

```dart
final List<String> _audioFiles = [
  'https://your-server.com/audio/track1.mp3',
  'https://your-server.com/audio/track2.mp3',
  'https://your-server.com/audio/track3.mp3',
  'https://your-server.com/audio/track4.mp3',
];
```
