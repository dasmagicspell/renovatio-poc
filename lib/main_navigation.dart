import 'package:flutter/material.dart';
import 'audio_player_page.dart';
import 'health_data_page.dart';
import 'sessions_page.dart';
import 'audio_generation_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  
  final List<Widget> _pages = [
    const SessionsPage(),
    const AudioPlayerPage(),
    const AudioGenerationPage(),
    const HealthDataPage(),
  ];
  
  final List<String> _pageTitles = [
    'Wellness Soundscapes',
    'Audio Player',
    'Audio Generation',
    'Health Data',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        title: Text(
          _pageTitles[_selectedIndex],
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2d2d2d),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: _buildDrawer(),
      body: _pages[_selectedIndex],
    );
  }
  
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF2d2d2d),
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1a1a1a),
                  Color(0xFF2d2d2d),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    const Icon(
                      Icons.health_and_safety,
                      color: Colors.blue,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Renovatio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Health & Wellness App',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(0, 'Soundscapes', Icons.psychology),
                _buildDrawerItem(1, 'Audio Player', Icons.music_note),
                _buildDrawerItem(2, 'Audio Generation', Icons.graphic_eq),
                _buildDrawerItem(3, 'Health Data', Icons.favorite),
                
                const Divider(
                  color: Colors.grey,
                  height: 32,
                  indent: 16,
                  endIndent: 16,
                ),
                
                // Additional menu items (placeholder for future features)
                _buildDrawerItem(-1, 'Settings', Icons.settings, isDisabled: true),
                _buildDrawerItem(-1, 'Profile', Icons.person, isDisabled: true),
                _buildDrawerItem(-1, 'Help & Support', Icons.help, isDisabled: true),
              ],
            ),
          ),
          
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Divider(color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: Colors.white54,
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
  
  Widget _buildDrawerItem(int index, String title, IconData icon, {bool isDisabled = false}) {
    final bool isSelected = _selectedIndex == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDisabled ? Colors.grey : (isSelected ? Colors.blue : Colors.white70),
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDisabled ? Colors.grey : (isSelected ? Colors.blue : Colors.white),
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: isDisabled ? null : () {
          setState(() {
            _selectedIndex = index;
          });
          Navigator.pop(context); // Close drawer
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
