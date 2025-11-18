# Multi-Track Audio Player

A Flutter application that allows you to overlay multiple audio files with individual and master controls for speed, volume, and pitch transposition.

## Features

- **Multi-track playback**: Play up to 4 audio tracks simultaneously
- **Master controls**: Global speed, volume, and pitch controls that affect all tracks
- **Individual track controls**: Each track has its own speed, volume, and pitch controls
- **Real-time control**: Adjust parameters while audio is playing
- **Modern UI**: Dark theme with intuitive controls and visual feedback
- **Cross-platform**: Works on iOS, Android, Web, Windows, macOS, and Linux

## Setup

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Add your audio files**:
   - Place your audio files in the `assets/audio/` directory
   - Update the file paths in `lib/audio_player_page.dart` if needed
   - Supported formats: MP3, WAV, M4A, AAC

3. **Run the app**:
   ```bash
   flutter run
   ```

## File Structure

```
lib/
├── main.dart                 # App entry point
└── audio_player_page.dart    # Main audio player interface

assets/
└── audio/                   # Place your audio files here
    ├── track1.mp3
    ├── track2.mp3
    ├── track3.mp3
    └── track4.mp3
```

## Usage

### Master Controls
- **Speed**: Adjust playback speed for all tracks (0.5x - 2.0x)
- **Volume**: Control overall volume level (0.0 - 1.0)
- **Pitch**: Transpose pitch for all tracks (0.5x - 2.0x)

### Individual Track Controls
Each track has its own set of controls that work in combination with the master controls:
- **Volume**: Track-specific volume (0.0 - 1.0)
- **Speed**: Track-specific speed (0.5x - 2.0x)
- **Pitch**: Track-specific pitch (0.5x - 2.0x)

### Playback Controls
- **Play**: Start all tracks simultaneously
- **Pause**: Pause all tracks
- **Stop**: Stop all tracks and reset to beginning

## Customization

### Adding More Tracks
To add more tracks, update the following in `lib/audio_player_page.dart`:

```dart
// Add more file paths
final List<String> _audioFiles = [
  'assets/audio/track1.mp3',
  'assets/audio/track2.mp3',
  'assets/audio/track3.mp3',
  'assets/audio/track4.mp3',
  'assets/audio/track5.mp3', // Add more tracks here
];

// Add corresponding track names
final List<String> _trackNames = [
  'Track 1',
  'Track 2',
  'Track 3',
  'Track 4',
  'Track 5', // Add more names here
];
```

### Using Remote Audio Files
To use audio files from a remote server, replace the file paths with URLs:

```dart
final List<String> _audioFiles = [
  'https://your-server.com/audio/track1.mp3',
  'https://your-server.com/audio/track2.mp3',
  'https://your-server.com/audio/track3.mp3',
  'https://your-server.com/audio/track4.mp3',
];
```

### Styling
The app uses a dark theme with customizable colors. You can modify the color scheme in the `build` methods of the audio player page.

## Dependencies

- `just_audio`: For audio playback and control
- `audioplayers`: Alternative audio player (included but not used)
- `audio_waveforms`: For audio visualization (included but not used)
- `flutter_slider_drawer`: For UI components (included but not used)

## Troubleshooting

### Audio Not Playing
1. Check that audio files exist in the correct directory
2. Verify file paths in the code match your actual files
3. Ensure audio files are in supported formats
4. Check device volume and permissions

### Performance Issues
- Reduce the number of simultaneous tracks
- Use compressed audio formats (MP3, AAC)
- Close other audio applications

### Platform-Specific Issues
- **iOS**: Ensure audio session is properly configured
- **Android**: Check audio focus and permissions
- **Web**: Some browsers may have audio autoplay restrictions

## Future Enhancements

- Audio waveform visualization
- Recording capabilities
- Audio effects (reverb, echo, etc.)
- Playlist management
- Audio file import/export
- MIDI support
- Real-time audio processing

## License

This project is part of the Renovatio POC and is for demonstration purposes.
