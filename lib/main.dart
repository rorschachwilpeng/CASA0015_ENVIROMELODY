import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/create_screen.dart';
import 'screens/library_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'services/music_library_manager.dart';
import 'services/audio_player_manager.dart';
import 'widgets/mini_player.dart';
import 'widgets/music_visualizer_player.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'theme/pixel_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Use the generated configuration to initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialization successful!');
  } catch (e) {
    print('Firebase initialization failed: $e');
    // Try to initialize without options
    try {
      await Firebase.initializeApp();
      print('Firebase default initialization successful!');
    } catch (e) {
      print('Firebase default initialization also failed: $e');
    }
  }
  
  // 测试Storage连接
  final firebaseService = FirebaseService();
  await firebaseService.initialize();
  await firebaseService.testStorageConnection();
  
  // Initialization of services
  await MusicLibraryManager().initialize();
  
  // Ensure AudioPlayerManager is created
  AudioPlayerManager();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Use the public method to release resources
    AudioPlayerManager().disposePlayer();
    
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // When the app goes to the background, pause the music
      AudioPlayerManager().pauseMusic();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EnviroMelody',
      theme: ThemeData(
        fontFamily: 'DMMono',
        primaryColor: PixelTheme.primary,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: SplashScreen(nextScreen: const MainScreen()),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  static const List<Widget> _pages = [
    HomeScreen(),
    CreateScreen(),
    LibraryScreen(),
    ProfileScreen(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MusicVisualizerPlayer(),
          
          Container(
            decoration: BoxDecoration(
              color: PixelTheme.surface,
              border: Border(
                top: BorderSide(color: PixelTheme.text, width: 2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPixelNavItem(
                    icon: Icons.home,
                    label: 'Home',
                    isSelected: _currentIndex == 0,
                    onTap: () => setState(() { _currentIndex = 0; }),
                  ),
                  _buildPixelNavItem(
                    icon: Icons.add,
                    label: 'Create',
                    isSelected: _currentIndex == 1,
                    onTap: () => setState(() { _currentIndex = 1; }),
                  ),
                  _buildPixelNavItem(
                    icon: Icons.library_music,
                    label: 'Library',
                    isSelected: _currentIndex == 2,
                    onTap: () => setState(() { _currentIndex = 2; }),
                  ),
                  _buildPixelNavItem(
                    icon: Icons.person,
                    label: 'Settings',
                    isSelected: _currentIndex == 3,
                    onTap: () => setState(() { _currentIndex = 3; }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPixelNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? PixelTheme.primary : PixelTheme.text,
                width: isSelected ? 2 : 1,
              ),
              color: isSelected ? PixelTheme.primary.withOpacity(0.2) : PixelTheme.surface,
              boxShadow: isSelected ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  offset: const Offset(2, 2),
                  blurRadius: 0,
                ),
              ] : null,
            ),
            child: Center(
              child: Icon(
                icon,
                color: isSelected ? PixelTheme.primary : PixelTheme.textLight,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'DMMono',
              color: isSelected ? PixelTheme.primary : PixelTheme.textLight,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
