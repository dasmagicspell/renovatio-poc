import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
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
  /// Carrier frequency (Hz) for the binaural tone.
  double _baseFrequencyHz = 200.0;
  /// Beat frequency (Hz) within the selected goal's band range.
  double _beatFrequencyHz = 2.0;
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

  // Per-layer volumes (persisted to Session)
  double _binauralVolume = 0.8;
  double _musicVolume = 0.1;
  double _ambienceVolume = 0.1;
  double _narrationVolume = 0.35;

  // Full soundscape preview state
  bool _isPreviewingAll = false;
  bool _isLoadingFullPreview = false;
  AudioPlayer? _binauralPreviewPlayer;
  StreamSubscription? _binauralPreviewStateSubscription;

  static const _primary = Color(0xFF7BC4B8);
  static const _secondary = Color(0xFFB8A4D4);
  static const _background = Color(0xFFF3E4D7);
  static const _surface = Color(0xFFEDEAE6);
  static const _textPrimary = Color(0xFF2F2F2F);
  static const _textSecondary = Color(0xFF7A7570);
  static const _border = Color(0xFFD9D0C8);
  
  // Activity options mapped to their brainwave band name.
  static const Map<String, String> _activityBand = {
    'Sleep': 'Delta',
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

  List<String> get _activities => _activityBand.keys.toList();

  String _bandForActivity(String activity) =>
      _activityBand[activity] ?? 'Alpha';
  
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
    _binauralPreviewStateSubscription?.cancel();
    _binauralPreviewPlayer?.dispose();
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
    if (_isPreviewingAll) await _stopFullPreview();
    
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
    if (_isPreviewingAll) await _stopFullPreview();
    
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
    if (_isPreviewingAll) await _stopFullPreview();

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
  
  // ---------------------------------------------------------------------------
  // Binaural preview (pure-Dart WAV synthesis, no FFmpeg)
  // ---------------------------------------------------------------------------

  /// Synthesises a short stereo WAV entirely in Dart and returns the temp path.
  Future<String> _generateBinauralPreviewWav({
    required double baseFrequencyHz,
    required double beatFrequencyHz,
    int durationSeconds = 5,
  }) async {
    const sampleRate = 44100;
    const numChannels = 2;
    const bitsPerSample = 16;
    final numSamples = sampleRate * durationSeconds;
    final dataBytes = numSamples * numChannels * 2;

    final wav = ByteData(44 + dataBytes);
    int o = 0;

    void writeAscii(String s) {
      for (final c in s.codeUnits) {
        wav.setUint8(o++, c);
      }
    }

    writeAscii('RIFF');
    wav.setUint32(o, 36 + dataBytes, Endian.little); o += 4;
    writeAscii('WAVE');
    writeAscii('fmt ');
    wav.setUint32(o, 16, Endian.little); o += 4;
    wav.setUint16(o, 1, Endian.little); o += 2;
    wav.setUint16(o, numChannels, Endian.little); o += 2;
    wav.setUint32(o, sampleRate, Endian.little); o += 4;
    wav.setUint32(o, sampleRate * numChannels * 2, Endian.little); o += 4;
    wav.setUint16(o, numChannels * 2, Endian.little); o += 2;
    wav.setUint16(o, bitsPerSample, Endian.little); o += 2;
    writeAscii('data');
    wav.setUint32(o, dataBytes, Endian.little); o += 4;

    final rightFreq = baseFrequencyHz + beatFrequencyHz;
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final left = (sin(2 * pi * baseFrequencyHz * t) * 32767).round().clamp(-32768, 32767);
      final right = (sin(2 * pi * rightFreq * t) * 32767).round().clamp(-32768, 32767);
      wav.setInt16(o, left, Endian.little); o += 2;
      wav.setInt16(o, right, Endian.little); o += 2;
    }

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/binaural_preview.wav');
    await file.writeAsBytes(wav.buffer.asUint8List());
    return file.path;
  }

  Future<void> _stopBinauralPreview() async {
    await _binauralPreviewStateSubscription?.cancel();
    _binauralPreviewStateSubscription = null;
    if (_binauralPreviewPlayer != null) {
      try {
        await _binauralPreviewPlayer!.stop();
        await _binauralPreviewPlayer!.dispose();
        _binauralPreviewPlayer = null;
      } catch (_) {}
    }
  }

  Future<void> _startFullPreview() async {
    if (_isPreviewingAll || _isLoadingFullPreview) return;

    final hasBinaural = _selectedActivity != null;
    final hasMusic = _selectedBackgroundMusic != null && _selectedBackgroundMusic != 'None';
    final hasAmbience = _selectedBackgroundAmbience != null && _selectedBackgroundAmbience != 'None';
    final hasNarration = _selectedVoice?.previewUrl != null &&
        _selectedVoice!.previewUrl!.isNotEmpty;

    if (!hasBinaural && !hasMusic && !hasAmbience && !hasNarration) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Select at least one layer (goal, music, ambience, or voice) to preview.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isLoadingFullPreview = true);

    // Stop any individually-playing previews first.
    await _stopBackgroundMusicPreview();
    await _stopBackgroundAmbiencePreview();
    await _stopVoicePreview();
    await _stopBinauralPreview();

    try {
      // Layer 1: Binaural (synthesised WAV)
      if (hasBinaural) {
        try {
          final wavPath = await _generateBinauralPreviewWav(
            baseFrequencyHz: _baseFrequencyHz,
            beatFrequencyHz: _beatFrequencyHz,
          );
          _binauralPreviewPlayer = AudioPlayer();
          _binauralPreviewStateSubscription =
              _binauralPreviewPlayer!.playerStateStream.listen((_) {
            if (mounted) setState(() {});
          });
          await _binauralPreviewPlayer!.setFilePath(wavPath);
          await _binauralPreviewPlayer!.setLoopMode(LoopMode.one);
          await _binauralPreviewPlayer!.setVolume(_binauralVolume);
          unawaited(_binauralPreviewPlayer!.play());
        } catch (e) {
          debugPrint('Full preview – binaural error: $e');
        }
      }

      // Layer 2: Background music
      if (hasMusic) {
        try {
          final assetPath = await _resolvePreviewAssetPath(
            folder: 'assets/audio/background-music',
            selectedName: _selectedBackgroundMusic!,
          );
          if (assetPath != null) {
            _backgroundMusicPreviewPlayer = AudioPlayer();
            _playerStateSubscription =
                _backgroundMusicPreviewPlayer!.playerStateStream.listen((state) {
              if (mounted) setState(() => _isPlayingBackgroundMusic = state.playing);
            });
            await _backgroundMusicPreviewPlayer!.setAsset(assetPath);
            await _backgroundMusicPreviewPlayer!.setLoopMode(LoopMode.one);
            await _backgroundMusicPreviewPlayer!.setVolume(_musicVolume);
            unawaited(_backgroundMusicPreviewPlayer!.play());
            if (mounted) setState(() => _isPlayingBackgroundMusic = true);
          }
        } catch (e) {
          debugPrint('Full preview – music error: $e');
        }
      }

      // Layer 3: Ambience
      if (hasAmbience) {
        try {
          final assetPath = await _resolvePreviewAssetPath(
            folder: 'assets/audio/background-audio',
            selectedName: _selectedBackgroundAmbience!,
          );
          if (assetPath != null) {
            _backgroundAmbiencePreviewPlayer = AudioPlayer();
            _ambienceStateSubscription =
                _backgroundAmbiencePreviewPlayer!.playerStateStream.listen((state) {
              if (mounted) setState(() => _isPlayingBackgroundAmbience = state.playing);
            });
            await _backgroundAmbiencePreviewPlayer!.setAsset(assetPath);
            await _backgroundAmbiencePreviewPlayer!.setLoopMode(LoopMode.one);
            await _backgroundAmbiencePreviewPlayer!.setVolume(_ambienceVolume);
            unawaited(_backgroundAmbiencePreviewPlayer!.play());
            if (mounted) setState(() => _isPlayingBackgroundAmbience = true);
          }
        } catch (e) {
          debugPrint('Full preview – ambience error: $e');
        }
      }

      // Layer 4: Narration voice sample (not looped – plays once)
      if (hasNarration) {
        try {
          _voicePreviewPlayer = AudioPlayer();
          _voiceStateSubscription =
              _voicePreviewPlayer!.playerStateStream.listen((state) {
            if (state.processingState == ProcessingState.completed) {
              unawaited(_stopVoicePreview());
              return;
            }
            if (mounted) {
              setState(() {
                _isPlayingVoicePreview = state.playing;
                if (state.playing) _isLoadingVoicePreview = false;
              });
            }
          });
          await _voicePreviewPlayer!.setUrl(_selectedVoice!.previewUrl!);
          await _voicePreviewPlayer!.setVolume(_narrationVolume);
          unawaited(_voicePreviewPlayer!.play());
          if (mounted) setState(() => _isPlayingVoicePreview = true);
        } catch (e) {
          debugPrint('Full preview – narration error: $e');
        }
      }

      if (mounted) setState(() => _isPreviewingAll = true);
    } catch (e) {
      await _stopFullPreview();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting preview: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingFullPreview = false);
    }
  }

  Future<void> _stopFullPreview() async {
    await _stopBinauralPreview();
    await _stopBackgroundMusicPreview();
    await _stopBackgroundAmbiencePreview();
    await _stopVoicePreview();
    if (mounted) setState(() => _isPreviewingAll = false);
  }

  // ---------------------------------------------------------------------------

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

      final generated = await BinauralAudioGenerator.generateSessionBinauralClip(
        sessionId: sessionId,
        baseFrequencyHz: _baseFrequencyHz,
        beatFrequencyHz: _beatFrequencyHz,
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

      // Stop any running preview before creating the session.
      if (_isPreviewingAll) await _stopFullPreview();

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
        binauralBeatFrequencyHz: _beatFrequencyHz,
        binauralClipRelativePath: clipRelativePath,
        binauralVolume: _binauralVolume,
        backgroundMusicVolume: _musicVolume,
        ambienceVolume: _ambienceVolume,
        narrationVolume: _narrationVolume,
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

              // Description & Duration Card
              _buildFormCard(
                icon: Icons.edit_note_outlined,
                title: 'Session',
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

              // Goal & Binaural Frequency Card
              _buildFormCard(
                icon: Icons.tune,
                title: 'Goal',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('GOAL'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedActivity,
                      decoration: _fieldDecoration(hint: 'Select your goal'),
                      dropdownColor: _surface,
                      style: const TextStyle(color: _textPrimary),
                      icon: const Icon(Icons.arrow_drop_down, color: _textSecondary),
                      items: _activities.map((activity) {
                        final band = _bandForActivity(activity);
                        return DropdownMenuItem<String>(
                          value: activity,
                          child: Text('$activity ($band)'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedActivity = value;
                          if (value != null) {
                            // Reset beat frequency to the goal's default when goal changes.
                            _beatFrequencyHz =
                                BinauralGoalFrequencies.defaultBeatHzForGoal(value);
                          }
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
                      const SizedBox(height: 16),
                      _buildFieldLabel('BEAT FREQUENCY'),
                      const SizedBox(height: 4),
                      Builder(builder: (context) {
                        final range = BinauralGoalFrequencies.bandRangeForGoal(
                          _selectedActivity!,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: _primary,
                                inactiveTrackColor: _primary.withOpacity(0.15),
                                thumbColor: _primary,
                                overlayColor: _primary.withOpacity(0.12),
                                valueIndicatorColor: _primary,
                                valueIndicatorTextStyle:
                                    const TextStyle(color: Colors.white),
                              ),
                              child: Slider(
                                value: _beatFrequencyHz.clamp(
                                  range.minHz,
                                  range.maxHz,
                                ),
                                min: range.minHz,
                                max: range.maxHz,
                                divisions: range.divisions,
                                label: '${_beatFrequencyHz.toStringAsFixed(1)} Hz',
                                onChanged: (value) {
                                  setState(() => _beatFrequencyHz = value);
                                },
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${range.minHz.toStringAsFixed(1)} Hz',
                                  style: TextStyle(
                                    color: _textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _primary.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_beatFrequencyHz.toStringAsFixed(1)} Hz · '
                                    '${_bandForActivity(_selectedActivity!)}',
                                    style: const TextStyle(
                                      color: _primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${range.maxHz.toStringAsFixed(0)} Hz',
                                  style: TextStyle(
                                    color: _textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }),
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
                    const SizedBox(height: 16),
                    _buildVolumeRow(
                      value: _binauralVolume,
                      onChanged: (v) {
                        setState(() => _binauralVolume = v);
                        _binauralPreviewPlayer?.setVolume(v);
                      },
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
                    const SizedBox(height: 12),
                    _buildVolumeRow(
                      value: _musicVolume,
                      onChanged: (v) {
                        setState(() => _musicVolume = v);
                        _backgroundMusicPreviewPlayer?.setVolume(v);
                      },
                    ),
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
                    const SizedBox(height: 12),
                    _buildVolumeRow(
                      value: _ambienceVolume,
                      onChanged: (v) {
                        setState(() => _ambienceVolume = v);
                        _backgroundAmbiencePreviewPlayer?.setVolume(v);
                      },
                    ),
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
                    const SizedBox(height: 12),
                    _buildVolumeRow(
                      value: _narrationVolume,
                      onChanged: (v) {
                        setState(() => _narrationVolume = v);
                        _voicePreviewPlayer?.setVolume(v);
                      },
                    ),
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
              
              const SizedBox(height: 16),

              // Preview Soundscape Card
              _buildFormCard(
                icon: Icons.hearing,
                title: 'Preview Soundscape',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Listen to all active layers at the volumes you set before creating.',
                      style: TextStyle(color: _textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingFullPreview
                            ? null
                            : (_isPreviewingAll ? _stopFullPreview : _startFullPreview),
                        icon: _isLoadingFullPreview
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _isPreviewingAll
                                    ? Icons.stop_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                        label: Text(
                          _isLoadingFullPreview
                              ? 'Preparing preview…'
                              : _isPreviewingAll
                                  ? 'Stop Preview'
                                  : 'Preview Soundscape',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isPreviewingAll
                              ? const Color(0xFFD4867A)
                              : _secondary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    if (_isPreviewingAll) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLayerIndicator(
                            icon: Icons.headphones,
                            label: 'Binaural',
                            active: _binauralPreviewPlayer != null,
                          ),
                          const SizedBox(width: 12),
                          _buildLayerIndicator(
                            icon: Icons.music_note,
                            label: 'Music',
                            active: _isPlayingBackgroundMusic,
                          ),
                          const SizedBox(width: 12),
                          _buildLayerIndicator(
                            icon: Icons.park,
                            label: 'Ambience',
                            active: _isPlayingBackgroundAmbience,
                          ),
                          const SizedBox(width: 12),
                          _buildLayerIndicator(
                            icon: Icons.record_voice_over,
                            label: 'Voice',
                            active: _isPlayingVoicePreview,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

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

  Widget _buildLayerIndicator({
    required IconData icon,
    required String label,
    required bool active,
  }) {
    final color = active ? const Color(0xFF7BAF8E) : _border;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.15) : _surface,
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: Icon(icon, size: 14, color: active ? color : _textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: active ? color : _textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
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

  Widget _buildVolumeRow({
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        const Icon(Icons.volume_up, color: _textSecondary, size: 16),
        const SizedBox(width: 6),
        _buildFieldLabel('VOLUME'),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _primary,
              inactiveTrackColor: _primary.withOpacity(0.15),
              thumbColor: _primary,
              overlayColor: _primary.withOpacity(0.12),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              valueIndicatorColor: _primary,
              valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontSize: 11),
            ),
            child: Slider(
              value: value,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              label: '${(value * 100).round()}%',
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            '${(value * 100).round()}%',
            style: const TextStyle(color: _textSecondary, fontSize: 12),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

}
