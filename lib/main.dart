import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'main_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: ".env");
    print('✅ Environment variables loaded successfully');
  } catch (e) {
    print('⚠️ Warning: Could not load .env file: $e');
    print('   Make sure .env file exists in the project root');
  }
  
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Renovatio',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7BC4B8),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3E4D7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFEDEAE6),
          foregroundColor: Color(0xFF2F2F2F),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF2F2F2F)),
        ),
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}
