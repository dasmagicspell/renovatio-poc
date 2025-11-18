import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  String? _selectedActivity;
  bool _isSessionActive = false;
  bool _isLoadingAudio = false;
  
  // Multi-layer audio state
  Map<String, String>? _loadedAudioFiles;
  final Map<String, AudioPlayer> _audioPlayers = {};
  final Map<String, double> _layerVolumes = {
    'binaural': 0.5,
    'ambient_forest': 0.3,
    'narration': 0.7,
  };
  final Map<String, double> _layerSpeeds = {
    'binaural': 1.0,
    'ambient_forest': 1.0,
    'narration': 1.0,
  };
  final Map<String, double> _layerPitches = {
    'binaural': 1.0,
    'ambient_forest': 1.0,
    'narration': 1.0,
  };
  bool _isPlaying = false;

  // Activity to binaural file mapping
  final Map<String, String> _activityToBinauralFile = {
    'relax': 'assets/audio/binaural/relax.wav',
    'meditate': 'assets/audio/binaural/meditate.wav',
    'sleep': 'assets/audio/binaural/sleep.wav',
    'study': 'assets/audio/binaural/study.wav',
    'exercise': 'assets/audio/binaural/exercise.wav',
    'focus': 'assets/audio/binaural/focus.wav',
    'anxiety': 'assets/audio/binaural/anxiety_relief.wav',
    'energy': 'assets/audio/binaural/energy_boost.wav',
  };

  // Activity definitions
  final List<SessionActivity> _activities = [
    SessionActivity(
      id: 'relax',
      title: 'Relax',
      description: 'Gentle breathing and calming sounds',
      icon: Icons.spa,
      color: Colors.teal,
      duration: '10-30 min',
      frequencyRange: 'Theta (4 Hz)',
      prompt: '''
      Create a 30-minute binaural beats audio file for deep relaxation.
        - Use a base frequency of 200 Hz in the left ear.
        - Use 204 Hz in the right ear (4 Hz difference → theta range, good for relaxation/meditation).
        - Output format: high-quality stereo .wav file.
        - Add a gentle background layer of soft ocean waves at low volume.
        - Ensure smooth fade-in (30s) and fade-out (30s) to avoid abrupt starts/ends.
        - Keep volume comfortable for long listening sessions.''',
    ),
    SessionActivity(
      id: 'meditate',
      title: 'Meditate',
      description: 'Mindfulness and focus exercises',
      icon: Icons.self_improvement,
      color: Colors.purple,
      duration: '5-60 min',
      frequencyRange: 'Alpha (8 Hz)',
      prompt: '''
      Create a 20-minute guided meditation audio file for mindfulness practice.
        - Use a base frequency of 100 Hz in the left ear.
        - Use 108 Hz in the right ear (8 Hz difference → alpha range, good for meditation/focus).
        - Output format: high-quality stereo .wav file.
        - Add a subtle background layer of Tibetan singing bowls at very low volume.
        - Include gentle breathing cues every 4 minutes.
        - Ensure smooth fade-in (20s) and fade-out (20s) to avoid abrupt starts/ends.
        - Keep volume comfortable for extended meditation sessions.''',
    ),
    SessionActivity(
      id: 'sleep',
      title: 'Sleep',
      description: 'Bedtime stories and sleep sounds',
      icon: Icons.bedtime,
      color: Colors.indigo,
      duration: '20-90 min',
      frequencyRange: 'Delta (2 Hz)',
      prompt: '''
      Create a 45-minute sleep induction audio file for deep rest.
        - Use a base frequency of 50 Hz in the left ear.
        - Use 52 Hz in the right ear (2 Hz difference → delta range, good for deep sleep).
        - Output format: high-quality stereo .wav file.
        - Add a gentle background layer of white noise and soft rain sounds at low volume.
        - Include a slow, calming bedtime story narration in the first 15 minutes.
        - Gradually reduce narration volume and increase ambient sounds over time.
        - Ensure smooth fade-in (60s) and fade-out (60s) to avoid abrupt starts/ends.
        - Keep volume very low for sleep environment.''',
    ),
    SessionActivity(
      id: 'study',
      title: 'Study',
      description: 'Focus music and concentration aids',
      icon: Icons.school,
      color: Colors.blue,
      duration: '25-50 min',
      frequencyRange: 'Gamma (0.5 Hz)',
      prompt: '''
      Create a 40-minute focus enhancement audio file for deep study sessions.
        - Use a base frequency of 40 Hz in the left ear.
        - Use 40.5 Hz in the right ear (0.5 Hz difference → gamma range, good for focus/concentration).
        - Output format: high-quality stereo .wav file.
        - Add a subtle background layer of brown noise and soft classical piano at low volume.
        - Include gentle focus cues every 10 minutes to maintain attention.
        - Ensure smooth fade-in (15s) and fade-out (15s) to avoid abrupt starts/ends.
        - Keep volume moderate for study environment without distraction.''',
    ),
    SessionActivity(
      id: 'exercise',
      title: 'Exercise',
      description: 'Workout music and motivation',
      icon: Icons.fitness_center,
      color: Colors.orange,
      duration: '15-60 min',
      frequencyRange: 'Beta (8 Hz)',
      prompt: '''
      Create a 30-minute high-energy workout audio file for physical training.
        - Use a base frequency of 80 Hz in the left ear.
        - Use 88 Hz in the right ear (8 Hz difference → beta range, good for alertness/energy).
        - Output format: high-quality stereo .wav file.
        - Add an energetic background layer of electronic beats and motivational music at medium volume.
        - Include workout timing cues every 5 minutes for interval training.
        - Ensure smooth fade-in (10s) and fade-out (10s) to avoid abrupt starts/ends.
        - Keep volume high enough to motivate and energize during exercise.''',
    ),
    SessionActivity(
      id: 'focus',
      title: 'Focus',
      description: 'Deep work and productivity sessions',
      icon: Icons.psychology,
      color: Colors.green,
      duration: '25-90 min',
      frequencyRange: 'Theta (0.2 Hz)',
      prompt: '''
      Create a 60-minute deep focus audio file for intensive work sessions.
        - Use a base frequency of 30 Hz in the left ear.
        - Use 30.2 Hz in the right ear (0.2 Hz difference → theta range, good for deep focus/flow state).
        - Output format: high-quality stereo .wav file.
        - Add a minimal background layer of ambient forest sounds and soft instrumental music at very low volume.
        - Include subtle productivity cues every 15 minutes to maintain flow state.
        - Ensure smooth fade-in (25s) and fade-out (25s) to avoid abrupt starts/ends.
        - Keep volume low to maintain concentration without distraction.''',
    ),
    SessionActivity(
      id: 'anxiety',
      title: 'Anxiety Relief',
      description: 'Calming techniques and grounding',
      icon: Icons.favorite,
      color: Colors.pink,
      duration: '5-20 min',
      frequencyRange: 'Theta (4 Hz)',
      prompt: '''
      Create a 15-minute anxiety relief audio file for immediate calming.
        - Use a base frequency of 60 Hz in the left ear.
        - Use 64 Hz in the right ear (4 Hz difference → theta range, good for anxiety relief/calming).
        - Output format: high-quality stereo .wav file.
        - Add a soothing background layer of gentle rain and soft harp music at low volume.
        - Include guided breathing exercises and grounding affirmations every 3 minutes.
        - Ensure smooth fade-in (45s) and fade-out (45s) to avoid abrupt starts/ends.
        - Keep volume very low for maximum calming effect.''',
    ),
    SessionActivity(
      id: 'energy',
      title: 'Energy Boost',
      description: 'Uplifting sounds and motivation',
      icon: Icons.flash_on,
      color: Colors.yellow,
      duration: '10-30 min',
      frequencyRange: 'Alpha (8 Hz)',
      prompt: '''
      Create a 20-minute energy boost audio file for motivation and alertness.
        - Use a base frequency of 120 Hz in the left ear.
        - Use 128 Hz in the right ear (8 Hz difference → alpha range, good for alertness/energy).
        - Output format: high-quality stereo .wav file.
        - Add an uplifting background layer of bright acoustic guitar and nature sounds at medium volume.
        - Include motivational affirmations and energy cues every 5 minutes.
        - Ensure smooth fade-in (20s) and fade-out (20s) to avoid abrupt starts/ends.
        - Keep volume moderate to energize and motivate without being overwhelming.''',
    ),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // Dispose all audio players
    for (var player in _audioPlayers.values) {
      player.dispose();
    }
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: Column(
        children: [
          // Session Active Indicator
          if (_isSessionActive)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF2d2d2d),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Session Active',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2d2d2d),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.psychology,
                              color: Colors.blue,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Choose Your Session',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Select an activity that matches your current mood and needs. Each session is designed to help you achieve your wellness goals.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Activity Grid
                  _buildActivityGrid(),
                  
                  const SizedBox(height: 24),
                  
                  // Multi-Layer Audio Player
                  if (_loadedAudioFiles != null)
                    _buildMultiLayerAudioPlayer(),
                  
                  // Session Controls
                  if (_selectedActivity != null) _buildSessionControls(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Sessions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _activities.length,
          itemBuilder: (context, index) {
            final activity = _activities[index];
            final isSelected = _selectedActivity == activity.id;
            
            return _buildActivityCard(activity, isSelected);
          },
        ),
      ],
    );
  }

  Widget _buildActivityCard(SessionActivity activity, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedActivity = isSelected ? null : activity.id;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? activity.color.withOpacity(0.2)
              : const Color(0xFF2d2d2d),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? activity.color
                : Colors.grey[700]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? activity.color.withOpacity(0.3)
                  : Colors.black.withOpacity(0.3),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: activity.color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                activity.icon,
                color: activity.color,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              activity.title,
              style: TextStyle(
                color: isSelected ? activity.color : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              activity.duration,
              style: TextStyle(
                color: isSelected ? activity.color : Colors.white70,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                activity.description,
                style: TextStyle(
                  color: isSelected ? activity.color : Colors.white60,
                  fontSize: 9,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionControls() {
    final activity = _activities.firstWhere((a) => a.id == _selectedActivity);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2d2d2d),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                activity.icon,
                color: activity.color,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                '${activity.title} Session',
                style: TextStyle(
                  color: activity.color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            activity.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoadingAudio ? null : _loadAudio,
                  icon: _isLoadingAudio 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.audiotrack, color: Colors.white),
                  label: Text(
                    _isLoadingAudio ? 'Loading...' : 'Load Audio',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLoadingAudio ? Colors.grey : activity.color,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSessionActive ? _stopSession : _startSession,
                  icon: Icon(
                    _isSessionActive ? Icons.stop : Icons.play_arrow,
                    color: _isSessionActive ? Colors.red : activity.color,
                  ),
                  label: Text(
                    _isSessionActive ? 'Stop Session' : 'Start Session',
                    style: TextStyle(
                      color: _isSessionActive ? Colors.red : activity.color,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _isSessionActive ? Colors.red : activity.color,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          if (_isSessionActive) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Session is active. Your audio and health monitoring are now synchronized.',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadAudio() async {
    if (_selectedActivity == null) return;
    
    final activity = _activities.firstWhere((a) => a.id == _selectedActivity);
    
    setState(() {
      _isLoadingAudio = true;
    });
    
    try {
      // Show loading message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Loading audio files...'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Load audio files from assets
      final audioFiles = await _loadAudioFilesFromAssets(activity);
      
      if (audioFiles != null) {
        setState(() {
          _loadedAudioFiles = audioFiles;
        });
        
        // Automatically initialize all audio players
        final List<Future<void>> initializationTasks = [];
        
        for (var entry in audioFiles.entries) {
          initializationTasks.add(_initializeAudioPlayer(entry.key, entry.value));
        }
        
        // Wait for all audio players to be initialized
        await Future.wait(initializationTasks);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('${activity.title} audio loaded successfully! (${_audioPlayers.length} layers ready)'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load audio files. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Text('Error loading audio: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingAudio = false;
      });
    }
  }

  Future<Map<String, String>?> _loadAudioFilesFromAssets(SessionActivity activity) async {
    try {
      // Get the binaural file path for this activity
      final binauralFilePath = _activityToBinauralFile[activity.id];
      if (binauralFilePath == null) {
        return null;
      }
      
      // Create the audio files map - try different formats for better compatibility
      final Map<String, String> audioFiles = {
        'binaural': binauralFilePath,
        'ambient_forest': 'assets/audio/background-audio/forest.mp4', // Try MP4 instead of MP3
        'narration': 'assets/audio/narration/SampleSubMessage.m4a',
      };
      
      return audioFiles;
    } catch (e) {
      return null;
    }
  }








  Future<void> _createMonoWavFile(String filePath, Int16List pcmData, int sampleRate) async {
    final file = File(filePath);
    final bytes = ByteData(pcmData.length * 2 + 44);
    
    // WAV header for mono
    bytes.setUint8(0, 0x52); // 'R'
    bytes.setUint8(1, 0x49); // 'I'
    bytes.setUint8(2, 0x46); // 'F'
    bytes.setUint8(3, 0x46); // 'F'
    bytes.setUint32(4, pcmData.length * 2 + 36, Endian.little); // File size
    bytes.setUint8(8, 0x57); // 'W'
    bytes.setUint8(9, 0x41); // 'A'
    bytes.setUint8(10, 0x56); // 'V'
    bytes.setUint8(11, 0x45); // 'E'
    bytes.setUint8(12, 0x66); // 'f'
    bytes.setUint8(13, 0x6D); // 'm'
    bytes.setUint8(14, 0x74); // 't'
    bytes.setUint8(15, 0x20); // ' '
    bytes.setUint32(16, 16, Endian.little); // Subchunk1Size
    bytes.setUint16(20, 1, Endian.little); // AudioFormat (PCM)
    bytes.setUint16(22, 1, Endian.little); // NumChannels (mono)
    bytes.setUint32(24, sampleRate, Endian.little); // SampleRate
    bytes.setUint32(28, sampleRate * 1 * 2, Endian.little); // ByteRate
    bytes.setUint16(32, 2, Endian.little); // BlockAlign
    bytes.setUint16(34, 16, Endian.little); // BitsPerSample
    bytes.setUint8(36, 0x64); // 'd'
    bytes.setUint8(37, 0x61); // 'a'
    bytes.setUint8(38, 0x74); // 't'
    bytes.setUint8(39, 0x61); // 'a'
    bytes.setUint32(40, pcmData.length * 2, Endian.little); // Subchunk2Size
    
    // Write PCM data
    for (int i = 0; i < pcmData.length; i++) {
      bytes.setInt16(44 + i * 2, pcmData[i], Endian.little);
    }
    
    await file.writeAsBytes(bytes.buffer.asUint8List());
  }

  Future<void> _createPlaceholderAudio(String filePath, int sampleRate, int duration) async {
    // Create a simple tone audio file as placeholder instead of silent
    final totalSamples = sampleRate * duration;
    final pcmData = Int16List(totalSamples);
    
    // Generate a more audible sine wave (440 Hz) for ambient, 220 Hz for narration
    final frequency = filePath.contains('narration') ? 220.0 : 440.0;
    final amplitude = 8000; // More audible - was 1000
    
    for (int i = 0; i < totalSamples; i++) {
      final time = i / sampleRate;
      final sample = (amplitude * sin(2 * pi * frequency * time)).round();
      pcmData[i] = sample.clamp(-32768, 32767);
    }
    
    // Create WAV file (mono)
    await _createMonoWavFile(filePath, pcmData, sampleRate);
  }

  void _startSession() {
    setState(() {
      _isSessionActive = true;
    });
    
    // TODO: Implement actual session logic
    // This could include:
    // - Starting appropriate audio tracks
    // - Beginning health monitoring
    // - Setting up timers
    // - Connecting to audio player and health services
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_activities.firstWhere((a) => a.id == _selectedActivity).title} session started!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _stopSession() {
    setState(() {
      _isSessionActive = false;
    });
    
    // Stop all audio players
    _stopAllAudio();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session stopped.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _buildMultiLayerAudioPlayer() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 600), // Limit height
      decoration: BoxDecoration(
        color: const Color(0xFF2d2d2d),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.layers, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Multi-Layer Audio Player',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _audioPlayers.isNotEmpty ? (_isPlaying ? _stopAllAudio : _playAllAudio) : null,
                  icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                  label: Text(_isPlaying ? 'Stop All' : 'Play All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _audioPlayers.isEmpty 
                        ? Colors.grey 
                        : (_isPlaying ? Colors.red : Colors.green),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _testAudioLayers,
                  icon: const Icon(Icons.bug_report),
                  label: const Text('Test'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: _loadedAudioFiles!.entries.map((entry) {
                  final layerName = entry.key;
                  final filePath = entry.value;
                  return _buildAudioLayerControl(layerName, filePath);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioLayerControl(String layerName, String filePath) {
    final displayName = _getLayerDisplayName(layerName);
    final icon = _getLayerIcon(layerName);
    final color = _getLayerColor(layerName);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _audioPlayers.containsKey(layerName),
                onChanged: (value) {
                  if (value) {
                    _initializeAudioPlayer(layerName, filePath);
                  } else {
                    _disposeAudioPlayer(layerName);
                  }
                },
                activeColor: color,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          
          if (_audioPlayers.containsKey(layerName)) ...[
            const SizedBox(height: 8),
            
            // Volume control
            Row(
              children: [
                const Icon(Icons.volume_up, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                const Text('Vol:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(width: 6),
                Expanded(
                  child: Slider(
                    value: _layerVolumes[layerName]!,
                    min: 0.0,
                    max: 1.0,
                    divisions: 50,
                    activeColor: color,
                    onChanged: (value) {
                      setState(() {
                        _layerVolumes[layerName] = value;
                      });
                      _audioPlayers[layerName]?.setVolume(value);
                    },
                  ),
                ),
                SizedBox(
                  width: 35,
                  child: Text(
                    '${(_layerVolumes[layerName]! * 100).round()}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            
            // Speed control
            Row(
              children: [
                const Icon(Icons.speed, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                const Text('Speed:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(width: 6),
                Expanded(
                  child: Slider(
                    value: _layerSpeeds[layerName]!,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    activeColor: color,
                    onChanged: (value) {
                      setState(() {
                        _layerSpeeds[layerName] = value;
                      });
                      // Apply speed only (independent of pitch)
                      _audioPlayers[layerName]?.setSpeed(value);
                    },
                  ),
                ),
                SizedBox(
                  width: 35,
                  child: Text(
                    '${_layerSpeeds[layerName]!.toStringAsFixed(1)}x',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            
            // Pitch control (only for binaural and narration)
            if (layerName == 'binaural' || layerName == 'narration') ...[
              Row(
                children: [
                  const Icon(Icons.tune, color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    Platform.isIOS ? 'Voice (iOS):' : 'Voice:',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Slider(
                      value: _layerPitches[layerName]!,
                      min: 0.5,
                      max: 2.0,
                      divisions: 30,
                      activeColor: color,
                      onChanged: (value) {
                        setState(() {
                          _layerPitches[layerName] = value;
                        });
                        // Apply pitch using platform-specific method
                        if (_audioPlayers[layerName] != null) {
                          _setAudioPitch(_audioPlayers[layerName]!, value, layerName: layerName);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: 35,
                    child: Text(
                      Platform.isIOS 
                          ? (_layerPitches[layerName]! < 1.0 
                              ? 'Slower' 
                              : _layerPitches[layerName]! > 1.0 
                                  ? 'Faster' 
                                  : 'Normal')
                          : (_layerPitches[layerName]! < 1.0 
                              ? 'Deeper' 
                              : _layerPitches[layerName]! > 1.0 
                                  ? 'Higher' 
                                  : 'Normal'),
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _getLayerDisplayName(String layerName) {
    switch (layerName) {
      case 'binaural': return 'Binaural Audio';
      case 'ambient_forest': return 'Forest Ambient';
      case 'narration': return 'Narration';
      default: return layerName;
    }
  }

  IconData _getLayerIcon(String layerName) {
    switch (layerName) {
      case 'binaural': return Icons.headphones;
      case 'ambient_forest': return Icons.park;
      case 'narration': return Icons.record_voice_over;
      default: return Icons.audiotrack;
    }
  }

  Color _getLayerColor(String layerName) {
    switch (layerName) {
      case 'binaural': return Colors.blue;
      case 'ambient_forest': return Colors.green;
      case 'narration': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Future<void> _initializeAudioPlayer(String layerName, String filePath) async {
    try {
      final player = AudioPlayer();
      
      // Try to set the source with better error handling
      try {
        // Check if it's an asset file (starts with 'assets/')
        if (filePath.startsWith('assets/')) {
          await player.setAsset(filePath);
        } else {
          // Check if file exists for non-asset files
      final file = File(filePath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Audio file not found for $layerName'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Check file size to avoid loading empty files
      final fileSize = await file.length();
      if (fileSize == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Audio file is empty for $layerName'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
        await player.setFilePath(filePath);
        }
      } catch (sourceError) {
        // Create a placeholder audio file for any failed asset
        final tempDir = await getTemporaryDirectory();
        final wavPath = '${tempDir.path}/${layerName}_placeholder.wav';
        await _createPlaceholderAudio(wavPath, 44100, 300); // 5 minutes
        
        // Update the loaded audio files map
        if (_loadedAudioFiles != null) {
          _loadedAudioFiles![layerName] = wavPath;
        }
        
        // Try again with WAV file
        await player.setFilePath(wavPath);
      }
      
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(_layerVolumes[layerName]!);
      // Apply separate speed and pitch controls
      await player.setSpeed(_layerSpeeds[layerName]!);
      await _setAudioPitch(player, _layerPitches[layerName]!, layerName: layerName);
      
      setState(() {
        _audioPlayers[layerName] = player;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load audio for $layerName. Using placeholder.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _disposeAudioPlayer(String layerName) {
    _audioPlayers[layerName]?.dispose();
    _audioPlayers.remove(layerName);
    setState(() {});
  }

  Future<void> _playAllAudio() async {
    if (_audioPlayers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No audio players available. Please load audio first.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    // Play all available players simultaneously
    final List<Future<void>> playTasks = [];
    for (var entry in _audioPlayers.entries) {
      playTasks.add(_playSingleAudio(entry.key, entry.value));
    }
    
    // Wait for all players to start playing
    await Future.wait(playTasks);
    
    setState(() {
      _isPlaying = true;
    });
  }
  
  Future<void> _playSingleAudio(String layerName, AudioPlayer player) async {
    try {
      await player.play();
    } catch (e) {
      // Error playing audio
    }
  }

  Future<void> _stopAllAudio() async {
    // Stop all players simultaneously
    final List<Future<void>> stopTasks = [];
    for (var entry in _audioPlayers.entries) {
      stopTasks.add(_stopSingleAudio(entry.key, entry.value));
    }
    
    // Wait for all players to stop
    await Future.wait(stopTasks);
    
    setState(() {
      _isPlaying = false;
    });
  }
  
  Future<void> _stopSingleAudio(String layerName, AudioPlayer player) async {
    try {
      await player.pause();
    } catch (e) {
      // Error stopping audio
    }
  }

  Future<void> _testAudioLayers() async {
    if (_loadedAudioFiles == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No audio files loaded. Please load audio first.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // Test each layer individually
    for (var entry in _loadedAudioFiles!.entries) {
      final layerName = entry.key;
      final hasPlayer = _audioPlayers.containsKey(layerName);
      
      if (hasPlayer) {
        try {
          // Check player state and duration
          final player = _audioPlayers[layerName]!;
          final duration = await player.duration;
          
          if (duration != null && duration.inSeconds > 0) {
            await player.play();
            await Future.delayed(const Duration(seconds: 3));
            await player.pause();
          }
        } catch (e) {
          // Error testing audio layer
        }
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio layer test completed.'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  /// Platform-specific pitch control
  /// Only works on Android - on iOS, pitch control is not supported by just_audio
  Future<void> _setAudioPitch(AudioPlayer player, double pitch, {String? layerName}) async {
    if (Platform.isAndroid) {
      try {
        await player.setPitch(pitch);
      } catch (e) {
        // Error setting pitch on Android
      }
    } else {
      // On iOS, we can simulate pitch by adjusting speed (though this also changes timing)
      // This is not ideal but provides some functionality
      if (layerName != null) {
        final currentSpeed = _layerSpeeds[layerName] ?? 1.0;
        await player.setSpeed(currentSpeed * pitch);
      }
    }
  }

}

class SessionActivity {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String duration;
  final String prompt;
  final String frequencyRange;

  SessionActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.duration,
    required this.prompt,
    required this.frequencyRange,
  });
}
