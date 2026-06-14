import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

class _FaqCategory {
  const _FaqCategory({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<_FaqItem> items;
}

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  static const _primary = Color(0xFF2F6F65);
  static const _secondary = Color(0xFFB8A4D4);
  static const _background = Color(0xFFF3E4D7);
  static const _surface = Color(0xFFEDEAE6);
  static const _textPrimary = Color(0xFF2F2F2F);
  static const _textSecondary = Color(0xFF7A7570);
  static const _textTertiary = Color(0xFFA09890);
  static const _border = Color(0xFFD9D0C8);
  static const _supportEmail = 'support@renovatio.app';

  String _appVersion = '';

  static const _gettingStartedSteps = [
    'Tap the + button on Soundscapes to create a new session.',
    'Choose an activity that matches your goal — each maps to a brainwave band.',
    'Customize the four layers: Binaural, Music, Ambience, and Narration.',
    'Use Preview to hear your mix, then tap Save Soundscape.',
    'Open your session and press Play. Export when you want to save or share it.',
  ];

  static const _faqCategories = [
    _FaqCategory(
      title: 'Soundscapes & Goals',
      icon: Icons.psychology_outlined,
      items: [
        _FaqItem(
          question: 'What is a soundscape?',
          answer:
              'A soundscape is a personalized wellness audio session that combines '
              'binaural tones, background music, nature ambience, and guided narration '
              'into one experience tailored to your goal.',
        ),
        _FaqItem(
          question: 'How do I choose the right activity?',
          answer:
              'Pick the activity that matches how you want to feel. Sleep and Pain Relief '
              'use Delta waves; Meditate, Anxiety Relief, and Creativity use Theta; Relax, '
              'Study, and Light Focus use Alpha; Exercise and Focus use Beta; Energy Boost '
              'uses Gamma.',
        ),
        _FaqItem(
          question: 'What are brainwave bands?',
          answer:
              'Each activity is linked to a brainwave band — Delta, Theta, Alpha, Beta, '
              'or Gamma. These bands correspond to different mental states, from deep rest '
              'to alert focus. The binaural layer is tuned to support that state.',
        ),
        _FaqItem(
          question: 'How long should a session be?',
          answer:
              'Most sessions work well between 15 and 30 minutes. Shorter sessions are '
              'great for a quick reset; longer ones suit meditation, sleep prep, or deep '
              'focus. You set the duration when creating your soundscape.',
        ),
        _FaqItem(
          question: 'Can I turn off individual layers?',
          answer:
              'Yes. When creating a soundscape you can enable or disable each layer — '
              'Binaural, Music, Ambience, and Narration — independently. Disabled layers '
              'are skipped during playback.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Binaural Beats',
      icon: Icons.headphones_outlined,
      items: [
        _FaqItem(
          question: 'What are binaural beats?',
          answer:
              'Binaural beats play slightly different frequencies in each ear. Your brain '
              'perceives the difference as a gentle pulse that can encourage relaxation, '
              'focus, or other states depending on the beat frequency.',
        ),
        _FaqItem(
          question: 'Do I need headphones?',
          answer:
              'Yes — headphones are essential. Each ear must receive its own frequency '
              'for the binaural effect to work. Use them in a quiet space for the best '
              'experience.',
        ),
        _FaqItem(
          question: 'What is base frequency vs beat frequency?',
          answer:
              'Base frequency is the carrier tone you hear in each ear. Beat frequency '
              'is the small difference between the two ears — that difference creates '
              'the binaural pulse tied to your chosen goal.',
        ),
        _FaqItem(
          question: 'Why do some frequency ranges feel different?',
          answer:
              'Lower base frequencies feel deeper and more grounding. Mid-range carriers '
              'tend to produce the strongest beat perception. Higher carriers sound brighter '
              'but the binaural effect becomes subtler.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Narration & Voice',
      icon: Icons.record_voice_over_outlined,
      items: [
        _FaqItem(
          question: 'What is the guided voice layer?',
          answer:
              'The narration layer plays a calm, supportive narration script during your '
              'session — guiding your breathing, relaxation, or focus alongside the '
              'other audio layers.',
        ),
        _FaqItem(
          question: 'Can I write my own script?',
          answer:
              'Yes. Edit the narration text when creating a session, or use AI to '
              'generate a new script based on your activity and duration. A default '
              'script is provided to get you started.',
        ),
        _FaqItem(
          question: 'Why does narration take time to load?',
          answer:
              'When using AI voice narration, the app generates audio from your script '
              'using text-to-speech. This happens on first playback and may take a moment '
              'depending on script length and network speed. Generated audio is cached '
              'for future sessions.',
        ),
        _FaqItem(
          question: 'Can I upload my own narration?',
          answer:
              'Yes. You can upload your own narration audio file instead of using AI '
              'voice generation. Select it from your narration library when creating '
              'a soundscape.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Music & Ambience',
      icon: Icons.music_note_outlined,
      items: [
        _FaqItem(
          question: 'What is the difference between music and ambience?',
          answer:
              'Background music adds melodic or instrumental layers — piano, guitar, '
              'classical, or your own uploads. Ambience adds environmental sounds like '
              'rain, ocean waves, forest, or birds to create atmosphere.',
        ),
        _FaqItem(
          question: 'Can I upload my own audio?',
          answer:
              'Yes. You can upload custom tracks for music, ambience, and narration. '
              'Uploaded files are stored locally on your device and appear in your '
              'library when creating sessions.',
        ),
        _FaqItem(
          question: 'What file formats are supported?',
          answer:
              'Common audio formats including MP3, WAV, and M4A are supported for '
              'uploads and playback.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Playback & Export',
      icon: Icons.play_circle_outline,
      items: [
        _FaqItem(
          question: 'What do Play, Pause, and Stop do?',
          answer:
              'Play starts all enabled layers together. Pause freezes playback across '
              'every layer. Stop ends the session, resets playback, and clears the '
              'session timer.',
        ),
        _FaqItem(
          question: 'What is the session timer?',
          answer:
              'When you start a session, a countdown runs for the duration you set. '
              'In the final seconds, volume fades out gently so the session ends '
              'smoothly rather than stopping abruptly.',
        ),
        _FaqItem(
          question: 'What does Export do?',
          answer:
              'Export merges all active layers into a single audio file. After processing, '
              'the share sheet opens so you can save the file to your device or send it '
              'to another app.',
        ),
        _FaqItem(
          question: 'Can I adjust volume and speed during playback?',
          answer:
              'Yes. Each layer has its own volume and speed controls on the session '
              'details screen. Changes apply immediately while playing.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Profile & Data',
      icon: Icons.person_outline,
      items: [
        _FaqItem(
          question: 'What is the Profile page for?',
          answer:
              'Your profile stores your name, company, and email locally on your device. '
              'It helps personalize your experience and may be used for support '
              'communication.',
        ),
        _FaqItem(
          question: 'Where are my soundscapes saved?',
          answer:
              'All soundscapes and uploaded audio are stored locally on your device. '
              'They remain available offline unless you delete them.',
        ),
        _FaqItem(
          question: 'Is my data sent anywhere?',
          answer:
              'Soundscapes and uploads stay on your device. AI narration and script '
              'generation use external services only when you use those features, and '
              'only the text needed for generation is sent.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Troubleshooting',
      icon: Icons.build_outlined,
      items: [
        _FaqItem(
          question: 'No sound or audio won\'t play',
          answer:
              'Check your device volume and ensure headphones are connected if using '
              'binaural tones. Make sure at least one layer is enabled. Try stopping '
              'and restarting the session.',
        ),
        _FaqItem(
          question: 'Narration failed to generate',
          answer:
              'Voice generation requires a network connection. '
              'Check your internet connection and try again. If the problem persists, '
              'use an uploaded narration file instead.',
        ),
        _FaqItem(
          question: 'Upload failed',
          answer:
              'Make sure the file is a supported audio format and not corrupted. On some '
              'devices, storage permissions may be required to access files from your '
              'library.',
        ),
        _FaqItem(
          question: 'Export didn\'t work',
          answer:
              'Wait until all audio layers have finished loading before exporting. '
              'Export needs enough free storage on your device to write the merged file.',
        ),
      ],
    ),
  ];

  static const _safetyPoints = [
    'Renovatio is designed for wellness and relaxation, not medical treatment.',
    'Binaural beats work best with headphones in a quiet, comfortable setting.',
    'Consult a healthcare professional if you have epilepsy, hearing conditions, or other health concerns.',
    'Do not use this app while driving or operating machinery.',
    'Heart rate and AI analysis features are informational only — not a substitute for medical advice.',
  ];

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _appVersion = info.version);
      }
    }).catchError((Object e) {
      debugPrint('Could not load package info: $e');
    });
  }

  Future<void> _copySupportEmail() async {
    await Clipboard.setData(const ClipboardData(text: _supportEmail));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Support email copied to clipboard'),
        backgroundColor: _primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHero(),
            const SizedBox(height: 24),
            _buildSectionTitle('Getting Started'),
            const SizedBox(height: 12),
            _buildGettingStarted(),
            const SizedBox(height: 28),
            _buildSectionTitle('Frequently Asked Questions'),
            const SizedBox(height: 12),
            ..._faqCategories.map(_buildFaqCategory),
            const SizedBox(height: 28),
            _buildSectionTitle('Safety & Wellness'),
            const SizedBox(height: 12),
            _buildSafetyCard(),
            const SizedBox(height: 28),
            _buildSectionTitle('Contact & Feedback'),
            const SizedBox(height: 12),
            _buildContactCard(),
            const SizedBox(height: 28),
            _buildFooter(),
            const SizedBox(height: 8),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.help_outline,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How can we help?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Renovatio helps you create personalized wellness soundscapes. '
                  'Choose a goal, layer binaural tones with music and guided voice, '
                  'then play or export your session.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.45,
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

  Widget _buildGettingStarted() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _gettingStartedSteps.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _gettingStartedSteps[i],
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFaqCategory(_FaqCategory category) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            leading: Icon(category.icon, color: _primary, size: 22),
            title: Text(
              category.title,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            iconColor: _textSecondary,
            collapsedIconColor: _textSecondary,
            children: category.items
                .map(
                  (item) => Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 0),
                      childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                      title: Text(
                        item.question,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      iconColor: _textTertiary,
                      collapsedIconColor: _textTertiary,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.answer,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4867A).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.health_and_safety_outlined,
                  color: Color(0xFFD4867A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Please read before use',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._safetyPoints.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: _textTertiary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      point,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
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

  Widget _buildContactCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildContactRow(
            icon: Icons.email_outlined,
            title: 'Email Support',
            subtitle: _supportEmail,
            onTap: _copySupportEmail,
          ),
          const SizedBox(height: 12),
          _buildContactRow(
            icon: Icons.bug_report_outlined,
            title: 'Report a Bug',
            subtitle: 'Tap to copy our support email and describe the issue',
            onTap: _copySupportEmail,
          ),
          const SizedBox(height: 12),
          _buildContactRow(
            icon: Icons.lightbulb_outline,
            title: 'Request a Feature',
            subtitle: 'We\'d love to hear your ideas for Renovatio',
            onTap: _copySupportEmail,
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: _primary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.copy_outlined,
                color: _textTertiary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Text(
            'Renovatio',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _appVersion.isNotEmpty ? 'Version $_appVersion' : 'Version —',
            style: const TextStyle(
              color: _textTertiary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Powered by AI voice and narration services',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
