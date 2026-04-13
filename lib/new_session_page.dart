import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:just_audio/just_audio.dart';
import 'models/session.dart';
import 'services/session_storage_service.dart';
import 'services/elevenlabs_service.dart';
import 'services/config_service.dart';
import 'services/binaural_audio_generator.dart';
import 'services/binaural_goal_frequencies.dart';
import 'chatgpt_service.dart';
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
  /// Carrier frequency (Hz) for the binaural tone; used when generating the session clip.
  double _baseFrequencyHz = 200.0;
  bool _isCreatingSoundscape = false;
  bool _isGeneratingScript = false;
  double _durationMinutes = 15.0;
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

  // Audio player for narration voice preview
  AudioPlayer? _voicePreviewPlayer;
  bool _isPlayingVoicePreview = false;
  bool _isLoadingVoicePreview = false;
  StreamSubscription? _voiceStateSubscription;

  // ElevenLabs voices
  List<ElevenLabsVoice> _availableVoices = [];
  ElevenLabsVoice? _selectedVoice;
  bool _isLoadingVoices = false;
  String? _voicesError;

  static const _primary = Color(0xFF7BC4B8);
  static const _secondary = Color(0xFFB8A4D4);
  static const _background = Color(0xFFF3E4D7);
  static const _surface = Color(0xFFEDEAE6);
  static const _textPrimary = Color(0xFF2F2F2F);
  static const _textSecondary = Color(0xFF7A7570);
  static const _border = Color(0xFFD9D0C8);
  
  // Activity options with their corresponding frequency bands
  final Map<String, String> _activityFrequencies = {
    'Deep Sleep': 'Delta 1Hz',
    'Sleep': 'Delta 2Hz',
    'Deep Meditation': 'Delta 2Hz',
    'Pain Relief': 'Delta 2Hz',
    'Meditate': 'Theta 6Hz',
    'Anxiety Relief': 'Theta 6Hz',
    'Creativity': 'Theta 6Hz',
    'Relax': 'Alpha 10Hz',
    'Study': 'Alpha 10Hz',
    'Light Focus': 'Alpha 10Hz',
    'Exercise': 'Beta 20Hz',
    'Focus': 'Beta 20Hz',
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
  ];
  
  // Background ambience options
  final List<String> _backgroundAmbienceOptions = [
    'None',
    'Forest',
    'Ocean Waves',
    'Rain',
    'Birds Chirping',
  ];
  
  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    final apiKey = ConfigService.elevenLabsApiKey;
    if (apiKey == null) {
      setState(() {
        _voicesError = 'ElevenLabs API key not configured.';
      });
      return;
    }

    setState(() {
      _isLoadingVoices = true;
      _voicesError = null;
    });

    try {
      ElevenLabsService.initialize(apiKey);
      final voices = await ElevenLabsService.getVoices(includeLegacy: true);

      if (mounted) {
        setState(() {
          _availableVoices = voices;
          _isLoadingVoices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _voicesError = 'Failed to load voices: $e';
          _isLoadingVoices = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    _narrationTextController.dispose();
    _playerStateSubscription?.cancel();
    _backgroundMusicPreviewPlayer?.dispose();
    _ambienceStateSubscription?.cancel();
    _backgroundAmbiencePreviewPlayer?.dispose();
    _voiceStateSubscription?.cancel();
    _voicePreviewPlayer?.dispose();
    super.dispose();
  }
  
  /// Checks whether an asset exists in the bundled Flutter assets.
  Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Resolves a preview asset by trying multiple common audio extensions.
  Future<String?> _resolvePreviewAssetPath({
    required String folder,
    required String selectedName,
  }) async {
    final baseName = selectedName.toLowerCase().replaceAll(' ', '-');
    const extensions = ['.mp3', '.m4a', '.wav', '.mp4'];
    debugPrint(
      'Resolving preview asset: selected="$selectedName", folder="$folder", baseName="$baseName"',
    );

    for (final ext in extensions) {
      final candidate = '$folder/$baseName$ext';
      debugPrint('Checking asset candidate: $candidate');
      if (await _assetExists(candidate)) {
        debugPrint('Found preview asset: $candidate');
        return candidate;
      }
      debugPrint('Missing preview asset: $candidate');
    }

    debugPrint('No preview asset found for "$selectedName" in "$folder".');
    return null;
  }

  
  Future<void> _playBackgroundMusicPreview() async {
    if (_selectedBackgroundMusic == null || 
        _selectedBackgroundMusic == 'None' || 
        _isPlayingBackgroundMusic) {
      return;
    }
    
    try {
      await _stopBackgroundMusicPreview();
      _backgroundMusicPreviewPlayer = AudioPlayer();
      
      // Listen to player state changes
      _playerStateSubscription = _backgroundMusicPreviewPlayer!.playerStateStream.listen(
        (state) {
          if (mounted) {
            setState(() {
              _isPlayingBackgroundMusic = state.playing;
            });
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Background music player stream error: $error');
        },
      );

      final selectedMusic = _selectedBackgroundMusic!;
      final assetPath = await _resolvePreviewAssetPath(
        folder: 'assets/audio/background-music',
        selectedName: selectedMusic,
      );
      if (assetPath == null) {
        debugPrint(
          'Background music preview failed: selected="$selectedMusic", folder="assets/audio/background-music"',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Preview file not found for "$selectedMusic".'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      await _backgroundMusicPreviewPlayer!.setAsset(assetPath);
      await _backgroundMusicPreviewPlayer!.play();
      
      if (mounted) {
        setState(() {
          _isPlayingBackgroundMusic = true;
        });
      }
    } catch (e) {
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
  
  Future<void> _stopBackgroundMusicPreview() async {
    await _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
    
    if (_backgroundMusicPreviewPlayer != null) {
      try {
        await _backgroundMusicPreviewPlayer!.stop();
        await _backgroundMusicPreviewPlayer!.dispose();
        _backgroundMusicPreviewPlayer = null;
      } catch (e) {
        // ignore
      }
    }
    
    if (mounted) {
      setState(() {
        _isPlayingBackgroundMusic = false;
      });
    }
  }
  
  Future<void> _playBackgroundAmbiencePreview() async {
    if (_selectedBackgroundAmbience == null || 
        _selectedBackgroundAmbience == 'None' || 
        _isPlayingBackgroundAmbience) {
      return;
    }
    
    try {
      await _stopBackgroundAmbiencePreview();
      _backgroundAmbiencePreviewPlayer = AudioPlayer();
      
      // Listen to player state changes
      _ambienceStateSubscription = _backgroundAmbiencePreviewPlayer!.playerStateStream.listen(
        (state) {
          if (mounted) {
            setState(() {
              _isPlayingBackgroundAmbience = state.playing;
            });
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Background ambience player stream error: $error');
        },
      );

      final selectedAmbience = _selectedBackgroundAmbience!;
      final assetPath = await _resolvePreviewAssetPath(
        folder: 'assets/audio/background-audio',
        selectedName: selectedAmbience,
      );
      if (assetPath == null) {
        debugPrint(
          'Background ambience preview failed: selected="$selectedAmbience", folder="assets/audio/background-audio"',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Preview file not found for "$selectedAmbience".'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      await _backgroundAmbiencePreviewPlayer!.setAsset(assetPath);
      await _backgroundAmbiencePreviewPlayer!.play();
      
      if (mounted) {
        setState(() {
          _isPlayingBackgroundAmbience = true;
        });
      }
    } catch (e) {
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
  
  Future<void> _stopBackgroundAmbiencePreview() async {
    await _ambienceStateSubscription?.cancel();
    _ambienceStateSubscription = null;
    
    if (_backgroundAmbiencePreviewPlayer != null) {
      try {
        await _backgroundAmbiencePreviewPlayer!.stop();
        await _backgroundAmbiencePreviewPlayer!.dispose();
        _backgroundAmbiencePreviewPlayer = null;
      } catch (e) {
        // ignore
      }
    }
    
    if (mounted) {
      setState(() {
        _isPlayingBackgroundAmbience = false;
      });
    }
  }

  Future<void> _playVoicePreview() async {
    final selectedVoice = _selectedVoice;
    if (selectedVoice == null ||
        selectedVoice.previewUrl == null ||
        selectedVoice.previewUrl!.isEmpty ||
        _isPlayingVoicePreview ||
        _isLoadingVoicePreview) {
      return;
    }

    try {
      await _stopVoicePreview();
      if (mounted) {
        setState(() {
          _isLoadingVoicePreview = true;
        });
      }
      _voicePreviewPlayer = AudioPlayer();

      _voiceStateSubscription = _voicePreviewPlayer!.playerStateStream.listen(
        (state) {
          if (state.processingState == ProcessingState.completed) {
            unawaited(_stopVoicePreview());
            return;
          }
          if (mounted) {
            setState(() {
              _isPlayingVoicePreview = state.playing;
              if (state.playing) {
                _isLoadingVoicePreview = false;
              }
            });
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Voice preview player stream error: $error');
        },
      );

      await _voicePreviewPlayer!.setUrl(selectedVoice.previewUrl!);
      await _voicePreviewPlayer!.play();

      if (mounted) {
        setState(() {
          _isPlayingVoicePreview = true;
          _isLoadingVoicePreview = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingVoicePreview = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing voice preview: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopVoicePreview() async {
    await _voiceStateSubscription?.cancel();
    _voiceStateSubscription = null;

    if (_voicePreviewPlayer != null) {
      try {
        await _voicePreviewPlayer!.stop();
        await _voicePreviewPlayer!.dispose();
        _voicePreviewPlayer = null;
      } catch (e) {
        // ignore
      }
    }

    if (mounted) {
      setState(() {
        _isPlayingVoicePreview = false;
        _isLoadingVoicePreview = false;
      });
    }
  }
  
  Future<void> _createSession() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_isCreatingSoundscape) {
      return;
    }

    setState(() {
      _isCreatingSoundscape = true;
    });

    try {
      final sessionId = const Uuid().v4();
      final clipRelativePath =
          BinauralAudioGenerator.relativePathForSessionBinauralClip(sessionId);
      final beatHz = BinauralGoalFrequencies.beatHzForGoal(_selectedActivity!);

      final generated = await BinauralAudioGenerator.generateSessionBinauralClip(
        sessionId: sessionId,
        baseFrequencyHz: _baseFrequencyHz,
        beatFrequencyHz: beatHz,
      );

      if (!generated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not generate binaural audio. '
                'If you are on desktop, ensure ffmpeg is installed and on PATH.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      final session = Session(
        id: sessionId,
        name: _sessionNameController.text.trim(),
        activity: _selectedActivity!,
        durationMinutes: _durationMinutes.toInt(),
        backgroundMusic: _selectedBackgroundMusic!,
        backgroundAmbience: _selectedBackgroundAmbience ?? 'None',
        narrationText: _narrationTextController.text.trim(),
        narrationVoiceId: _selectedVoice?.voiceId,
        createdAt: DateTime.now(),
        binauralBaseFrequencyHz: _baseFrequencyHz,
        binauralBeatFrequencyHz: beatHz,
        binauralClipRelativePath: clipRelativePath,
      );

      await SessionStorageService.saveSession(session);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Soundscape created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SessionDetailsPage(session: session),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating soundscape: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingSoundscape = false;
        });
      }
    }
  }

  Future<void> _generateScriptUsingAI() async {
    if (_isGeneratingScript) {
      return;
    }

    final apiKey = ConfigService.openAIApiKey;
    if (apiKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OpenAI API key is not configured.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingScript = true;
    });

    try {
      ChatGPTService.initialize(apiKey);
      final generatedScript = await ChatGPTService.generateNarrationScript(
        activity: _selectedActivity,
        durationMinutes: _durationMinutes.round(),
        sessionName: _sessionNameController.text.trim().isEmpty
            ? null
            : _sessionNameController.text.trim(),
      );

      if (!mounted) return;

      if (generatedScript == null || generatedScript.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not generate a script. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      _narrationTextController.text = generatedScript.trim();
      _narrationTextController.selection = TextSelection.fromPosition(
        TextPosition(offset: _narrationTextController.text.length),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Narration script generated.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating script: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingScript = false;
        });
      }
    }
  }
  
  String _formatDuration(double minutes) {
    final mins = minutes.toInt();
    if (mins == 60) {
      return '1 hour';
    }
    if (mins == 1) {
      return '1 minute';
    }
    return '$mins minutes';
  }

  InputDecoration _fieldDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFA09890)),
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'New Soundscape',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textPrimary),
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _primary.withOpacity(0.12),
                      _secondary.withOpacity(0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _primary.withOpacity(0.20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add_circle_outline,
                        color: _primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create New Soundscape',
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Configure your personalized binaural audio soundscape',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Name & Goal Card
              _buildFormCard(
                icon: Icons.tune,
                title: 'Goal',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('DESCRIPTION'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _sessionNameController,
                      style: const TextStyle(color: _textPrimary),
                      decoration: _fieldDecoration(hint: 'e.g. Morning Focus Session'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a soundscape name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildFieldLabel('GOAL'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedActivity,
                      decoration: _fieldDecoration(hint: 'Select your goal'),
                      dropdownColor: _surface,
                      style: const TextStyle(color: _textPrimary),
                      icon: const Icon(Icons.arrow_drop_down, color: _textSecondary),
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
                    if (_selectedActivity != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.graphic_eq, size: 16, color: _primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Beat: ${_getFrequencyForActivity(_selectedActivity!)} '
                                '(${BinauralGoalFrequencies.beatHzForGoal(_selectedActivity!)} Hz)',
                                style: const TextStyle(
                                  color: _primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildFieldLabel('BASE FREQUENCY (CARRIER)'),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _primary,
                        inactiveTrackColor: _primary.withOpacity(0.15),
                        thumbColor: _primary,
                        overlayColor: _primary.withOpacity(0.12),
                        valueIndicatorColor: _primary,
                        valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                      ),
                      child: Slider(
                        value: _baseFrequencyHz,
                        min: 120,
                        max: 440,
                        divisions: 320,
                        label: '${_baseFrequencyHz.round()} Hz',
                        onChanged: (value) {
                          setState(() {
                            _baseFrequencyHz = value;
                          });
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('120 Hz', style: TextStyle(color: _textSecondary, fontSize: 12)),
                        Text(
                          '${_baseFrequencyHz.round()} Hz',
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text('440 Hz', style: TextStyle(color: _textSecondary, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'A ${BinauralAudioGenerator.sessionLoopDurationSeconds}s loop will be generated and played on repeat.',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),

              // Duration Card
              _buildFormCard(
                icon: Icons.timer_outlined,
                title: 'Duration',
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFieldLabel('SESSION LENGTH'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatDuration(_durationMinutes),
                            style: const TextStyle(
                              color: _primary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _primary,
                        inactiveTrackColor: _primary.withOpacity(0.15),
                        thumbColor: _primary,
                        overlayColor: _primary.withOpacity(0.12),
                        valueIndicatorColor: _primary,
                        valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                      ),
                      child: Slider(
                        value: _durationMinutes,
                        min: 15.0,
                        max: 60.0,
                        divisions: 45,
                        label: _formatDuration(_durationMinutes),
                        onChanged: (value) {
                          setState(() {
                            _durationMinutes = value;
                          });
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('15 mins', style: TextStyle(color: _textSecondary, fontSize: 12)),
                        Text('1 hour', style: TextStyle(color: _textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Background Music Card
              _buildFormCard(
                icon: Icons.music_note_outlined,
                title: 'Background Music',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('TRACK'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedBackgroundMusic,
                            decoration: _fieldDecoration(hint: 'Select a track'),
                            dropdownColor: _surface,
                            style: const TextStyle(color: _textPrimary),
                            icon: const Icon(Icons.arrow_drop_down, color: _textSecondary),
                            items: _backgroundMusicOptions.map((music) {
                              return DropdownMenuItem<String>(
                                value: music,
                                child: Text(music),
                              );
                            }).toList(),
                            onChanged: (value) async {
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
                        _buildPreviewButton(
                          enabled: _selectedBackgroundMusic != null &&
                              _selectedBackgroundMusic != 'None',
                          isPlaying: _isPlayingBackgroundMusic,
                          onPlay: _playBackgroundMusicPreview,
                          onStop: _stopBackgroundMusicPreview,
                        ),
                      ],
                    ),
                    if (_selectedBackgroundMusic != null &&
                        _selectedBackgroundMusic != 'None') ...[
                      const SizedBox(height: 8),
                      Text(
                        _isPlayingBackgroundMusic
                            ? 'Playing preview — tap stop when done'
                            : 'Tap play to preview this track',
                        style: TextStyle(
                          color: _isPlayingBackgroundMusic ? const Color(0xFF7BAF8E) : _textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Ambience Card
              _buildFormCard(
                icon: Icons.park_outlined,
                title: 'Ambience',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('NATURE SOUND'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedBackgroundAmbience,
                            decoration: _fieldDecoration(hint: 'Select an ambience'),
                            dropdownColor: _surface,
                            style: const TextStyle(color: _textPrimary),
                            icon: const Icon(Icons.arrow_drop_down, color: _textSecondary),
                            items: _backgroundAmbienceOptions.map((ambience) {
                              return DropdownMenuItem<String>(
                                value: ambience,
                                child: Text(ambience),
                              );
                            }).toList(),
                            onChanged: (value) async {
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
                        _buildPreviewButton(
                          enabled: _selectedBackgroundAmbience != null &&
                              _selectedBackgroundAmbience != 'None',
                          isPlaying: _isPlayingBackgroundAmbience,
                          onPlay: _playBackgroundAmbiencePreview,
                          onStop: _stopBackgroundAmbiencePreview,
                        ),
                      ],
                    ),
                    if (_selectedBackgroundAmbience != null &&
                        _selectedBackgroundAmbience != 'None') ...[
                      const SizedBox(height: 8),
                      Text(
                        _isPlayingBackgroundAmbience
                            ? 'Playing preview — tap stop when done'
                            : 'Tap play to preview this sound',
                        style: TextStyle(
                          color: _isPlayingBackgroundAmbience ? const Color(0xFF7BAF8E) : _textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Narration Card
              _buildFormCard(
                icon: Icons.record_voice_over_outlined,
                title: 'Narration',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('VOICE'),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildVoiceDropdown()),
                        const SizedBox(width: 8),
                        _buildPreviewButton(
                          enabled: _selectedVoice?.previewUrl != null &&
                              _selectedVoice!.previewUrl!.isNotEmpty,
                          isPlaying: _isPlayingVoicePreview,
                          isLoading: _isLoadingVoicePreview,
                          onPlay: _playVoicePreview,
                          onStop: _stopVoicePreview,
                        ),
                      ],
                    ),
                    if (_selectedVoice?.previewUrl != null &&
                        _selectedVoice!.previewUrl!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _isLoadingVoicePreview
                            ? 'Loading voice sample...'
                            : _isPlayingVoicePreview
                            ? 'Playing voice sample — tap stop when done'
                            : 'Tap play to preview this voice',
                        style: TextStyle(
                          color: (_isPlayingVoicePreview || _isLoadingVoicePreview)
                              ? const Color(0xFF7BAF8E)
                              : _textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildFieldLabel('SCRIPT'),
                    const SizedBox(height: 4),
                    Text(
                      'These words will be narrated by AI during your session.',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isGeneratingScript ? null : _generateScriptUsingAI,
                        icon: _isGeneratingScript
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _primary,
                                ),
                              )
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(
                          _isGeneratingScript
                              ? 'Generating Script...'
                              : 'Generate Script using AI',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primary,
                          side: BorderSide(color: _primary.withOpacity(0.45)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _narrationTextController,
                      style: const TextStyle(color: _textPrimary),
                      maxLines: 5,
                      decoration: _fieldDecoration(
                        hint: 'e.g. Breathe in slowly... hold... and release...',
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Create Soundscape Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCreatingSoundscape ? null : _createSession,
                  icon: _isCreatingSoundscape
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle, color: Colors.white),
                  label: Text(
                    _isCreatingSoundscape ? 'Generating binaural audio…' : 'Create Soundscape',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
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
  
  Widget _buildVoiceDropdown() {
    if (_isLoadingVoices) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
            ),
            const SizedBox(width: 10),
            Text(
              'Loading voices...',
              style: const TextStyle(color: _textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_voicesError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _voicesError!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: _loadVoices,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    if (_availableVoices.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: const Text(
          'No voices available',
          style: TextStyle(color: _textSecondary, fontSize: 14),
        ),
      );
    }

    return DropdownButtonFormField<ElevenLabsVoice>(
      value: _selectedVoice,
      decoration: _fieldDecoration(hint: 'Select a voice'),
      dropdownColor: _surface,
      style: const TextStyle(color: _textPrimary),
      icon: const Icon(Icons.arrow_drop_down, color: _textSecondary),
      isExpanded: true,
      items: _availableVoices.map((voice) {
        return DropdownMenuItem<ElevenLabsVoice>(
          value: voice,
          child: Row(
            children: [
              const Icon(Icons.record_voice_over, size: 16, color: _textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  voice.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _textPrimary, fontSize: 14),
                ),
              ),
              if (voice.category != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    voice.category!,
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
      onChanged: (voice) async {
        if (_isPlayingVoicePreview || _isLoadingVoicePreview) {
          await _stopVoicePreview();
        }
        setState(() {
          _selectedVoice = voice;
        });
      },
    );
  }

  Widget _buildPreviewButton({
    required bool enabled,
    required bool isPlaying,
    bool isLoading = false,
    required VoidCallback onPlay,
    required VoidCallback onStop,
  }) {
    final color = isPlaying ? const Color(0xFFD4867A) : const Color(0xFF7BAF8E);
    return IconButton(
      onPressed: (enabled && !isLoading) ? (isPlaying ? onStop : onPlay) : null,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(
              isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
              color: enabled ? Colors.white : _textSecondary,
            ),
      style: IconButton.styleFrom(
        backgroundColor: enabled ? color : _border,
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildFormCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: _primary, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          // Card body
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: _textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }

}
