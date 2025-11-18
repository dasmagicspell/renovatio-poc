# Audio Merger & Processor

A Flutter application that allows you to merge multiple audio tracks with individual and master controls for speed, volume, and pitch transposition, then export the result as a single audio file.

## 🎵 New Workflow

### 1. **Parameter Adjustment Phase**
- Adjust **master controls** (affects all tracks globally)
- Fine-tune **individual track controls** (volume, speed, pitch)
- Preview settings in real-time

### 2. **Audio Processing Phase**
- Click **"Merge Tracks"** to process and combine all tracks
- FFmpeg processes each track with applied effects
- Creates a single output file with all tracks overlaid

### 3. **Playback Phase**
- Play the merged audio file
- All tracks play simultaneously with your applied effects
- Export the final result

## ✨ Key Features

### **Audio Processing**
- **Real-time parameter adjustment** before merging
- **FFmpeg-powered** audio processing for high quality
- **Individual track effects** (volume, speed, pitch)
- **Master controls** that affect all tracks
- **Automatic file naming** with timestamps

### **User Interface**
- **Dark theme** with professional audio player aesthetics
- **Real-time sliders** with value display
- **Processing indicators** during merge operations
- **Output file management**
- **Error handling** with user feedback

### **File Management**
- **Automatic output directory** (Documents folder)
- **Timestamped filenames** to avoid conflicts
- **Cross-platform file handling**
- **Permission management** for storage access

## 🔧 Technical Implementation

### **Dependencies Added**
- `ffmpeg_kit_flutter`: For audio processing and merging
- `path_provider`: For file system access
- `permission_handler`: For storage permissions

### **Audio Processing Pipeline**
1. **Input**: Multiple audio files with individual parameters
2. **Processing**: FFmpeg applies effects to each track
3. **Mixing**: All processed tracks are overlaid
4. **Output**: Single merged audio file

### **FFmpeg Commands Used**
- `volume`: Adjust track volume
- `asetrate`: Change sample rate (pitch)
- `atempo`: Adjust playback speed
- `amix`: Mix multiple audio streams

## 📱 Platform Support

### **Android**
- Storage permissions configured
- FFmpeg Kit support
- File system access

### **iOS**
- Document directory access
- Audio processing capabilities
- Permission handling

### **Desktop (Windows/macOS/Linux)**
- Cross-platform file handling
- FFmpeg integration
- Native audio support

## 🚀 Usage Instructions

### **Step 1: Setup**
```bash
flutter pub get
```

### **Step 2: Add Audio Files**
Place your audio files in `assets/audio/` directory:
- `track1.mp3`
- `track2.mp3`
- `track3.mp3`
- `track4.mp3`

### **Step 3: Adjust Parameters**
- Use **Master Controls** for global adjustments
- Fine-tune **Individual Track Controls** as needed
- Preview changes in real-time

### **Step 4: Merge Tracks**
- Click **"Merge Tracks"** button
- Wait for processing to complete
- Output file will be saved automatically

### **Step 5: Play Merged Audio**
- Use the **Output Player** to play your merged file
- All tracks will play simultaneously with applied effects

## 🎛️ Control Parameters

### **Master Controls**
- **Speed**: 0.5x - 2.0x (affects all tracks)
- **Volume**: 0.0 - 1.0 (affects all tracks)
- **Pitch**: 0.5x - 2.0x (affects all tracks)

### **Individual Track Controls**
- **Volume**: 0.0 - 1.0 (per track)
- **Speed**: 0.5x - 2.0x (per track)
- **Pitch**: 0.5x - 2.0x (per track)

### **Final Values**
Each track's final effect = Master Control × Individual Track Control

## 📁 File Structure

```
lib/
├── main.dart                 # App entry point
├── audio_player_page.dart    # Main UI and controls
└── audio_processor.dart      # FFmpeg audio processing

assets/audio/                 # Input audio files
├── track1.mp3
├── track2.mp3
├── track3.mp3
└── track4.mp3

Documents/                    # Output directory (auto-created)
└── merged_audio_[timestamp].mp3
```

## 🔍 Troubleshooting

### **Audio Not Merging**
- Check that input files exist and are accessible
- Verify FFmpeg Kit is properly installed
- Ensure storage permissions are granted

### **Processing Errors**
- Check audio file formats (MP3, WAV, M4A supported)
- Verify file paths are correct
- Check available storage space

### **Permission Issues**
- Grant storage permissions when prompted
- Check device-specific permission settings
- Restart app if permissions are denied

## 🎯 Use Cases

### **Music Production**
- Layer multiple instrument tracks
- Apply different effects to each track
- Create final mixed compositions

### **Podcast Production**
- Mix background music with voice tracks
- Apply different processing to each element
- Export professional-quality results

### **Audio Effects**
- Layer sound effects over music
- Apply pitch/speed changes to create variations
- Create complex audio compositions

### **Live Performance**
- Pre-process audio tracks for live shows
- Create custom mixes with effects
- Export ready-to-play audio files

## 🔮 Future Enhancements

- **Real-time preview** during parameter adjustment
- **Audio waveform visualization**
- **More audio effects** (reverb, echo, filters)
- **Batch processing** for multiple projects
- **Cloud storage integration**
- **MIDI support** for tempo synchronization
- **Audio format conversion**
- **Quality presets** for different use cases

## 📄 License

This project is part of the Renovatio POC and is for demonstration purposes.

---

**Note**: The app now focuses on creating merged audio files rather than simultaneous playback, giving you full control over the final output with professional-quality audio processing.
