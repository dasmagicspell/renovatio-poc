import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:just_audio/just_audio.dart';
import '../models/session.dart';
import '../services/session_storage_service.dart';
import 'session_details_page.dart';

class NewSessionPage extends StatefulWidget {
  const NewSessionPage({super.key});

  @override
  State<NewSessionPage> createState() => _NewSessionPageState();
}

class _NewSessionPageState extends State<NewSessionPage> {
  final _formKey = GlobalKey<FormState>();
  final _sessionNameController = TextEditingController();
  final _narrationTextController = TextEditingController();
  
  String? _selectedActivity;
  double _durationMinutes = 30.0;
  String? _selectedBackgroundMusic;
  String? _selectedBackgroundAmbience;
  
  // Audio player for background music preview
  AudioPlayer? _backgroundMusicPreviewPlayer;
  bool _isPlayingBackgroundMusic = false;
  StreamSubscription? _playerStateSubscription;
  
  // Audio player for background ambience preview
  AudioPlayer? _backgroundAmbiencePreviewPlayer;
  bool _isPlayingBackgroundAmbience = false;
  StreamSubscription? _ambienceStateSubscription;
  
  // Activity options with their corresponding frequency bands
  final Map<String, String> _activityFrequencies = {
    'Relax': 'Alpha 10Hz',
    'Sleep': 'Delta 2Hz',
    'Exercise': 'Beta 20Hz',
    'Meditate': 'Theta 6Hz',
    'Focus': 'Beta 20Hz',
    'Study': 'Alpha 10Hz',
    'Anxiety Relief': 'Theta 6Hz',
    'Energy Boost': 'Gamma 40Hz',
  };
  
  List<String> get _activities => _activityFrequencies.keys.toList();
  
  String _getFrequencyForActivity(String activity) {
    return _activityFrequencies[activity] ?? '';
  }
  
  // Background music options
  final List<String> _backgroundMusicOptions = [
    'None',
    'Classical Music',
    'Piano Instrumental',
    'Acoustic Guitar',
    /*'Meditation Music',
    'Zen Music',
    'Chillout Music',
    'Lounge Music',
    'Spa Music',
    'Nature Ambience',
    'White Noise',
    'Brown Noise',
    'Pink Noise',
    'Ambient Electronic',*/
  ];
  
  // Background ambience options
  final List<String> _backgroundAmbienceOptions = [
    'None',
    'Forest',
    'Ocean Waves',
    'Rain',
    'Birds Chirping',
    /*'Crackling Fire',
    'Waterfall',
    'Wind',
    'Desert Wind',
    'Tropical Beach',
    'Mountain Stream',
    'Night Sounds',
    'Zen Garden',
    'Thunderstorm',*/
  ];
  
  @override
  void dispose() {
    _sessionNameController.dispose();
    _narrationTextController.dispose();
    _playerStateSubscription?.cancel();
    _backgroundMusicPreviewPlayer?.dispose();
    _ambienceStateSubscription?.cancel();
    _backgroundAmbiencePreviewPlayer?.dispose();
    super.dispose();
  }
  
  /// Convert background music name to asset filename
  /// Example: "Classical Music" -> "classical-music.mp3"
  String _getBackgroundMusicFilename(String musicName) {
    if (musicName == 'None') return '';
    return '${musicName.toLowerCase().replaceAll(' ', '-')}.mp3';
  }
  
  /// Convert background ambience name to asset filename
  /// Example: "Ocean Waves" -> "ocean-waves.mp3"
  String _getBackgroundAmbienceFilename(String ambienceName) {
    if (ambienceName == 'None') return '';
    return '${ambienceName.toLowerCase().replaceAll(' ', '-')}.mp3';
  }
  
  /// Play preview of selected background music
  Future<void> _playBackgroundMusicPreview() async {
    if (_selectedBackgroundMusic == null || 
        _selectedBackgroundMusic == 'None' || 
        _isPlayingBackgroundMusic) {
      return;
    }
    
    try {
      // Stop any currently playing audio
      await _stopBackgroundMusicPreview();
      
      // Stop any existing player and cancel subscription
      await _stopBackgroundMusicPreview();
      
      // Create new player
      _backgroundMusicPreviewPlayer = AudioPlayer();
      
      // Listen to player state changes
      _playerStateSubscription = _backgroundMusicPreviewPlayer!.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlayingBackgroundMusic = state.playing;
          });
        }
      });
      
      // Get filename
      final filename = _getBackgroundMusicFilename(_selectedBackgroundMusic!);
      final assetPath = 'assets/audio/background-music/$filename';
      
      // Load and play
      await _backgroundMusicPreviewPlayer!.setAsset(assetPath);
      await _backgroundMusicPreviewPlayer!.play();
      
      // Update state immediately
      if (mounted) {
        setState(() {
          _isPlayingBackgroundMusic = true;
        });
      }
    } catch (e) {
      print('Error playing background music preview: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing preview: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Stop background music preview
  Future<void> _stopBackgroundMusicPreview() async {
    // Cancel subscription
    await _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
    
    if (_backgroundMusicPreviewPlayer != null) {
      try {
        await _backgroundMusicPreviewPlayer!.stop();
        await _backgroundMusicPreviewPlayer!.dispose();
        _backgroundMusicPreviewPlayer = null;
      } catch (e) {
        print('Error stopping background music preview: $e');
      }
    }
    
    if (mounted) {
      setState(() {
        _isPlayingBackgroundMusic = false;
      });
    }
  }
  
  /// Play preview of selected background ambience
  Future<void> _playBackgroundAmbiencePreview() async {
    if (_selectedBackgroundAmbience == null || 
        _selectedBackgroundAmbience == 'None' || 
        _isPlayingBackgroundAmbience) {
      return;
    }
    
    try {
      // Stop any existing player and cancel subscription
      await _stopBackgroundAmbiencePreview();
      
      // Create new player
      _backgroundAmbiencePreviewPlayer = AudioPlayer();
      
      // Listen to player state changes
      _ambienceStateSubscription = _backgroundAmbiencePreviewPlayer!.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlayingBackgroundAmbience = state.playing;
          });
        }
      });
      
      // Get filename
      final filename = _getBackgroundAmbienceFilename(_selectedBackgroundAmbience!);
      final assetPath = 'assets/audio/background-audio/$filename';
      
      // Load and play
      await _backgroundAmbiencePreviewPlayer!.setAsset(assetPath);
      await _backgroundAmbiencePreviewPlayer!.play();
      
      // Update state immediately
      if (mounted) {
        setState(() {
          _isPlayingBackgroundAmbience = true;
        });
      }
    } catch (e) {
      print('Error playing background ambience preview: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing preview: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Stop background ambience preview
  Future<void> _stopBackgroundAmbiencePreview() async {
    // Cancel subscription
    await _ambienceStateSubscription?.cancel();
    _ambienceStateSubscription = null;
    
    if (_backgroundAmbiencePreviewPlayer != null) {
      try {
        await _backgroundAmbiencePreviewPlayer!.stop();
        await _backgroundAmbiencePreviewPlayer!.dispose();
        _backgroundAmbiencePreviewPlayer = null;
      } catch (e) {
        print('Error stopping background ambience preview: $e');
      }
    }
    
    if (mounted) {
      setState(() {
        _isPlayingBackgroundAmbience = false;
      });
    }
  }
  
  Future<void> _createSession() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Create a new soundscape
        final session = Session(
          id: const Uuid().v4(),
          name: _sessionNameController.text.trim(),
          activity: _selectedActivity!,
          durationMinutes: _durationMinutes.toInt(),
          backgroundMusic: _selectedBackgroundMusic!,
          backgroundAmbience: _selectedBackgroundAmbience ?? 'None',
          narrationText: _narrationTextController.text.trim(),
          createdAt: DateTime.now(),
        );
        
        // Save to local storage
        await SessionStorageService.saveSession(session);
        
        // Print for debugging
        print('=== Session Saved ===');
        print('Session Name: ${session.name}');
        print('Activity: ${session.activity}');
        print('Duration: ${session.durationMinutes} minutes');
        print('Background Music: ${session.backgroundMusic}');
        print('Background Ambience: ${session.backgroundAmbience}');
        print('Narration Text: ${session.narrationText}');
        print('ID: ${session.id}');
        print('=====================');
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Soundscape created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to soundscape details page
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SessionDetailsPage(session: session),
            ),
          );
        }
      } catch (e) {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating soundscape: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  String _formatDuration(double minutes) {
    final mins = minutes.toInt();
    if (mins == 60) {
      return '1 hour';
    } else {
      return '$mins minutes';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
          title: const Text(
          'New Soundscape',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2d2d2d),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
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
                          Icons.add_circle_outline,
                          color: Colors.blue,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Create New Soundscape',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Configure your personalized binaural audio soundscape',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Soundscape Name Field
              _buildSectionTitle('Soundscape Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _sessionNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter a name for this soundscape',
                  hintStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF2d2d2d),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a soundscape name';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // Activity Field
              _buildSectionTitle('Goal'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedActivity,
                decoration: InputDecoration(
                  hintText: 'Select your goal',
                  hintStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF2d2d2d),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
                dropdownColor: const Color(0xFF2d2d2d),
                style: const TextStyle(color: Colors.white),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                items: _activities.map((activity) {
                  final frequency = _getFrequencyForActivity(activity);
                  return DropdownMenuItem<String>(
                    value: activity,
                    child: Text('$activity ($frequency)'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedActivity = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select an activity';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // Duration Field
              _buildSectionTitle('Duration'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2d2d2d),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: Column(
                  children: [
                    Text(
                      _formatDuration(_durationMinutes),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: _durationMinutes,
                      min: 30.0,
                      max: 60.0,
                      divisions: 6, // 30, 35, 40, 45, 50, 55, 60
                      activeColor: Colors.blue,
                      inactiveColor: Colors.grey[700],
                      label: _formatDuration(_durationMinutes),
                      onChanged: (value) {
                        setState(() {
                          _durationMinutes = value;
                        });
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '30 min',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          '1 hour',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Background Music Field
              _buildSectionTitle('Background Music'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedBackgroundMusic,
                      decoration: InputDecoration(
                        hintText: 'Select background music',
                        hintStyle: TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF2d2d2d),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                      dropdownColor: const Color(0xFF2d2d2d),
                      style: const TextStyle(color: Colors.white),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      items: _backgroundMusicOptions.map((music) {
                        return DropdownMenuItem<String>(
                          value: music,
                          child: Text(music),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        // Stop current audio if playing
                        if (_isPlayingBackgroundMusic) {
                          await _stopBackgroundMusicPreview();
                        }
                        setState(() {
                          _selectedBackgroundMusic = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select background music';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: (_selectedBackgroundMusic != null && 
                               _selectedBackgroundMusic != 'None')
                        ? (_isPlayingBackgroundMusic 
                            ? _stopBackgroundMusicPreview 
                            : _playBackgroundMusicPreview)
                        : null,
                    icon: Icon(
                      _isPlayingBackgroundMusic ? Icons.stop : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: (_selectedBackgroundMusic != null && 
                                     _selectedBackgroundMusic != 'None')
                          ? (_isPlayingBackgroundMusic 
                              ? Colors.red 
                              : Colors.green)
                          : const Color(0xFF2d2d2d),
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: (_selectedBackgroundMusic != null && 
                                 _selectedBackgroundMusic != 'None')
                              ? (_isPlayingBackgroundMusic 
                                  ? Colors.red.shade700 
                                  : Colors.green.shade700)
                              : Colors.grey[700]!,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Background Ambience Field
              _buildSectionTitle('Background Ambience'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedBackgroundAmbience,
                      decoration: InputDecoration(
                        hintText: 'Select background ambience',
                        hintStyle: TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF2d2d2d),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                      dropdownColor: const Color(0xFF2d2d2d),
                      style: const TextStyle(color: Colors.white),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      items: _backgroundAmbienceOptions.map((ambience) {
                        return DropdownMenuItem<String>(
                          value: ambience,
                          child: Text(ambience),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        // Stop current audio if playing
                        if (_isPlayingBackgroundAmbience) {
                          await _stopBackgroundAmbiencePreview();
                        }
                        setState(() {
                          _selectedBackgroundAmbience = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: (_selectedBackgroundAmbience != null && 
                               _selectedBackgroundAmbience != 'None')
                        ? (_isPlayingBackgroundAmbience 
                            ? _stopBackgroundAmbiencePreview 
                            : _playBackgroundAmbiencePreview)
                        : null,
                    icon: Icon(
                      _isPlayingBackgroundAmbience ? Icons.stop : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: (_selectedBackgroundAmbience != null && 
                                     _selectedBackgroundAmbience != 'None')
                          ? (_isPlayingBackgroundAmbience 
                              ? Colors.red 
                              : Colors.green)
                          : const Color(0xFF2d2d2d),
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: (_selectedBackgroundAmbience != null && 
                                 _selectedBackgroundAmbience != 'None')
                              ? (_isPlayingBackgroundAmbience 
                                  ? Colors.red.shade700 
                                  : Colors.green.shade700)
                              : Colors.grey[700]!,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Narration Text Field
              _buildSectionTitle('Narration Text'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _narrationTextController,
                style: const TextStyle(color: Colors.white),
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Enter the words you want to be narrated during the soundscape...',
                  hintStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF2d2d2d),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Create Soundscape Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _createSession,
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text(
                    'Create Soundscape',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

