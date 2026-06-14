import 'package:flutter/material.dart';

import 'constants/soundscape_options.dart';
import 'models/soundscape_defaults.dart';
import 'models/user_music_track.dart';
import 'services/config_service.dart';
import 'services/elevenlabs_service.dart';
import 'services/soundscape_defaults_service.dart';
import 'services/user_ambience_library_service.dart';
import 'services/user_music_library_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _primary = Color(0xFF2F6F65);
  static const _secondary = Color(0xFFB8A4D4);
  static const _background = Color(0xFFF3E4D7);
  static const _surface = Color(0xFFEDEAE6);
  static const _textPrimary = Color(0xFF2F2F2F);
  static const _textSecondary = Color(0xFF7A7570);
  static const _textTertiary = Color(0xFFA09890);
  static const _border = Color(0xFFD9D0C8);

  bool _isLoading = true;
  bool _isSaving = false;

  String? _selectedActivity;
  double _durationMinutes = 15.0;
  double _binauralVolume = 0.8;
  double _musicVolume = 0.1;
  double _ambienceVolume = 0.1;
  double _narrationVolume = 0.35;
  String? _selectedBackgroundMusic;
  String? _selectedBackgroundAmbience;

  List<ElevenLabsVoice> _availableVoices = [];
  ElevenLabsVoice? _selectedVoice;
  bool _isLoadingVoices = false;
  String? _voicesError;

  List<UserMusicTrack> _userMusicTracks = [];
  List<UserMusicTrack> _userAmbienceTracks = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final defaults = await SoundscapeDefaultsService.getDefaults();
    final musicTracks = await UserMusicLibraryService.getAllTracks();
    final ambienceTracks = await UserAmbienceLibraryService.getAllTracks();

    if (!mounted) return;

    setState(() {
      _selectedActivity = defaults.activity;
      _durationMinutes = defaults.durationMinutes;
      _binauralVolume = defaults.binauralVolume;
      _musicVolume = defaults.musicVolume;
      _ambienceVolume = defaults.ambienceVolume;
      _narrationVolume = defaults.narrationVolume;
      _selectedBackgroundMusic = _validMusicSelection(
        defaults.backgroundMusic,
        musicTracks,
      );
      _selectedBackgroundAmbience = _validAmbienceSelection(
        defaults.backgroundAmbience,
        ambienceTracks,
      );
      _userMusicTracks = musicTracks;
      _userAmbienceTracks = ambienceTracks;
      _isLoading = false;
    });

    await _loadVoices(defaultVoiceId: defaults.narrationVoiceId);
  }

  String? _validMusicSelection(
    String? value,
    List<UserMusicTrack> tracks,
  ) {
    if (value == null || value.isEmpty || value == 'None') return null;
    if (SoundscapeOptions.bundledMusic.contains(value)) return value;
    if (UserMusicLibraryService.isUserTrackKey(value)) {
      final id = UserMusicLibraryService.trackIdFromKey(value);
      if (tracks.any((t) => t.id == id)) return value;
    }
    return null;
  }

  String? _validAmbienceSelection(
    String? value,
    List<UserMusicTrack> tracks,
  ) {
    if (value == null || value.isEmpty || value == 'None') return null;
    if (SoundscapeOptions.bundledAmbience.contains(value)) return value;
    if (UserAmbienceLibraryService.isUserTrackKey(value)) {
      final id = UserAmbienceLibraryService.trackIdFromKey(value);
      if (tracks.any((t) => t.id == id)) return value;
    }
    return null;
  }

  Future<void> _loadVoices({String? defaultVoiceId}) async {
    final apiKey = ConfigService.elevenLabsApiKey;
    if (apiKey == null) {
      if (mounted) {
        setState(() {
          _voicesError = 'ElevenLabs API key not configured.';
        });
      }
      return;
    }

    setState(() {
      _isLoadingVoices = true;
      _voicesError = null;
    });

    try {
      ElevenLabsService.initialize(apiKey);
      final voices = await ElevenLabsService.getVoices(includeLegacy: true);

      if (!mounted) return;
      setState(() {
        _availableVoices = voices;
        _isLoadingVoices = false;
        if (defaultVoiceId != null) {
          _selectedVoice = voices
              .where((v) => v.voiceId == defaultVoiceId)
              .cast<ElevenLabsVoice?>()
              .firstOrNull;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _voicesError = 'Failed to load voices: $e';
        _isLoadingVoices = false;
      });
    }
  }

  Future<void> _saveDefaults() async {
    setState(() => _isSaving = true);

    try {
      final defaults = SoundscapeDefaults(
        activity: _selectedActivity,
        durationMinutes: _durationMinutes,
        binauralVolume: _binauralVolume,
        musicVolume: _musicVolume,
        ambienceVolume: _ambienceVolume,
        narrationVolume: _narrationVolume,
        backgroundMusic: _selectedBackgroundMusic,
        backgroundAmbience: _selectedBackgroundAmbience,
        narrationVoiceId: _selectedVoice?.voiceId,
        narrationVoiceName: _selectedVoice?.name,
      );

      await SoundscapeDefaultsService.saveDefaults(defaults);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Soundscape defaults saved'),
          backgroundColor: _primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving defaults: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _resetToStandard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Reset defaults?',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This restores the factory soundscape defaults. Your saved soundscapes are not affected.',
          style: TextStyle(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    const standard = SoundscapeDefaults.standard;
    setState(() {
      _selectedActivity = standard.activity;
      _durationMinutes = standard.durationMinutes;
      _binauralVolume = standard.binauralVolume;
      _musicVolume = standard.musicVolume;
      _ambienceVolume = standard.ambienceVolume;
      _narrationVolume = standard.narrationVolume;
      _selectedBackgroundMusic = standard.backgroundMusic;
      _selectedBackgroundAmbience = standard.backgroundAmbience;
      _selectedVoice = null;
    });
  }

  String _formatDuration(double minutes) {
    final totalMinutes = minutes.round();
    if (totalMinutes >= 60) return '1 hour';
    return '$totalMinutes mins';
  }

  InputDecoration _fieldDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textTertiary),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _background,
        body: Center(
          child: CircularProgressIndicator(color: _primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHero(),
            const SizedBox(height: 24),
            _buildSectionTitle('Soundscape Defaults'),
            const SizedBox(height: 8),
            Text(
              'These values pre-fill the form when you create a new soundscape.',
              style: TextStyle(color: _textSecondary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            _buildDurationCard(),
            const SizedBox(height: 16),
            _buildGoalCard(),
            const SizedBox(height: 16),
            _buildVolumesCard(),
            const SizedBox(height: 16),
            _buildMusicCard(),
            const SizedBox(height: 16),
            _buildAmbienceCard(),
            const SizedBox(height: 16),
            _buildVoiceCard(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveDefaults,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Defaults',
                      style: TextStyle(
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
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isSaving ? null : _resetToStandard,
              style: OutlinedButton.styleFrom(
                foregroundColor: _textSecondary,
                side: const BorderSide(color: _border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Reset to Factory Defaults'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _secondary],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.settings,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Customize how Renovatio works for you',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildFormCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
              Icon(icon, color: _primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: _textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildDurationCard() {
    return _buildFormCard(
      icon: Icons.timer_outlined,
      title: 'Default Duration',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFieldLabel('SOUNDSCAPE LENGTH'),
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
              onChanged: (value) => setState(() => _durationMinutes = value),
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
    );
  }

  Widget _buildGoalCard() {
    return _buildFormCard(
      icon: Icons.tune,
      title: 'Default Goal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('GOAL'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedActivity,
            isExpanded: true,
            decoration: _fieldDecoration(hint: 'No default goal'),
            dropdownColor: _surface,
            style: const TextStyle(color: _textPrimary),
            icon: const Icon(Icons.arrow_drop_down, color: _textSecondary),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('No default goal'),
              ),
              ...SoundscapeOptions.activities.map((activity) {
                final band = SoundscapeOptions.bandForActivity(activity);
                return DropdownMenuItem<String>(
                  value: activity,
                  child: Text('$activity ($band)'),
                );
              }),
            ],
            onChanged: (value) => setState(() => _selectedActivity = value),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumesCard() {
    return _buildFormCard(
      icon: Icons.volume_up_outlined,
      title: 'Default Layer Volumes',
      child: Column(
        children: [
          _buildVolumeRow(
            label: 'Binaural',
            value: _binauralVolume,
            onChanged: (v) => setState(() => _binauralVolume = v),
          ),
          const SizedBox(height: 12),
          _buildVolumeRow(
            label: 'Music',
            value: _musicVolume,
            onChanged: (v) => setState(() => _musicVolume = v),
          ),
          const SizedBox(height: 12),
          _buildVolumeRow(
            label: 'Ambience',
            value: _ambienceVolume,
            onChanged: (v) => setState(() => _ambienceVolume = v),
          ),
          const SizedBox(height: 12),
          _buildVolumeRow(
            label: 'Narration',
            value: _narrationVolume,
            onChanged: (v) => setState(() => _narrationVolume = v),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeRow({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(color: _textSecondary, fontSize: 13),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _primary,
              inactiveTrackColor: _primary.withOpacity(0.15),
              thumbColor: _primary,
              overlayColor: _primary.withOpacity(0.12),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
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

  Widget _buildMusicCard() {
    return _buildFormCard(
      icon: Icons.music_note_outlined,
      title: 'Default Background Music',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('TRACK'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedBackgroundMusic,
            isExpanded: true,
            decoration: _fieldDecoration(hint: 'No default track'),
            dropdownColor: _surface,
            style: const TextStyle(color: _textPrimary),
            icon: const Icon(Icons.arrow_drop_down, color: _textSecondary),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('No default track'),
              ),
              ...SoundscapeOptions.bundledMusic
                  .where((m) => m != 'None')
                  .map((music) {
                return DropdownMenuItem<String>(
                  value: music,
                  child: Text(music),
                );
              }),
              if (_userMusicTracks.isNotEmpty) ...[
                const DropdownMenuItem<String>(
                  enabled: false,
                  value: '__music_divider__',
                  child: Divider(height: 1),
                ),
                ..._userMusicTracks.map((track) {
                  return DropdownMenuItem<String>(
                    value: track.sessionKey,
                    child: Text(
                      track.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
            ],
            onChanged: (value) {
              if (value == '__music_divider__') return;
              setState(() => _selectedBackgroundMusic = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAmbienceCard() {
    return _buildFormCard(
      icon: Icons.nature_people_outlined,
      title: 'Default Background Ambience',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('BACKGROUND SOUND'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedBackgroundAmbience,
            isExpanded: true,
            decoration: _fieldDecoration(hint: 'No default ambience'),
            dropdownColor: _surface,
            style: const TextStyle(color: _textPrimary),
            icon: const Icon(Icons.arrow_drop_down, color: _textSecondary),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('No default ambience'),
              ),
              ...SoundscapeOptions.bundledAmbience
                  .where((a) => a != 'None')
                  .map((ambience) {
                return DropdownMenuItem<String>(
                  value: ambience,
                  child: Text(ambience),
                );
              }),
              if (_userAmbienceTracks.isNotEmpty) ...[
                const DropdownMenuItem<String>(
                  enabled: false,
                  value: '__ambience_divider__',
                  child: Divider(height: 1),
                ),
                ..._userAmbienceTracks.map((track) {
                  return DropdownMenuItem<String>(
                    value: UserAmbienceLibraryService.sessionKey(track.id),
                    child: Text(
                      track.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
            ],
            onChanged: (value) {
              if (value == '__ambience_divider__') return;
              setState(() => _selectedBackgroundAmbience = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceCard() {
    return _buildFormCard(
      icon: Icons.record_voice_over_outlined,
      title: 'Default Narration Voice',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('VOICE'),
          const SizedBox(height: 8),
          _buildVoiceDropdown(),
        ],
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
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
            ),
            SizedBox(width: 10),
            Text(
              'Loading voices...',
              style: TextStyle(color: _textSecondary, fontSize: 14),
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
              onPressed: () => _loadVoices(
                defaultVoiceId: _selectedVoice?.voiceId,
              ),
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
      decoration: _fieldDecoration(hint: 'No default voice'),
      dropdownColor: _surface,
      style: const TextStyle(color: _textPrimary),
      icon: const Icon(Icons.arrow_drop_down, color: _textSecondary),
      isExpanded: true,
      items: [
        const DropdownMenuItem<ElevenLabsVoice>(
          value: null,
          child: Text('No default voice'),
        ),
        ..._availableVoices.map((voice) {
          return DropdownMenuItem<ElevenLabsVoice>(
            value: voice,
            child: Text(
              voice.name,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: (voice) => setState(() => _selectedVoice = voice),
    );
  }
}
