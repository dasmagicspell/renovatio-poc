import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:permission_handler/permission_handler.dart';
import 'audio_processor.dart';

class AudioPlayerPage extends StatefulWidget {
  const AudioPlayerPage({super.key});

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  // Audio players for each track
  late List<just_audio.AudioPlayer> _audioPlayers;
  List<just_audio.PlayerState> _playerStates = [];
  late List<Duration> _durations;
  late List<Duration> _positions;
  
  // Control states
  bool _isPlaying = false;
  bool _isProcessing = false;
  double _masterSpeed = 1.0;
  double _masterVolume = 1.0;
  double _masterPitch = 1.0;
  
  // Output file
  String? _outputFilePath;
  just_audio.AudioPlayer? _outputPlayer;
  
  // Track-specific controls
  late List<double> _trackVolumes;
  late List<double> _trackSpeeds;
  late List<double> _trackPitches;
  
  // Audio file paths (placeholder - you can replace these)
  final List<String> _audioFiles = [
    'assets/audio/track1.mp4',
    'assets/audio/track2.m4a',
    'assets/audio/track3.mp4',
    'assets/audio/track4.mp4',
  ];
  
  // Track names for display
  final List<String> _trackNames = [
    'Track 1',
    'Track 2', 
    'Track 3',
    'Track 4',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAudioPlayers();
  }

  void _initializeAudioPlayers() {
    _audioPlayers = List.generate(_audioFiles.length, (index) => just_audio.AudioPlayer());
    _playerStates = [];
    _durations = List.filled(_audioFiles.length, Duration.zero);
    _positions = List.filled(_audioFiles.length, Duration.zero);
    _trackVolumes = List.filled(_audioFiles.length, 1.0);
    _trackSpeeds = List.filled(_audioFiles.length, 1.0);
    _trackPitches = List.filled(_audioFiles.length, 1.0);
    
    // Set up listeners for each player
    for (int i = 0; i < _audioPlayers.length; i++) {
      _setupPlayerListeners(i);
    }
  }

  void _setupPlayerListeners(int index) {
    _audioPlayers[index].playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          // Ensure the list is large enough
          while (_playerStates.length <= index) {
            _playerStates.add(state);
          }
          _playerStates[index] = state;
        });
      }
    });

    _audioPlayers[index].durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _durations[index] = duration ?? Duration.zero;
        });
      }
    });

    _audioPlayers[index].positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _positions[index] = position;
        });
      }
    });
  }

  Future<void> _loadAudioFiles() async {
    for (int i = 0; i < _audioFiles.length; i++) {
      try {
        await _audioPlayers[i].setFilePath(_audioFiles[i]);
      } catch (e) {
        print('Error loading audio file ${_audioFiles[i]}: $e');
      }
    }
  }

  Future<void> _mergeTracks() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _showSnackBar('Storage permission required to save merged audio');
        return;
      }
      
      _showSnackBar('Preparing audio files...');
      
      // Calculate final values for each track
      List<double> finalVolumes = [];
      List<double> finalSpeeds = [];
      List<double> finalPitches = [];
      
      for (int i = 0; i < _audioFiles.length; i++) {
        finalVolumes.add(_masterVolume * _trackVolumes[i]);
        finalSpeeds.add(_masterSpeed * _trackSpeeds[i]);
        finalPitches.add(_masterPitch * _trackPitches[i]);
      }
      
      // Generate output filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputFileName = 'merged_audio_$timestamp.m4a';
      
      _showSnackBar('Processing audio tracks...');
      
      // Merge tracks
      final result = await AudioProcessor.mergeAudioTracks(
        inputFiles: _audioFiles,
        volumes: finalVolumes,
        speeds: finalSpeeds,
        pitches: finalPitches,
        outputFileName: outputFileName,
      );
      
      if (result != null) {
        setState(() {
          _outputFilePath = result;
        });
        
        // Initialize output player
        _outputPlayer = just_audio.AudioPlayer();
        await _outputPlayer!.setFilePath(result);
        
        _showSnackBar('Audio merged successfully!');
      } else {
        _showSnackBar('Failed to merge audio tracks');
      }
    } catch (e) {
      _showSnackBar('Error merging tracks: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _playMergedAudio() async {
    if (_outputFilePath == null || _outputPlayer == null) {
      _showSnackBar('No merged audio available. Please merge tracks first.');
      return;
    }
    
    try {
      if (_isPlaying) {
        await _outputPlayer!.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _outputPlayer!.play();
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      _showSnackBar('Error playing merged audio: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }


  void _updateMasterSpeed(double speed) {
    setState(() {
      _masterSpeed = speed;
    });
    for (int i = 0; i < _audioPlayers.length; i++) {
      _audioPlayers[i].setSpeed(speed * _trackSpeeds[i]);
    }
  }

  void _updateMasterVolume(double volume) {
    setState(() {
      _masterVolume = volume;
    });
    for (int i = 0; i < _audioPlayers.length; i++) {
      _audioPlayers[i].setVolume(volume * _trackVolumes[i]);
    }
  }

  void _updateMasterPitch(double pitch) {
    setState(() {
      _masterPitch = pitch;
    });
    for (int i = 0; i < _audioPlayers.length; i++) {
      _audioPlayers[i].setPitch(pitch * _trackPitches[i]);
    }
  }

  void _updateTrackVolume(int index, double volume) {
    setState(() {
      _trackVolumes[index] = volume;
    });
    _audioPlayers[index].setVolume(_masterVolume * volume);
  }

  void _updateTrackSpeed(int index, double speed) {
    setState(() {
      _trackSpeeds[index] = speed;
    });
    _audioPlayers[index].setSpeed(_masterSpeed * speed);
  }

  void _updateTrackPitch(int index, double pitch) {
    setState(() {
      _trackPitches[index] = pitch;
    });
    _audioPlayers[index].setPitch(_masterPitch * pitch);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    for (var player in _audioPlayers) {
      player.dispose();
    }
    _outputPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: Column(
        children: [
          // Custom header with refresh button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF2d2d2d),
            ),
            child: Row(
              children: [
                const Text(
                  'Multi-Track Audio Player',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadAudioFiles,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Master Controls
            _buildMasterControls(),
            const SizedBox(height: 24),
            
            // Track List
            _buildTrackList(),
            
            const SizedBox(height: 24),
            
            // Merge and Playback Controls
            _buildMergeControls(),
            
            const SizedBox(height: 16),
            
            // Output Audio Player
            if (_outputFilePath != null) _buildOutputPlayer(),
          ],
        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterControls() {
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
          const Text(
            'Master Controls',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // Master Speed
          _buildControlSlider(
            'Speed',
            _masterSpeed,
            0.5,
            2.0,
            (value) => _updateMasterSpeed(value),
            Icons.speed,
          ),
          
          const SizedBox(height: 16),
          
          // Master Volume
          _buildControlSlider(
            'Volume',
            _masterVolume,
            0.0,
            1.0,
            (value) => _updateMasterVolume(value),
            Icons.volume_up,
          ),
          
          const SizedBox(height: 16),
          
          // Master Pitch
          _buildControlSlider(
            'Pitch',
            _masterPitch,
            0.5,
            2.0,
            (value) => _updateMasterPitch(value),
            Icons.music_note,
          ),
        ],
      ),
    );
  }

  Widget _buildControlSlider(String label, double value, double min, double max,
      Function(double) onChanged, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.blue,
                  inactiveTrackColor: Colors.grey[600],
                  thumbColor: Colors.blue,
                  overlayColor: Colors.blue.withOpacity(0.2),
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
              Text(
                '${value.toStringAsFixed(2)}x',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrackList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tracks',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        ...List.generate(_audioFiles.length, (index) {
          return _buildTrackCard(index);
        }),
      ],
    );
  }

  Widget _buildTrackCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2d2d2d),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Track header
          Row(
            children: [
              Icon(
                Icons.music_note,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _trackNames[index],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                _formatDuration(_positions[index]),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Text(
                ' / ',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                _formatDuration(_durations[index]),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Track controls
          Row(
            children: [
              Expanded(
                child: _buildTrackControlSlider(
                  'Vol',
                  _trackVolumes[index],
                  0.0,
                  1.0,
                  (value) => _updateTrackVolume(index, value),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTrackControlSlider(
                  'Speed',
                  _trackSpeeds[index],
                  0.5,
                  2.0,
                  (value) => _updateTrackSpeed(index, value),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTrackControlSlider(
                  'Pitch',
                  _trackPitches[index],
                  0.5,
                  2.0,
                  (value) => _updateTrackPitch(index, value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrackControlSlider(String label, double value, double min,
      double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.blue,
            inactiveTrackColor: Colors.grey[600],
            thumbColor: Colors.blue,
            overlayColor: Colors.blue.withOpacity(0.2),
            trackHeight: 3,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        Text(
          '${value.toStringAsFixed(2)}x',
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildMergeControls() {
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
        children: [
          const Text(
            'Audio Processing',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Merge button
              _buildControlButton(
                Icons.merge,
                'Merge Tracks',
                _isProcessing ? null : _mergeTracks,
                _isProcessing ? Colors.grey : Colors.blue,
                isLarge: true,
              ),
              
              // Processing indicator
              if (_isProcessing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.blue,
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isProcessing 
                ? 'Processing audio... This may take a moment.'
                : 'Adjust track parameters above, then merge to create output file.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOutputPlayer() {
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
          const Text(
            'Merged Audio Output',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Play/Pause button for merged audio
              _buildControlButton(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                _isPlaying ? 'Pause' : 'Play',
                _playMergedAudio,
                _isPlaying ? Colors.orange : Colors.green,
                isLarge: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Output file: ${_outputFilePath?.split('/').last ?? 'Unknown'}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, String label, VoidCallback? onPressed,
      Color color, {bool isLarge = false}) {
    return Column(
      children: [
        Container(
          width: isLarge ? 60 : 50,
          height: isLarge ? 60 : 50,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: Colors.white,
              size: isLarge ? 30 : 24,
            ),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
