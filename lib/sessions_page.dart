import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'new_session_page.dart';
import 'session_details_page.dart';
import 'models/session.dart';
import 'services/session_storage_service.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  List<Session> _sessions = [];
  bool _isLoading = true;

  static const _primary = Color(0xFF7BC4B8);
  static const _background = Color(0xFFF3E4D7);
  static const _surface = Color(0xFFEDEAE6);
  static const _textPrimary = Color(0xFF2F2F2F);
  static const _textSecondary = Color(0xFF7A7570);
  static const _textTertiary = Color(0xFFA09890);
  static const _border = Color(0xFFD9D0C8);

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sessions = await SessionStorageService.getAllSessions();
      sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading soundscapes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _navigateToNewSession() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NewSessionPage(),
      ),
    );
    // Reload whenever this route stack unwinds (including after create →
    // SessionDetails via pushReplacement, then back). Pop never sends `true`
    // from that flow, so a result check would skip refresh.
    _loadSessions();
  }

  void _navigateToSessionDetails(Session session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SessionDetailsPage(session: session),
      ),
    );
  }

  Future<bool> _confirmAndDeleteSession(Session session) async {
    final doDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Delete Soundscape',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${session.name}"? This cannot be undone.',
          style: const TextStyle(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (doDelete != true) return false;

    try {
      final appDir = await getApplicationDocumentsDirectory();

      // Delete the per-session binaural audio clip.
      if (session.binauralClipRelativePath != null) {
        final binauralFile =
            File('${appDir.path}/${session.binauralClipRelativePath}');
        if (await binauralFile.exists()) await binauralFile.delete();
      }

      // Delete TTS narration cache directories for this session.
      // Directories are named: generated_audio/narration_<sessionId>_<hash>[_<voiceId>]
      final generatedAudioDir =
          Directory('${appDir.path}/generated_audio');
      if (await generatedAudioDir.exists()) {
        await for (final entity in generatedAudioDir.list()) {
          if (entity is Directory) {
            final dirName = entity.path.split('/').last;
            if (dirName.startsWith('narration_${session.id}_')) {
              await entity.delete(recursive: true);
            }
          }
        }
      }

      // Remove the session record from storage.
      await SessionStorageService.deleteSession(session.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting soundscape: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: BoxDecoration(
              color: _surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: _primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'My Soundscapes',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _navigateToNewSession,
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: const Text(
                    'New',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          
          // Sessions List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _primary),
                  )
                : _sessions.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadSessions,
                        color: _primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _sessions.length,
                          itemBuilder: (context, index) {
                            final session = _sessions[index];
                            return _buildSessionCard(session);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology_outlined,
              size: 56,
              color: _primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No soundscapes yet',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first soundscape to get started',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _navigateToNewSession,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Create Soundscape',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(Session session) {
    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 26),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      background: const SizedBox.shrink(),
      confirmDismiss: (_) => _confirmAndDeleteSession(session),
      onDismissed: (_) {
        setState(() => _sessions.removeWhere((s) => s.id == session.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${session.name}" deleted'),
            backgroundColor: _textSecondary,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToSessionDetails(session),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: _primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.name,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        session.activity,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 13,
                            color: _textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            session.formattedDuration,
                            style: const TextStyle(
                              color: _textTertiary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.music_note_outlined,
                            size: 13,
                            color: _textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              session.backgroundMusic,
                              style: const TextStyle(
                                color: _textTertiary,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: _textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

