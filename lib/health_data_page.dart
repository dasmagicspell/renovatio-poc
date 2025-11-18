import 'dart:async';
import 'package:flutter/material.dart';
import 'heart_rate_service.dart';

class HealthDataPage extends StatefulWidget {
  const HealthDataPage({super.key});

  @override
  State<HealthDataPage> createState() => _HealthDataPageState();
}

class _HealthDataPageState extends State<HealthDataPage> {
  List<HeartRateData> _heartRateData = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Observer status
  bool _isObserverActive = false;
  String _observerStatus = 'Not started';
  Timer? _fallbackTimer;
  int _updateCounter = 0;

  @override
  void initState() {
    super.initState();
    _initializeObserver();
    _loadHeartRateData();
  }
  
  Future<void> _initializeObserver() async {
    try {
      // Initialize the observer service
      await HeartRateService.initializeObserver();
      
      // Set up callbacks
      HeartRateService.setObserverCallbacks(
        onNewHeartRateData: _onNewHeartRateData,
        onObserverError: _onObserverError,
      );
      
      // Start the observer
      await HeartRateService.startObserver();
      
      // Start fallback timer to check for data every 30 seconds
      _startFallbackTimer();
      
      setState(() {
        _observerStatus = 'Initializing...';
      });
    } catch (e) {
      setState(() {
        _observerStatus = 'Error: $e';
      });
    }
  }

  Future<void> _loadHeartRateData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await HeartRateService.getHeartRateLastHour();
      setState(() {
        _heartRateData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  // Observer callback methods
  void _onNewHeartRateData(List<HeartRateData> newData) {
    print("📱 Flutter: Received ${newData.length} new heart rate readings from observer");
    print("📱 Flutter: Current list has ${_heartRateData.length} readings before update");
    
    for (int i = 0; i < newData.length; i++) {
      final data = newData[i];
      print("   Reading ${i + 1}: ${data.value.toInt()} BPM at ${data.formattedTime}");
    }
    
    setState(() {
      _updateCounter++;
      print("📱 Flutter: setState called #$_updateCounter");
      
      // Remove duplicates by checking if data already exists
      final existingTimes = _heartRateData.map((e) => e.dateTime.millisecondsSinceEpoch).toSet();
      final uniqueNewData = newData.where((newItem) => 
        !existingTimes.contains(newItem.dateTime.millisecondsSinceEpoch)
      ).toList();
      
      print("📱 Flutter: After deduplication, adding ${uniqueNewData.length} unique readings");
      
      if (uniqueNewData.isNotEmpty) {
        // Add new data to the beginning of the list
        _heartRateData = [...uniqueNewData, ..._heartRateData];
        
        // Sort the entire list by date/time (newest first)
        _heartRateData.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        
        // Keep only the last 50 readings to avoid memory issues
        if (_heartRateData.length > 50) {
          _heartRateData = _heartRateData.take(50).toList();
        }
        _observerStatus = 'Active - ${uniqueNewData.length} new readings (Update #$_updateCounter)';
        print("📱 Flutter: Added ${uniqueNewData.length} new readings. Total now: ${_heartRateData.length}");
      } else {
        print("📱 Flutter: No new unique readings to add");
        _observerStatus = 'Active - No new data (Update #$_updateCounter)';
      }
    });
    
    print("📱 Flutter: UI update completed. Total readings: ${_heartRateData.length}");
  }
  
  
  void _onObserverError(String error) {
    print("❌ Flutter: Observer error - $error");
    setState(() {
      _observerStatus = 'Error: $error';
    });
  }
  
  Future<void> _toggleObserver() async {
    if (_isObserverActive) {
      await HeartRateService.stopObserver();
      _stopFallbackTimer();
      setState(() {
        _isObserverActive = false;
        _observerStatus = 'Stopped';
      });
    } else {
      await HeartRateService.startObserver();
      _startFallbackTimer();
      setState(() {
        _isObserverActive = true;
        _observerStatus = 'Starting...';
      });
    }
  }
  
  Future<void> _fetchDataNow() async {
    print("🔄 Manual fetch triggered from UI");
    await HeartRateService.fetchDataNow();
  }
  
  void _testCallback() {
    print("🧪 Testing callback with fake data");
    final testData = [
      HeartRateData(
        value: 75.0,
        dateTime: DateTime.now(),
        unit: 'BPM',
      ),
      HeartRateData(
        value: 80.0,
        dateTime: DateTime.now().subtract(const Duration(minutes: 1)),
        unit: 'BPM',
      ),
    ];
    _onNewHeartRateData(testData);
  }
  
  void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isObserverActive) {
        print("🔄 Fallback timer: Checking for new data...");
        HeartRateService.fetchDataNow();
      }
    });
  }
  
  void _stopFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }
  
  @override
  void dispose() {
    _stopFallbackTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      /*appBar: AppBar(
        title: const Text(
          'Health Datass',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2d2d2d),
        elevation: 0,
      ),*/
      body: SingleChildScrollView(
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
                        Icons.favorite,
                        color: Colors.red,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Health Data Dashboard',
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
                    'Track and monitor your health metrics with comprehensive data visualization and analysis tools.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Heart Rate Section
            _buildHeartRateSection(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeartRateSection() {
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Heart Rate (Last Hour)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Observer status indicator
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isObserverActive ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _observerStatus,
                          style: TextStyle(
                            color: _isObserverActive ? Colors.green : Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${_heartRateData.length} readings)',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Control buttons row
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isObserverActive ? Icons.stop : Icons.play_arrow,
                            color: _isObserverActive ? Colors.red : Colors.green,
                          ),
                          onPressed: _toggleObserver,
                          tooltip: _isObserverActive ? 'Stop Observer' : 'Start Observer',
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: _loadHeartRateData,
                          tooltip: 'Refresh Data',
                        ),
                        IconButton(
                          icon: const Icon(Icons.sync, color: Colors.blue),
                          onPressed: _fetchDataNow,
                          tooltip: 'Fetch Data Now (Observer)',
                        ),
                        /*IconButton(
                          icon: const Icon(Icons.bug_report, color: Colors.orange),
                          onPressed: _testCallback,
                          tooltip: 'Test Callback',
                        ),*/
                      ],
                    ),
                  ],
                ),
              ),
                  ],
                ),
          const SizedBox(height: 16),
          
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Colors.red),
              ),
            )
          else if (_errorMessage != null)
            _buildErrorWidget()
          else if (_heartRateData.isEmpty)
            _buildNoDataWidget()
          else
            _buildHeartRateList(),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Error Loading Heart Rate Data',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error occurred',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadHeartRateData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue, size: 48),
          const SizedBox(height: 12),
          const Text(
            'No Heart Rate Data',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No heart rate data found for the last hour. Make sure you have heart rate data in the Health app and that permissions are granted.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateList() {
    return Column(
      children: [
        // Summary stats
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatCard('Count', '${_heartRateData.length}', Icons.analytics),
            _buildStatCard('Average', '${_calculateAverage().toStringAsFixed(0)} BPM', Icons.trending_up),
            _buildStatCard('Max', '${_calculateMax().toStringAsFixed(0)} BPM', Icons.trending_up),
          ],
        ),
        const SizedBox(height: 16),
        
        // Heart rate list
        Container(
          height: 700,
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a1a),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[700]!),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _heartRateData.length,
            itemBuilder: (context, index) {
              final data = _heartRateData[index];
              return _buildHeartRateItem(data);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.red, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateItem(HeartRateData data) {
    final zone = data.heartRateZone;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2d2d2d),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: zone.color.withOpacity(0.3)),
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
                Text(
                  '${data.value.toStringAsFixed(0)} BPM',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${data.formattedDate} at ${data.formattedTime}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
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
    );
  }

  double _calculateAverage() {
    if (_heartRateData.isEmpty) return 0;
    final sum = _heartRateData.fold(0.0, (sum, data) => sum + data.value);
    return sum / _heartRateData.length;
  }

  double _calculateMax() {
    if (_heartRateData.isEmpty) return 0;
    return _heartRateData.map((data) => data.value).reduce((a, b) => a > b ? a : b);
  }
}
