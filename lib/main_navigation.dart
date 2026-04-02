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

  static const _primary = Color(0xFF7BC4B8);
  static const _background = Color(0xFFF3E4D7);
  static const _surface = Color(0xFFEDEAE6);
  static const _textPrimary = Color(0xFF2F2F2F);
  static const _textSecondary = Color(0xFF7A7570);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text(
          _pageTitles[_selectedIndex],
          style: const TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _surface,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        surfaceTintColor: Colors.transparent,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: _textPrimary),
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
      backgroundColor: _surface,
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
                  Color(0xFF7BC4B8),
                  Color(0xFFB8A4D4),
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.health_and_safety,
                        color: Colors.white,
                        size: 36,
                      ),
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
                        color: Colors.white.withOpacity(0.8),
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
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerItem(0, 'Soundscapes', Icons.psychology),
                _buildDrawerItem(1, 'Audio Player', Icons.music_note),
                _buildDrawerItem(2, 'Audio Generation', Icons.graphic_eq),
                _buildDrawerItem(3, 'Health Data', Icons.favorite),
                
                Divider(
                  color: const Color(0xFFD9D0C8),
                  height: 32,
                  indent: 16,
                  endIndent: 16,
                ),
                
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
                Divider(color: const Color(0xFFD9D0C8)),
                const SizedBox(height: 8),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: _textSecondary,
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
        color: isSelected ? _primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDisabled
              ? const Color(0xFFBDB5AF)
              : (isSelected ? _primary : _textSecondary),
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDisabled
                ? const Color(0xFFBDB5AF)
                : (isSelected ? _primary : _textPrimary),
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: isDisabled ? null : () {
          setState(() {
            _selectedIndex = index;
          });
          Navigator.pop(context);
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
