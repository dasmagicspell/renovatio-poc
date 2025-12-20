import 'package:flutter/material.dart';
import 'models/binaural_preset.dart';
import 'services/binaural_preset_service.dart';
import 'services/binaural_audio_generator.dart';

class AudioGenerationPage extends StatefulWidget {
  const AudioGenerationPage({super.key});

  @override
  State<AudioGenerationPage> createState() => _AudioGenerationPageState();
}

class _AudioGenerationPageState extends State<AudioGenerationPage> {
  List<BinauralActivity> _activities = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Map<String, bool> _generatingActivities = {}; // Track which activities are being generated
  final Map<String, Map<String, String>> _generationProgress = {}; // Track progress for each activity

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final activities = await BinauralPresetService.loadActivities();
      setState(() {
        _activities = activities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _generateAudio(BinauralActivity activity) async {
    // Check if already generating
    if (_generatingActivities[activity.activity] == true) {
      return;
    }
    
    setState(() {
      _generatingActivities[activity.activity] = true;
      _generationProgress[activity.activity] = {
        'base': 'Waiting...',
        'increase': 'Waiting...',
        'decrease': 'Waiting...',
      };
    });
    
    try {
      // Show initial message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Starting audio generation for ${activity.activity}...'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Generate audio files
      final results = await BinauralAudioGenerator.generateAudioForActivity(
        activityName: activity.activity,
        presets: activity.presets,
        onProgress: (preset, status) {
          if (mounted) {
            setState(() {
              _generationProgress[activity.activity]?[preset] = status;
            });
          }
        },
      );
      
      // Check results
      final successCount = results.length;
      final totalPresets = activity.presets.length;
      
      if (mounted) {
        final directoryPath = await BinauralAudioGenerator.getBinauralAudioDirectory();
        
        if (successCount == totalPresets) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully generated ${successCount} audio files for ${activity.activity}!\n'
                'Files saved to: $directoryPath',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
          
          // Print file paths for debugging
          print('=== Generated Audio Files ===');
          results.forEach((preset, path) {
            print('$preset: $path');
          });
          print('============================');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Generated $successCount out of $totalPresets files for ${activity.activity}',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating audio: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      print('Error generating audio for ${activity.activity}: $e');
    } finally {
      if (mounted) {
        setState(() {
          _generatingActivities[activity.activity] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF2d2d2d),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.graphic_eq,
                  color: Colors.blue,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Audio Generation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.blue),
                  )
                : _errorMessage != null
                    ? _buildErrorState()
                    : _activities.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadActivities,
                            color: Colors.blue,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _activities.length,
                              itemBuilder: (context, index) {
                                final activity = _activities[index];
                                return _buildActivityCard(activity);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error Loading Activities',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadActivities,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text(
              'Retry',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
          Icon(
            Icons.graphic_eq_outlined,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No activities found',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(BinauralActivity activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.activity,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity.description,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Show progress if generating
            if (_generatingActivities[activity.activity] == true &&
                _generationProgress[activity.activity] != null) ...[
              _buildProgressSection(activity),
              const SizedBox(height: 12),
            ],
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generatingActivities[activity.activity] == true
                    ? null
                    : () => _generateAudio(activity),
                icon: _generatingActivities[activity.activity] == true
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.graphic_eq, color: Colors.white),
                label: Text(
                  _generatingActivities[activity.activity] == true
                      ? 'Generating...'
                      : 'Generate Audio',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _generatingActivities[activity.activity] == true
                      ? Colors.grey
                      : Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProgressSection(BinauralActivity activity) {
    final progress = _generationProgress[activity.activity];
    if (progress == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generation Progress:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...progress.entries.map((entry) {
            final preset = entry.key;
            final status = entry.value;
            final isCompleted = status == 'Completed';
            final isFailed = status.startsWith('Error') || status == 'Failed';
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle
                        : isFailed
                            ? Icons.error
                            : Icons.hourglass_empty,
                    size: 16,
                    color: isCompleted
                        ? Colors.green
                        : isFailed
                            ? Colors.red
                            : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${preset.toUpperCase()}: $status',
                      style: TextStyle(
                        color: isCompleted
                            ? Colors.green
                            : isFailed
                                ? Colors.red
                                : Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

