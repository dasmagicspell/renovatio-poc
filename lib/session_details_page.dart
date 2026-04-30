import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'models/session.dart';
import 'heart_rate_service.dart';
import 'services/openai_service.dart';
import 'services/elevenlabs_service.dart';
import 'services/config_service.dart';
import 'services/binaural_audio_generator.dart';
import 'services/user_music_library_service.dart';
import 'audio_processor.dart';

class SessionDetailsPage extends StatefulWidget {
  final Session session;

  const SessionDetailsPage({
    super.key,
    required this.session,
  });

  @override
  State<SessionDetailsPage> createState() => _SessionDetailsPageState();
}

class _SessionDetailsPageState extends State<SessionDetailsPage> {
  /// Set to true to re-enable automatic binaural switching after AI heart-rate
  /// analysis. Currently disabled because all sessions use a custom FFmpeg clip
  /// and the switching logic only supports the legacy preset-file flow.
  static const bool _binauralSwitchingEnabled = false;
  AudioPlayer? _audioPlayer; // Binaural audio
  AudioPlayer? _backgroundMusicPlayer; // Background music
  AudioPlayer? _natureAmbiencePlayer; // Nature ambience
  AudioPlayer? _narrationPlayer; // Narration
  bool _isLoading = false;
  bool _isLoadingBackground = false;
  bool _isLoadingAmbience = false;
  bool _isLoadingNarration = false;
  bool _isGeneratingNarration = false;
  bool _isPlaying = false;
  bool _isPlayingBackground = false;
  bool _isPlayingAmbience = false;
  bool _isPlayingNarration = false;
  late double _volume;
  double _speed = 1.0;
  late double _backgroundVolume;
  double _backgroundSpeed = 1.0;
  String _backgroundMusicDisplayName = '';
  late double _ambienceVolume;
  double _ambienceSpeed = 1.0;
  late double _narrationVolume;
  double _narrationSpeed = 1.0;
  bool _isSessionStarted = false;

  /// Counts down while the soundscape is playing; paused when the user pauses all audio.
  Timer? _sessionClockTimer;
  /// Total length of this run in seconds (from [Session.durationMinutes]); fixed until session ends.
  int _sessionTotalSeconds = 0;
  /// Seconds left until stop (fade is included: last [_effectiveFadeSeconds] seconds ramp volume down).
  /// [ValueNotifier] so the countdown UI updates every tick even if [setState] batching misbehaves.
  final ValueNotifier<int> _sessionRemainingNotifier = ValueNotifier<int>(0);
  static const Duration _fadeOutDuration = Duration(seconds: 12);
  
  // HealthKit Observer state
  bool _isObserverInitialized = false;
  bool _isObserverActive = false;
  // ignore: unused_field
  String _observerStatus = 'Not initialized';
  List<HeartRateData> _sessionHeartRateData = [];
  DateTime? _sessionStartTime;
  
  // AI Analysis state
  bool _isAnalyzing = false;
  String? _aiAnalysis;
  String? _aiAnalysisError;
  
  // Binaural audio file tracking
  String _currentBinauralFile = 'base'; // 'base', 'increase', 'decrease'
  bool _hasAudioSwitched = false;
  
  // File paths for export
  String? _binauralAudioPath;
  String? _backgroundMusicPath;
  String? _ambiencePath;
  String? _narrationPath;
  
  // Export state
  bool _isExporting = false;
  
  @override
  void initState() {
    super.initState();
    // Restore per-layer volumes saved at creation time.
    _volume = widget.session.binauralVolume;
    _backgroundVolume = widget.session.backgroundMusicVolume;
    _ambienceVolume = widget.session.ambienceVolume;
    _narrationVolume = widget.session.narrationVolume;
    _backgroundMusicDisplayName =
        UserMusicLibraryService.isUserTrackKey(widget.session.backgroundMusic)
            ? 'Loading…'
            : widget.session.backgroundMusic;
    // Initialize ElevenLabsService for TTS
    _initializeElevenLabsService();
    if (widget.session.goalEnabled) _loadAudio();
    if (widget.session.musicEnabled) _loadBackgroundMusic();
    if (widget.session.ambienceEnabled) _loadNatureAmbience();
    if (widget.session.narrationEnabled) _loadNarration();
    _initializeObserver();
  }
  
  /// Initialize ElevenLabsService for TTS
  void _initializeElevenLabsService() {
    try {
      // Get API key from environment variables
      final apiKey = ConfigService.elevenLabsApiKey;
      if (apiKey == null) {
        throw Exception('ElevenLabs API key not configured. Please set ELEVENLABS_API_KEY in .env file');
      }
      
      ElevenLabsService.initialize(apiKey);
      
      // Optionally prefetch meditation voice (recommended for faster first use)
      ElevenLabsService.prefetchMeditationVoice().then((_) {
        print('✅ Meditation voice ready');
      }).catchError((e) {
        print('⚠️ Could not prefetch meditation voice: $e');
      });
      
      print('✅ ElevenLabsService initialized for TTS');
    } catch (e) {
      print('❌ Error initializing ElevenLabsService: $e');
    }
  }
  
  @override
  void dispose() {
    _cancelMasterClockTimer();
    _sessionRemainingNotifier.dispose();
    _audioPlayer?.dispose();
    _backgroundMusicPlayer?.dispose();
    _natureAmbiencePlayer?.dispose();
    _narrationPlayer?.dispose();
    _stopObserver();
    super.dispose();
  }
  
  /// Initialize the HealthKit observer (but don't start it yet)
  Future<void> _initializeObserver() async {
    try {
      // Initialize the observer service
      await HeartRateService.initializeObserver();
      
      // Set up callbacks
      HeartRateService.setObserverCallbacks(
        onNewHeartRateData: _onNewHeartRateData,
        onObserverError: _onObserverError,
      );
      
      setState(() {
        _isObserverInitialized = true;
        _observerStatus = 'Initialized (waiting for soundscape start)';
      });
      
      print('HealthKit observer initialized for session');
    } catch (e) {
      setState(() {
        _observerStatus = 'Error initializing: $e';
      });
      print('Error initializing HealthKit observer: $e');
    }
  }
  
  /// Start the HealthKit observer (reserved for premium users).
  // ignore: unused_element
  Future<void> _startObserver() async {
    if (!_isObserverInitialized) {
      print('⚠️ Observer not initialized, cannot start');
      return;
    }
    
    if (_isObserverActive) {
      print('ℹ️ Observer already active, skipping start');
      return;
    }
    
    try {
      print('🚀 Starting HealthKit observer...');
      await HeartRateService.startObserver();
      if (mounted) {
        setState(() {
          _isObserverActive = true;
          _observerStatus = 'Active - Monitoring heart rate';
        });
      }
      print('✅ HealthKit observer started for session');
    } catch (e) {
      print('❌ Error starting HealthKit observer: $e');
      if (mounted) {
        setState(() {
          _observerStatus = 'Error starting: $e';
        });
      }
      // Don't throw - allow session to continue without heart rate monitoring
    }
  }
  
  /// Stop the HealthKit observer
  Future<void> _stopObserver() async {
    if (!_isObserverActive) {
      print('Observer not active, skipping stop');
      return;
    }
    
    try {
      await HeartRateService.stopObserver();
      if (mounted) {
        setState(() {
          _isObserverActive = false;
          _observerStatus = 'Stopped';
        });
      }
      print('✅ HealthKit observer stopped');
    } catch (e) {
      print('❌ Error stopping HealthKit observer: $e');
      // Even if there's an error, update the state to reflect that we tried to stop
      if (mounted) {
        setState(() {
          _isObserverActive = false;
          _observerStatus = 'Error stopping: $e';
        });
      }
    }
  }
  
  /// Callback when new heart rate data is received
  void _onNewHeartRateData(List<HeartRateData> newData) {
    print("📱 Session: Received ${newData.length} new heart rate readings");
    
    setState(() {
      // Remove duplicates by checking if data already exists
      final existingTimes = _sessionHeartRateData.map((e) => e.dateTime.millisecondsSinceEpoch).toSet();
      final uniqueNewData = newData.where((newItem) => 
        !existingTimes.contains(newItem.dateTime.millisecondsSinceEpoch)
      ).toList();
      
      if (uniqueNewData.isNotEmpty) {
        // Add new data to the beginning of the list
        _sessionHeartRateData = [...uniqueNewData, ..._sessionHeartRateData];
        
        // Sort the entire list by date/time (newest first)
        _sessionHeartRateData.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        
        // Keep only the last 100 readings to avoid memory issues
        if (_sessionHeartRateData.length > 100) {
          _sessionHeartRateData = _sessionHeartRateData.take(100).toList();
        }
        
        _observerStatus = 'Active - ${_sessionHeartRateData.length} readings';
        print("📱 Session: Added ${uniqueNewData.length} new readings. Total: ${_sessionHeartRateData.length}");
        
        // If soundscape is started and we have enough data, analyze with AI
        if (_isSessionStarted && _sessionStartTime != null && _sessionHeartRateData.length >= 5) {
          _analyzeHeartRateWithAI();
        }
      }
    });
  }
  
  /// Analyze heart rate data with OpenAI
  Future<void> _analyzeHeartRateWithAI() async {
    // Prevent multiple simultaneous requests
    if (_isAnalyzing) {
      print('AI analysis already in progress, skipping...');
      return;
    }
    
    // Only analyze if we have at least 5 readings and soundscape has been running for at least 1 minute
    if (_sessionHeartRateData.length < 5 || _sessionStartTime == null) {
      return;
    }
    
    final elapsedTime = DateTime.now().difference(_sessionStartTime!);
    if (elapsedTime.inSeconds < 60) {
      // Wait at least 1 minute before first analysis
      return;
    }
    
    setState(() {
      _isAnalyzing = true;
      _aiAnalysisError = null;
    });
    
    try {
      print('🤖 Requesting AI analysis for heart rate data...');
      final analysis = await OpenAIService.analyzeHeartRateChanges(
        session: widget.session,
        heartRateData: _sessionHeartRateData,
        elapsedTime: elapsedTime,
        sessionStartTime: _sessionStartTime!,
      );
      
      if (mounted) {
        setState(() {
          _aiAnalysis = analysis;
          _isAnalyzing = false;
        });
        print('✅ AI analysis received');
        
        if (_binauralSwitchingEnabled) {
          _switchBinauralAudio('increase');
        }
      }
    } catch (e) {
      print('❌ Error getting AI analysis: $e');
      if (mounted) {
        setState(() {
          _aiAnalysisError = e.toString();
          _isAnalyzing = false;
        });
      }
    }
  }
  
  /// Callback when observer error occurs
  void _onObserverError(String error) {
    print("❌ Session: Observer error - $error");
    setState(() {
      _observerStatus = 'Error: $error';
    });
  }
  
  Future<void> _loadAudio({String? fileType, bool? wasPlaying}) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      String? audioFilePath;
      late final String resolvedBinauralLabel;

      if (widget.session.hasCustomBinauralClip) {
        final path =
            await BinauralAudioGenerator.absolutePathForSessionBinauralClip(widget.session);
        final clipFile = File(path);
        if (!await clipFile.exists()) {
          print(
            '❌ Custom binaural clip missing (expected file on disk):\n'
            '   $path\n'
            '   On macOS, paste the directory into Finder → Go → Go to Folder… to inspect.',
          );
          setState(() {
            _isLoading = false;
            _audioPlayer = null;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Binaural audio file for this soundscape is missing. '
                  'Create a new soundscape to regenerate it.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }
        audioFilePath = path;
        resolvedBinauralLabel = 'custom';
        print(
          '✅ Using custom session binaural clip: $path\n'
          '   (On macOS: Finder → Go → Go to Folder… and paste the folder path to verify the .mp3 file.)',
        );
      } else {
        // Binaural audio is only loaded from per-session generated clips (no JSON preset / asset fallback).
        print(
          '⚠️ Session ${widget.session.id} has no binauralBaseFrequencyHz / '
          'binauralBeatFrequencyHz — skipping binaural (create a new soundscape for binaural audio).',
        );
        setState(() {
          _isLoading = false;
          _audioPlayer = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This soundscape has no custom binaural clip. '
                'Create a new soundscape to generate binaural audio.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 6),
            ),
          );
        }
        return;
      }

      // Create and initialize audio player with file path
      final player = AudioPlayer();
      await player.setFilePath(audioFilePath);
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(_volume);
      await player.setSpeed(_speed);
      
      // Listen to player state changes
      player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
        }
      });
      
      // Dispose old player if it exists
      final oldPlayer = _audioPlayer;
      final shouldResume = wasPlaying ?? _isPlaying;
      
      setState(() {
        _audioPlayer = player;
        _isLoading = false;
        _currentBinauralFile = resolvedBinauralLabel;
        _binauralAudioPath = audioFilePath; // Store path for export
      });
      
      // Dispose old player after state update
      oldPlayer?.dispose();
      
      // If was playing, start the new audio
      if (shouldResume && _isSessionStarted) {
        await player.play();
      }
      
      print('Audio loaded successfully: $resolvedBinauralLabel');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _audioPlayer = null; // Clear player on error
      });
      
      // Only show error if it's not already handled (e.g., file not found is handled above)
      if (mounted && !e.toString().contains('Binaural audio file not found')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading audio: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      print('Error loading audio: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }
  
  /// Switch binaural audio file (base, increase, or decrease)
  Future<void> _switchBinauralAudio(String fileType) async {
    if (widget.session.hasCustomBinauralClip) {
      print('Custom binaural clip — skipping switch to $fileType');
      return;
    }

    if (_currentBinauralFile == fileType) {
      print('Audio file already set to $fileType');
      return;
    }
    
    if (_audioPlayer == null) {
      print('No audio player available to switch');
      return;
    }
    
    try {
      print('🔄 Switching binaural audio from $_currentBinauralFile to $fileType');
      
      // Save current playback state
      final wasPlaying = _isPlaying;
      
      // Load the new audio file
      await _loadAudio(fileType: fileType, wasPlaying: wasPlaying);
      
      setState(() {
        _hasAudioSwitched = true;
      });
      
      // Show notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.swap_horiz, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Binaural audio switched to $fileType mode'),
                ),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      print('✅ Audio switched successfully to $fileType');
    } catch (e) {
      print('❌ Error switching audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error switching audio: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  Future<void> _loadBackgroundMusic() async {
    if (widget.session.backgroundMusic == 'None') return;

    setState(() => _isLoadingBackground = true);

    if (UserMusicLibraryService.isUserTrackKey(widget.session.backgroundMusic)) {
      await _loadUserBackgroundMusic();
      return;
    }

    // --- Bundled asset path ---
    
    try {
      // Build list of possible file paths to try
      final baseName = widget.session.backgroundMusic.toLowerCase().replaceAll(' ', '-');
      final extensions = ['.mp3', '.m4a', '.wav', '.mp4'];
      final possiblePaths = <String>[];
      
      // Add paths with different extensions
      for (final ext in extensions) {
        possiblePaths.add('assets/audio/background-music/$baseName$ext');
      }
      
      // For large files, copy asset to temporary directory first
      final tempDir = await getTemporaryDirectory();
      String? loadedPath;
      File? tempFile;
      
      // Try each possible path
      for (final assetPath in possiblePaths) {
        try {
          print('Trying to load background music from: $assetPath');
          // Try to load the asset
          final byteData = await rootBundle.load(assetPath);
          print('Successfully loaded asset: $assetPath (${byteData.lengthInBytes} bytes)');
          
          // If successful, create temp file
          final fileName = assetPath.split('/').last;
          tempFile = File('${tempDir.path}/bg_$fileName');
          
          // Check if file already exists in temp
          if (!await tempFile.exists()) {
            await tempFile.writeAsBytes(byteData.buffer.asUint8List());
            print('Background music file copied to: ${tempFile.path}');
          } else {
            print('Using existing temp file: ${tempFile.path}');
          }
          
          loadedPath = assetPath;
          break; // Success, exit loop
        } catch (e) {
          // File doesn't exist, try next path
          print('Failed to load $assetPath: $e');
          continue;
        }
      }
      
      // If no file was found, log and fail silently (background music is optional)
      if (loadedPath == null || tempFile == null) {
        print('Background music not found. Tried paths: ${possiblePaths.join(", ")}');
        print('Selected background music: ${widget.session.backgroundMusic}');
        setState(() {
          _isLoadingBackground = false;
        });
        return;
      }
      
      // Create and initialize background music player
      final player = AudioPlayer();
      await player.setFilePath(tempFile.path);
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(_backgroundVolume);
      await player.setSpeed(_backgroundSpeed);
      
      // Listen to player state changes
      player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlayingBackground = state.playing;
          });
        }
      });
      
      setState(() {
        _backgroundMusicPlayer = player;
        _isLoadingBackground = false;
        _backgroundMusicPath = tempFile!.path; // Store path for export (tempFile is guaranteed non-null here)
      });
      
      print('Background music loaded successfully: $loadedPath');
    } catch (e) {
      setState(() {
        _isLoadingBackground = false;
      });
      
      print('Error loading background music: $e');
    }
  }

  /// Loads a user-uploaded background music track identified by a `user:<uuid>` key.
  Future<void> _loadUserBackgroundMusic() async {
    final trackId = UserMusicLibraryService.trackIdFromKey(
      widget.session.backgroundMusic,
    );
    if (trackId == null) {
      setState(() => _isLoadingBackground = false);
      return;
    }

    try {
      final track = await UserMusicLibraryService.getTrackById(trackId);
      final filePath = await UserMusicLibraryService.resolveFilePath(trackId);

      if (filePath == null) {
        setState(() {
          _isLoadingBackground = false;
          _backgroundMusicDisplayName = track?.displayName ?? 'Unknown Track';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Uploaded music file is missing. It may have been deleted from your library.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final player = AudioPlayer();
      await player.setFilePath(filePath);
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(_backgroundVolume);
      await player.setSpeed(_backgroundSpeed);

      player.playerStateStream.listen((state) {
        if (mounted) setState(() => _isPlayingBackground = state.playing);
      });

      setState(() {
        _backgroundMusicPlayer = player;
        _isLoadingBackground = false;
        _backgroundMusicDisplayName = track?.displayName ?? 'Custom Track';
        _backgroundMusicPath = filePath;
      });

      print('User background music loaded: ${track?.displayName}');
    } catch (e) {
      setState(() => _isLoadingBackground = false);
      print('Error loading user background music: $e');
    }
  }

  /// Maps a user-facing ambience name to its bundled asset filename (without extension).
  static String? _ambienceAssetSlug(String? ambience) {
    switch (ambience) {
      case 'Forest':
        return 'forest';
      case 'Ocean Waves':
        return 'ocean-waves';
      case 'Rain':
        return 'rain';
      case 'Birds Chirping':
        return 'birds-chirping';
      default:
        return null;
    }
  }

  Future<void> _loadNatureAmbience() async {
    final slug = _ambienceAssetSlug(widget.session.backgroundAmbience);
    if (slug == null) {
      // "None" or unrecognised — nothing to load.
      setState(() => _isLoadingAmbience = false);
      return;
    }

    setState(() {
      _isLoadingAmbience = true;
    });

    try {
      final assetPath = 'assets/audio/background-audio/$slug.mp3';
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${slug}_ambience.mp3');

      if (!await tempFile.exists()) {
        try {
          print('Attempting to load ambience: $assetPath');
          final byteData = await rootBundle.load(assetPath);
          await tempFile.writeAsBytes(byteData.buffer.asUint8List());
          print('Ambience file copied to: ${tempFile.path}');
        } catch (e) {
          print('Failed to load $assetPath: $e');
          setState(() => _isLoadingAmbience = false);
          return;
        }
      } else {
        print('Using existing temp file: ${tempFile.path}');
      }

      // Create and initialize ambience player
      final player = AudioPlayer();
      await player.setFilePath(tempFile.path);
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(_ambienceVolume);
      await player.setSpeed(_ambienceSpeed);

      player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlayingAmbience = state.playing;
          });
        }
      });

      setState(() {
        _natureAmbiencePlayer = player;
        _isLoadingAmbience = false;
        _ambiencePath = tempFile.path;
      });

      print('Ambience loaded successfully');
    } catch (e) {
      setState(() {
        _isLoadingAmbience = false;
      });
      print('Error loading ambience: $e');
    }
  }
  
  Future<void> _loadNarration() async {
    // Skip if narration text is empty
    if (widget.session.narrationText.trim().isEmpty) {
      print('No narration text provided, skipping narration loading');
      return;
    }
    
    setState(() {
      _isLoadingNarration = true;
    });
    
    try {
      // Get the narration file path based on session ID and narration text hash
      final narrationFilePath = await _getNarrationFilePath();
      final narrationFile = File(narrationFilePath);
      
      // Check if narration audio file already exists
      if (await narrationFile.exists()) {
        print('Using existing narration file: ${narrationFile.path}');
        // File exists, load it directly
        await _initializeNarrationPlayer(narrationFile.path);
      } else {
        // File doesn't exist, generate it using AI
        print('Narration file not found, generating with AI...');
        setState(() {
          _isGeneratingNarration = true;
        });
        
        try {
          // Generate narration audio using ElevenLabs TTS
          // Uses the voice chosen by the user, or auto-selects a meditation voice as fallback
          final generatedFilePath = await ElevenLabsService.generateMeditationNarration(
            text: widget.session.narrationText,
            voiceId: widget.session.narrationVoiceId,
          );
          
          if (generatedFilePath != null) {
            // Move/rename the generated file to our expected location
            final generatedFile = File(generatedFilePath);
            if (await generatedFile.exists()) {
              // Copy to our expected location
              await generatedFile.copy(narrationFilePath);
              // Optionally delete the original timestamped file
              try {
                await generatedFile.delete();
              } catch (e) {
                print('Could not delete original file: $e');
              }
              
              print('✅ Narration audio generated and saved to: $narrationFilePath');
              await _initializeNarrationPlayer(narrationFilePath);
            } else {
              throw Exception('Generated file was not created');
            }
          } else {
            throw Exception('Failed to generate narration audio');
          }
        } catch (e) {
          print('❌ Error generating narration audio: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error generating narration audio: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          setState(() {
            _isLoadingNarration = false;
            _isGeneratingNarration = false;
          });
          return;
        } finally {
          setState(() {
            _isGeneratingNarration = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingNarration = false;
        _isGeneratingNarration = false;
      });
      
      print('Error loading narration: $e');
      // Don't show error snackbar for narration as it's optional
    }
  }
  
  /// Initialize the narration audio player with the given file path
  Future<void> _initializeNarrationPlayer(String filePath) async {
    try {
      // Create and initialize narration player
      final player = AudioPlayer();
      await player.setFilePath(filePath);
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(_narrationVolume);
      await player.setSpeed(_narrationSpeed);
      
      // Listen to player state changes
      player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlayingNarration = state.playing;
          });
        }
      });
      
      setState(() {
        _narrationPlayer = player;
        _isLoadingNarration = false;
        _narrationPath = filePath; // Store path for export
      });
      
      print('Narration loaded successfully');
    } catch (e) {
      setState(() {
        _isLoadingNarration = false;
      });
      print('Error initializing narration player: $e');
      rethrow;
    }
  }
  
  Future<void> _togglePlayPause() async {
    if (_audioPlayer == null) return;
    
    try {
      if (_isPlaying) {
        await _audioPlayer!.pause();
      } else {
        await _audioPlayer!.play();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _toggleBackgroundPlayPause() async {
    if (_backgroundMusicPlayer == null) return;
    
    try {
      if (_isPlayingBackground) {
        await _backgroundMusicPlayer!.pause();
      } else {
        await _backgroundMusicPlayer!.play();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing background music: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _toggleAmbiencePlayPause() async {
    if (_natureAmbiencePlayer == null) return;
    
    try {
      if (_isPlayingAmbience) {
        await _natureAmbiencePlayer!.pause();
      } else {
        await _natureAmbiencePlayer!.play();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing nature ambience: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _toggleNarrationPlayPause() async {
    if (_narrationPlayer == null) return;
    
    try {
      if (_isPlayingNarration) {
        await _narrationPlayer!.pause();
      } else {
        await _narrationPlayer!.play();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing narration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancelMasterClockTimer() {
    _sessionClockTimer?.cancel();
    _sessionClockTimer = null;
  }

  /// Fade length in seconds, capped by total session length (fade is inside chosen duration).
  int get _effectiveFadeSeconds {
    final total = _sessionTotalSeconds;
    if (total <= 0) return 0;
    final maxF = _fadeOutDuration.inSeconds;
    return maxF < total ? maxF : total;
  }

  void _startMasterClockTimer() {
    _cancelMasterClockTimer();
    if (!_isSessionStarted || _sessionRemainingNotifier.value <= 0) {
      return;
    }

    _sessionClockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _onSessionClockTick(),
    );
  }

  /// Countdown and fade are driven synchronously each tick so seconds cannot overlap or reorder.
  void _onSessionClockTick() {
    if (!mounted || !_isSessionStarted) return;

    var next = _sessionRemainingNotifier.value - 1;
    if (next < 0) next = 0;
    _sessionRemainingNotifier.value = next;

    if (_sessionRemainingNotifier.value <= 0) {
      _cancelMasterClockTimer();
      unawaited(_completeSessionAtTimerEnd());
      return;
    }

    unawaited(_syncVolumesToRemaining());
  }

  Future<void> _completeSessionAtTimerEnd() async {
    await _restoreAllPlayerVolumes();
    if (!mounted) return;
    await _finalizeStoppedSession(
      snackBarMessage: 'Session complete',
      snackBarColor: const Color(0xFF7BAF8E),
    );
  }

  Future<void> _syncVolumesToRemaining() async {
    final r = _sessionRemainingNotifier.value;
    final fade = _effectiveFadeSeconds;
    double factor;
    if (r <= 0) {
      factor = 0;
    } else if (fade <= 0) {
      factor = 1.0;
    } else if (r > fade) {
      factor = 1.0;
    } else {
      factor = r / fade;
    }
    try {
      if (_audioPlayer != null) await _audioPlayer!.setVolume(_volume * factor);
      if (_backgroundMusicPlayer != null) {
        await _backgroundMusicPlayer!.setVolume(_backgroundVolume * factor);
      }
      if (_natureAmbiencePlayer != null) {
        await _natureAmbiencePlayer!.setVolume(_ambienceVolume * factor);
      }
      if (_narrationPlayer != null) {
        await _narrationPlayer!.setVolume(_narrationVolume * factor);
      }
    } catch (_) {}
  }

  Future<void> _restoreAllPlayerVolumes() async {
    try {
      if (_audioPlayer != null) await _audioPlayer!.setVolume(_volume);
      if (_backgroundMusicPlayer != null) {
        await _backgroundMusicPlayer!.setVolume(_backgroundVolume);
      }
      if (_natureAmbiencePlayer != null) {
        await _natureAmbiencePlayer!.setVolume(_ambienceVolume);
      }
      if (_narrationPlayer != null) {
        await _narrationPlayer!.setVolume(_narrationVolume);
      }
    } catch (_) {}
  }

  /// Stops playback and resets session UI; restores player volumes for the next start.
  Future<void> _finalizeStoppedSession({
    required String snackBarMessage,
    required Color snackBarColor,
  }) async {
    try {
      _cancelMasterClockTimer();
      await _stopObserver();

      final futures = <Future>[];
      if (_audioPlayer != null) futures.add(_audioPlayer!.stop());
      if (_backgroundMusicPlayer != null) {
        futures.add(_backgroundMusicPlayer!.stop());
      }
      if (_natureAmbiencePlayer != null) {
        futures.add(_natureAmbiencePlayer!.stop());
      }
      if (_narrationPlayer != null) futures.add(_narrationPlayer!.stop());

      await Future.wait(futures);
      await _restoreAllPlayerVolumes();

      if (mounted) {
        setState(() {
          _isSessionStarted = false;
          _sessionStartTime = null;
          _hasAudioSwitched = false;
          _currentBinauralFile =
              widget.session.hasCustomBinauralClip ? 'custom' : 'base';
          _sessionTotalSeconds = 0;
          _sessionRemainingNotifier.value = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackBarMessage),
            backgroundColor: snackBarColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ending soundscape: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startSession() async {
    // Check if this is a new session or a resume
    final isResuming = _isSessionStarted && _sessionStartTime != null;
    
    // Update state immediately so UI shows pause/stop buttons right away
    setState(() {
      _isSessionStarted = true;
      // Only set start time if this is a new session, not a resume
      if (!isResuming) {
        _sessionStartTime = DateTime.now();
        _aiAnalysis = null; // Reset analysis when starting new soundscape
        _aiAnalysisError = null;
        _sessionTotalSeconds = widget.session.durationMinutes * 60;
        _sessionRemainingNotifier.value = _sessionTotalSeconds;
      }
    });
    
    try {
      // HealthKit heart rate monitoring is reserved for premium users.
      // Observer is intentionally not started here.

      // Start all available audio players simultaneously.
      // NOTE: just_audio `play()` future may complete only when playback stops,
      // so we must not await here or the master clock won't start.
      if (_audioPlayer != null) {
        unawaited(_audioPlayer!.play());
      }
      if (_backgroundMusicPlayer != null) {
        unawaited(_backgroundMusicPlayer!.play());
      }
      if (_natureAmbiencePlayer != null) {
        unawaited(_natureAmbiencePlayer!.play());
      }
      if (_narrationPlayer != null) {
        unawaited(_narrationPlayer!.play());
      }

      await _syncVolumesToRemaining();

      if (_sessionRemainingNotifier.value <= 0) {
        await _restoreAllPlayerVolumes();
        await _finalizeStoppedSession(
          snackBarMessage: 'Session complete',
          snackBarColor: const Color(0xFF7BAF8E),
        );
        return;
      }
      _startMasterClockTimer();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isResuming ? 'Soundscape resumed' : 'Soundscape started'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // If there's an error, revert the soundscape started state
      if (mounted) {
        _cancelMasterClockTimer();
        setState(() {
          // Only reset if this was a new session, not a resume
          if (!isResuming) {
            _isSessionStarted = false;
            _sessionStartTime = null;
            _sessionTotalSeconds = 0;
            _sessionRemainingNotifier.value = 0;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${isResuming ? 'resuming' : 'starting'} soundscape: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _pauseAllAudio() async {
    _cancelMasterClockTimer();
    try {
      final futures = <Future>[];
      
      if (_audioPlayer != null && _isPlaying) {
        futures.add(_audioPlayer!.pause());
      }
      if (_backgroundMusicPlayer != null && _isPlayingBackground) {
        futures.add(_backgroundMusicPlayer!.pause());
      }
      if (_natureAmbiencePlayer != null && _isPlayingAmbience) {
        futures.add(_natureAmbiencePlayer!.pause());
      }
      if (_narrationPlayer != null && _isPlayingNarration) {
        futures.add(_narrationPlayer!.pause());
      }
      
      await Future.wait(futures);

      await _restoreAllPlayerVolumes();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Soundscape paused'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error pausing soundscape: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _stopAllAudio() async {
    _cancelMasterClockTimer();
    try {
      await _restoreAllPlayerVolumes();
      await _finalizeStoppedSession(
        snackBarMessage: 'Soundscape stopped',
        snackBarColor: Colors.red,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error stopping soundscape: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Export all audio tracks as a single merged MP3 file.
  /// File is saved to the app's documents directory (sandboxed). On a real device:
  /// - iOS: app container Documents (not visible in Files unless shared)
  /// - Android: app internal storage
  /// After export we open the share sheet so the user can save to Files / share.
  Future<void> _exportSoundscape() async {
    // Check if at least one audio is loaded
    if (_binauralAudioPath == null && 
        _backgroundMusicPath == null && 
        _ambiencePath == null && 
        _narrationPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No audio files loaded. Please wait for audio to load.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    // Don't allow exporting if any audio is still loading
    if (_isAnyAudioLoading) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isGeneratingNarration 
                ? 'Generating narration audio. Please wait...'
                : 'Audio files are still loading. Please wait...'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    setState(() {
      _isExporting = true;
    });
    
    try {
      // Collect all loaded audio files and their settings
      List<String> inputFiles = [];
      List<double> volumes = [];
      List<double> speeds = [];
      List<double> pitches = []; // Not used but required by AudioProcessor
      
      if (_binauralAudioPath != null) {
        inputFiles.add(_binauralAudioPath!);
        volumes.add(_volume);
        speeds.add(_speed);
        pitches.add(1.0);
      }
      
      if (_backgroundMusicPath != null) {
        inputFiles.add(_backgroundMusicPath!);
        volumes.add(_backgroundVolume);
        speeds.add(_backgroundSpeed);
        pitches.add(1.0);
      }
      
      if (_ambiencePath != null) {
        inputFiles.add(_ambiencePath!);
        volumes.add(_ambienceVolume);
        speeds.add(_ambienceSpeed);
        pitches.add(1.0);
      }
      
      if (_narrationPath != null) {
        inputFiles.add(_narrationPath!);
        volumes.add(_narrationVolume);
        speeds.add(_narrationSpeed);
        pitches.add(1.0);
      }
      
      if (inputFiles.isEmpty) {
        throw Exception('No audio files to export');
      }
      
      // Calculate duration in seconds
      final durationSeconds = widget.session.durationMinutes * 60;
      
      // Generate output filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = widget.session.name.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      final outputFileName = '${sanitizedName}_${timestamp}.mp3';
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exporting soundscape... This may take a moment.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Export the merged audio
      final outputPath = await AudioProcessor.exportMergedAudio(
        inputFiles: inputFiles,
        volumes: volumes,
        speeds: speeds,
        pitches: pitches,
        durationSeconds: durationSeconds,
        outputFileName: outputFileName,
      );
      
      if (outputPath != null) {
        // Get file info
        final file = File(outputPath);
        final fileSize = await file.length();
        final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
        
        print('✅ Soundscape exported successfully!');
        print('📁 File path: $outputPath');
        print('📊 File size: $fileSizeMB MB');
        print('⏱️ Duration: ${widget.session.durationMinutes} minutes');
        
        if (mounted) {
          final isDesktop = !kIsWeb &&
              (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

          if (isDesktop) {
            final savedPath = await FilePicker.platform.saveFile(
              dialogTitle: 'Save Soundscape',
              fileName: outputFileName,
              type: FileType.custom,
              allowedExtensions: ['mp3'],
            );

            if (savedPath != null) {
              await File(outputPath).copy(savedPath);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Soundscape saved successfully!',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('Location: $savedPath'),
                        Text('Size: $fileSizeMB MB'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Soundscape exported successfully!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('File: ${outputPath.split('/').last}'),
                    Text('Size: $fileSizeMB MB'),
                    const SizedBox(height: 4),
                    const Text(
                      'Saved in app storage. Use Share to save to Files or share.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
              ),
            );
            unawaited(Future(() async {
              try {
                await Share.shareXFiles(
                  [XFile(outputPath)],
                  text: 'Soundscape: ${widget.session.name}',
                  subject: 'Soundscape export',
                );
              } catch (shareError) {
                print('Share sheet error (optional): $shareError');
              }
            }));
          }
        }
      } else {
        throw Exception('Failed to export soundscape');
      }
    } catch (e) {
      print('❌ Error exporting soundscape: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting soundscape: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  // Check if any audio is currently loading
  bool get _isAnyAudioLoading {
    return _isLoading || _isLoadingBackground || _isLoadingAmbience || _isLoadingNarration || _isGeneratingNarration;
  }
  
  /// Generate a hash from narration text for filename
  String _getNarrationHash(String narrationText) {
    final bytes = utf8.encode(narrationText);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16); // Use first 16 chars for shorter filename
  }
  
  /// Get the path for narration audio file based on session ID and narration text hash
  /// Uses MP3 format (ElevenLabs default output format)
  Future<String> _getNarrationFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${directory.path}/generated_audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    
    final narrationHash = _getNarrationHash(widget.session.narrationText);
    final voiceSuffix = widget.session.narrationVoiceId != null
        ? '_${widget.session.narrationVoiceId}'
        : '';
    final fileName = 'narration_${widget.session.id}_$narrationHash$voiceSuffix.mp3';
    return '${audioDir.path}/$fileName';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E4D7),
      appBar: AppBar(
        title: Text(
          widget.session.name,
          style: const TextStyle(color: Color(0xFF2F2F2F), fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFEDEAE6),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2F2F2F)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Soundscape Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7BC4B8), Color(0xFFB8A4D4)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7BC4B8).withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.psychology,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.session.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.session.activity,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Duration and Created info
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer,
                              color: Colors.white.withOpacity(0.8),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            ValueListenableBuilder<int>(
                              valueListenable: _sessionRemainingNotifier,
                              builder: (context, secondsLeft, _) {
                                final durationLabel = _isSessionStarted
                                    ? _formatSessionCountdown(secondsLeft)
                                    : widget.session.formattedDuration;
                                return Text(
                                  durationLabel,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 13,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.white.withOpacity(0.8),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _formatDate(widget.session.createdAt),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Soundscape Control Buttons
            _buildSessionControls(),
            
            const SizedBox(height: 24),
            
            // Audio Player Section
            _buildAudioPlayerSection(),
            
            // Background Music Section (only if not "None")
            if (widget.session.backgroundMusic != 'None') ...[
              const SizedBox(height: 24),
              _buildBackgroundMusicSection(),
            ],
            
            // Nature Ambience Section
            const SizedBox(height: 24),
            _buildNatureAmbienceSection(),
            
            // Narration Section
            const SizedBox(height: 24),
            _buildNarrationSection(),
            
            // HealthKit Observer Section
            const SizedBox(height: 24),
            _buildHealthKitObserverSection(),
            
            // AI Analysis Section
            if (_isSessionStarted && (_aiAnalysis != null || _isAnalyzing || _aiAnalysisError != null)) ...[
              const SizedBox(height: 24),
              _buildAIAnalysisSection(),
            ],
          ],
        ),
      ),
      // Loading overlay
      if (_isAnyAudioLoading)
            Container(
              color: const Color(0xFFF3E4D7).withOpacity(0.92),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFF7BC4B8),
                      strokeWidth: 4,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isGeneratingNarration 
                          ? 'Generating narration audio with AI...'
                          : 'Loading audio files...',
                      style: const TextStyle(
                        color: Color(0xFF2F2F2F),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildAudioPlayerSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEAE6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9D0C8)),
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
          Row(
            children: [
              const Icon(
                Icons.headphones,
                color: Color(0xFF7BC4B8),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Binaural Audio',
                style: TextStyle(
                  color: const Color(0xFF2F2F2F),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Audio file type indicator (preset sessions only; custom clips have a single loop)
              if (_hasAudioSwitched && !widget.session.hasCustomBinauralClip)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7BAF8E).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF7BAF8E).withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.swap_horiz,
                        color: Color(0xFF7BAF8E),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _currentBinauralFile.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF7BAF8E),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          if (widget.session.hasCustomBinauralClip) ...[
            const SizedBox(height: 8),
            Text(
              'Carrier ${widget.session.binauralBaseFrequencyHz!.round()} Hz · '
              'Beat ${widget.session.binauralBeatFrequencyHz} Hz · looped',
              style: const TextStyle(
                color: Color(0xFF7A7570),
                fontSize: 13,
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Color(0xFF7BC4B8)),
              ),
            )
          else if (_audioPlayer == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Audio not loaded',
                  style: TextStyle(color: Color(0xFFA09890)),
                ),
              ),
            )
          else ...[
            // Play/Pause Button
            Center(
              child: IconButton(
                iconSize: 64,
                icon: Icon(
                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: Color(0xFF7BC4B8),
                ),
                onPressed: _togglePlayPause,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Volume control
            Row(
              children: [
                const Icon(Icons.volume_up, color: const Color(0xFF7A7570), size: 18),
                const SizedBox(width: 8),
                const Text('Volume:', style: TextStyle(color: const Color(0xFF7A7570), fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _volume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 50,
                    activeColor: const Color(0xFF7BC4B8),
                    onChanged: (value) {
                      setState(() {
                        _volume = value;
                      });
                      _audioPlayer?.setVolume(value);
                    },
                  ),
                ),
                SizedBox(
                  width: 45,
                  child: Text(
                    '${(_volume * 100).round()}%',
                    style: const TextStyle(color: const Color(0xFF7A7570), fontSize: 12),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Speed control
            Row(
              children: [
                const Icon(Icons.speed, color: const Color(0xFF7A7570), size: 18),
                const SizedBox(width: 8),
                const Text('Speed:', style: TextStyle(color: const Color(0xFF7A7570), fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _speed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    activeColor: const Color(0xFF7BC4B8),
                    onChanged: (value) {
                      setState(() {
                        _speed = value;
                      });
                      _audioPlayer?.setSpeed(value);
                    },
                  ),
                ),
                SizedBox(
                  width: 45,
                  child: Text(
                    '${_speed.toStringAsFixed(1)}x',
                    style: const TextStyle(color: const Color(0xFF7A7570), fontSize: 12),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildBackgroundMusicSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEAE6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9D0C8)),
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
          Row(
            children: [
              const Icon(
                Icons.music_note,
                color: Color(0xFF85C4A8),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Background Music',
                      style: TextStyle(
                        color: const Color(0xFF2F2F2F),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (UserMusicLibraryService.isUserTrackKey(
                          widget.session.backgroundMusic,
                        )) ...[
                          const Icon(
                            Icons.upload_file_outlined,
                            size: 13,
                            color: Color(0xFF7A7570),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            _backgroundMusicDisplayName,
                            style: const TextStyle(
                              color: Color(0xFF7A7570),
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          if (_isLoadingBackground)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Color(0xFF85C4A8)),
              ),
            )
          else if (_backgroundMusicPlayer == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Background music not available',
                  style: TextStyle(color: Color(0xFFA09890)),
                ),
              ),
            )
          else ...[
            // Play/Pause Button
            Center(
              child: IconButton(
                iconSize: 64,
                icon: Icon(
                  _isPlayingBackground ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: Color(0xFF85C4A8),
                ),
                onPressed: _toggleBackgroundPlayPause,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Volume control
            Row(
              children: [
                const Icon(Icons.volume_up, color: const Color(0xFF7A7570), size: 18),
                const SizedBox(width: 8),
                const Text('Volume:', style: TextStyle(color: const Color(0xFF7A7570), fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _backgroundVolume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 50,
                    activeColor: const Color(0xFF85C4A8),
                    onChanged: (value) {
                      setState(() {
                        _backgroundVolume = value;
                      });
                      _backgroundMusicPlayer?.setVolume(value);
                    },
                  ),
                ),
                SizedBox(
                  width: 45,
                  child: Text(
                    '${(_backgroundVolume * 100).round()}%',
                    style: const TextStyle(color: const Color(0xFF7A7570), fontSize: 12),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Speed control
            Row(
              children: [
                const Icon(Icons.speed, color: const Color(0xFF7A7570), size: 18),
                const SizedBox(width: 8),
                const Text('Speed:', style: TextStyle(color: const Color(0xFF7A7570), fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _backgroundSpeed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    activeColor: const Color(0xFF85C4A8),
                    onChanged: (value) {
                      setState(() {
                        _backgroundSpeed = value;
                      });
                      _backgroundMusicPlayer?.setSpeed(value);
                    },
                  ),
                ),
                SizedBox(
                  width: 45,
                  child: Text(
                    '${_backgroundSpeed.toStringAsFixed(1)}x',
                    style: const TextStyle(color: const Color(0xFF7A7570), fontSize: 12),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildNatureAmbienceSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEAE6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9D0C8)),
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
          Row(
            children: [
              const Icon(
                Icons.park,
                color: Color(0xFF7BC4B8),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ambience',
                      style: TextStyle(
                        color: const Color(0xFF2F2F2F),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.session.backgroundAmbience,
                      style: TextStyle(
                        color: const Color(0xFF7A7570),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          if (_isLoadingAmbience)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Color(0xFF7BC4B8)),
              ),
            )
          else if (_natureAmbiencePlayer == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Ambience not available',
                  style: TextStyle(color: Color(0xFFA09890)),
                ),
              ),
            )
          else ...[
            // Play/Pause Button
            Center(
              child: IconButton(
                iconSize: 64,
                icon: Icon(
                  _isPlayingAmbience ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: Color(0xFF7BC4B8),
                ),
                onPressed: _toggleAmbiencePlayPause,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Volume control
            Row(
              children: [
                const Icon(Icons.volume_up, color: const Color(0xFF7A7570), size: 18),
                const SizedBox(width: 8),
                const Text('Volume:', style: TextStyle(color: const Color(0xFF7A7570), fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _ambienceVolume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 50,
                    activeColor: const Color(0xFF7BC4B8),
                    onChanged: (value) {
                      setState(() {
                        _ambienceVolume = value;
                      });
                      _natureAmbiencePlayer?.setVolume(value);
                    },
                  ),
                ),
                SizedBox(
                  width: 45,
                  child: Text(
                    '${(_ambienceVolume * 100).round()}%',
                    style: const TextStyle(color: const Color(0xFF7A7570), fontSize: 12),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Speed control
            Row(
              children: [
                const Icon(Icons.speed, color: const Color(0xFF7A7570), size: 18),
                const SizedBox(width: 8),
                const Text('Speed:', style: TextStyle(color: const Color(0xFF7A7570), fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _ambienceSpeed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    activeColor: const Color(0xFF7BC4B8),
                    onChanged: (value) {
                      setState(() {
                        _ambienceSpeed = value;
                      });
                      _natureAmbiencePlayer?.setSpeed(value);
                    },
                  ),
                ),
                SizedBox(
                  width: 45,
                  child: Text(
                    '${_ambienceSpeed.toStringAsFixed(1)}x',
                    style: const TextStyle(color: const Color(0xFF7A7570), fontSize: 12),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildNarrationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEAE6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9D0C8)),
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
          Row(
            children: [
              const Icon(
                Icons.record_voice_over,
                color: Color(0xFFB8A4D4),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Narration',
                style: TextStyle(
                  color: const Color(0xFF2F2F2F),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          if (_isLoadingNarration)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Color(0xFFB8A4D4)),
              ),
            )
          else if (_narrationPlayer == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Narration not available',
                  style: TextStyle(color: Color(0xFFA09890)),
                ),
              ),
            )
          else ...[
            // Play/Pause Button
            Center(
              child: IconButton(
                iconSize: 64,
                icon: Icon(
                  _isPlayingNarration ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: Color(0xFFB8A4D4),
                ),
                onPressed: _toggleNarrationPlayPause,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Volume control
            Row(
              children: [
                const Icon(Icons.volume_up, color: const Color(0xFF7A7570), size: 18),
                const SizedBox(width: 8),
                const Text('Volume:', style: TextStyle(color: const Color(0xFF7A7570), fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _narrationVolume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 50,
                    activeColor: const Color(0xFFB8A4D4),
                    onChanged: (value) {
                      setState(() {
                        _narrationVolume = value;
                      });
                      _narrationPlayer?.setVolume(value);
                    },
                  ),
                ),
                SizedBox(
                  width: 45,
                  child: Text(
                    '${(_narrationVolume * 100).round()}%',
                    style: const TextStyle(color: const Color(0xFF7A7570), fontSize: 12),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Speed control
            Row(
              children: [
                const Icon(Icons.speed, color: const Color(0xFF7A7570), size: 18),
                const SizedBox(width: 8),
                const Text('Speed:', style: TextStyle(color: const Color(0xFF7A7570), fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _narrationSpeed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    activeColor: const Color(0xFFB8A4D4),
                    onChanged: (value) {
                      setState(() {
                        _narrationSpeed = value;
                      });
                      _narrationPlayer?.setSpeed(value);
                    },
                  ),
                ),
                SizedBox(
                  width: 45,
                  child: Text(
                    '${_narrationSpeed.toStringAsFixed(1)}x',
                    style: const TextStyle(color: const Color(0xFF7A7570), fontSize: 12),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildSessionControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEAE6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9D0C8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isSessionStarted) ...[
            // Start Session Button
            ElevatedButton.icon(
              onPressed: () {
                // Check if at least one audio is loaded
                if (_audioPlayer == null && 
                    _backgroundMusicPlayer == null && 
                    _natureAmbiencePlayer == null && 
                    _narrationPlayer == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No audio files loaded. Please wait for audio to load.'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                
                // If narration text exists, ensure narration is loaded
                if (widget.session.narrationText.trim().isNotEmpty && _narrationPlayer == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Narration audio is still being generated. Please wait...'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                
                // Don't allow starting if any audio is still loading
                if (_isAnyAudioLoading) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isGeneratingNarration 
                          ? 'Generating narration audio. Please wait...'
                          : 'Audio files are still loading. Please wait...'),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                
                _startSession();
              },
              icon: const Icon(Icons.play_arrow, size: 28),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Start Soundscape',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7BAF8E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
            ),
            const SizedBox(height: 12),
            // Export Button
            ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportSoundscape,
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: const Color(0xFF2F2F2F),
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download, size: 24),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  _isExporting ? 'Exporting...' : 'Export Soundscape',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isExporting ? const Color(0xFFBDB5AF) : const Color(0xFF7BC4B8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Text(
                    'Time left',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF5C574F).withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ValueListenableBuilder<int>(
                    valueListenable: _sessionRemainingNotifier,
                    builder: (context, secondsLeft, _) {
                      return Text(
                        _formatSessionCountdown(secondsLeft),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF2F2F2F),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Pause and Stop Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pauseAllAudio,
                    icon: const Icon(Icons.pause, size: 24),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        'Pause All',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4A76A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _stopAllAudio,
                    icon: const Icon(Icons.stop, size: 24),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        'Stop All',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4867A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Resume button (if all are paused)
            if (!_isPlaying &&
                !_isPlayingBackground &&
                !_isPlayingAmbience &&
                !_isPlayingNarration)
              ElevatedButton.icon(
                onPressed: _startSession,
                icon: const Icon(Icons.play_arrow, size: 24),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Resume Soundscape',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7BAF8E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
              ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildHealthKitObserverSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEAE6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9D0C8)),
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
          Row(
            children: [
              const Icon(
                Icons.favorite,
                color: Color(0xFFD4867A),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Heart Rate Monitor',
                style: TextStyle(
                  color: Color(0xFF2F2F2F),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB8A4D4), Color(0xFF7BC4B8)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: Colors.white, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'PREMIUM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E4D7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFB8A4D4).withOpacity(0.35),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4867A).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFD4867A),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Real-Time Heart Rate Insights',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF2F2F2F),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Unlock live heart rate monitoring during your sessions. '
                  'Renovatio reads your Apple Watch data in real time and adapts '
                  'your soundscape automatically — helping you reach deeper states '
                  'of calm, focus, or recovery.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF7A7570),
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(color: Color(0xFFD9D0C8)),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PremiumFeatureChip(label: 'Live BPM'),
                    SizedBox(width: 8),
                    _PremiumFeatureChip(label: 'Heart Zone Tracking'),
                    SizedBox(width: 8),
                    _PremiumFeatureChip(label: 'AI Adaptation'),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'This feature is available to premium members. '
                  'We\'d love to have you on board — reach out to us and '
                  'we\'ll take care of the rest.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF7A7570),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: const Text('Contact Us to Upgrade'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB8A4D4),
                    side: const BorderSide(color: Color(0xFFB8A4D4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // ignore: unused_element
  Widget _buildHeartRateItem(HeartRateData data) {
    final zone = data.heartRateZone;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E4D7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: zone.color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: zone.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${data.value.toStringAsFixed(0)} BPM',
                      style: const TextStyle(
                        color: const Color(0xFF2F2F2F),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: zone.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        zone.name,
                        style: TextStyle(
                          color: zone.color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.formattedDate} at ${data.formattedTime}',
                  style: const TextStyle(
                    color: const Color(0xFF7A7570),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAIAnalysisSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEAE6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9D0C8)),
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
          Row(
            children: [
              const Icon(
                Icons.psychology,
                color: Color(0xFFB8A4D4),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'AI Heart Rate Analysis',
                style: TextStyle(
                  color: const Color(0xFF2F2F2F),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (_isAnalyzing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFFB8A4D4)),
                    SizedBox(height: 12),
                    Text(
                      'Analyzing heart rate data...',
                      style: TextStyle(color: Color(0xFFA09890)),
                    ),
                  ],
                ),
              ),
            )
          else if (_aiAnalysisError != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Analysis Error',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _aiAnalysisError!,
                    style: const TextStyle(color: const Color(0xFF7A7570), fontSize: 12),
                  ),
                ],
              ),
            )
          else if (_aiAnalysis != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFB8A4D4).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB8A4D4).withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.insights, color: Color(0xFFB8A4D4), size: 20),
                      const SizedBox(width: 8),
                      if (_sessionStartTime != null)
                        Text(
                          'Analysis (${_formatElapsedTime(DateTime.now().difference(_sessionStartTime!))})',
                          style: const TextStyle(
                            color: const Color(0xFFB8A4D4),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _aiAnalysis!,
                    style: const TextStyle(
                      color: const Color(0xFF2F2F2F),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  String _formatElapsedTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  /// MM:SS for the session master clock (matches [Session.durationMinutes] cap).
  String _formatSessionCountdown(int totalSeconds) {
    final s = totalSeconds.clamp(0, 86400 * 2);
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
  
  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _PremiumFeatureChip extends StatelessWidget {
  final String label;
  const _PremiumFeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFB8A4D4).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB8A4D4).withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFB8A4D4),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

