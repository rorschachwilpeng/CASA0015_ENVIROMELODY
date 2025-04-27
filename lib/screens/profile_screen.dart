import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'dart:async';
import '../models/music_item.dart';
import '../services/firebase_service.dart';
import '../services/music_library_manager.dart';
import '../theme/pixel_theme.dart';
import 'splash_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mock user data
    const String username = "Music Lover";
    const String email = "music_lover@ucl.ac.uk";
    const int createdMusicCount = 15;
    const int favoriteMusicCount = 8;
    
    return Scaffold(
      backgroundColor: PixelTheme.background,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: PixelTheme.titleStyle.copyWith(
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: PixelTheme.surface,
        foregroundColor: PixelTheme.text,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile avatar with pixel style
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: PixelTheme.surface,
                border: PixelTheme.pixelBorder,
                boxShadow: PixelTheme.cardShadow,
              ),
              child: Icon(
                Icons.person,
                size: 80,
                color: PixelTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            
            // Username with pixel style
            Text(
              username,
              style: PixelTheme.titleStyle.copyWith(
                fontSize: 24,
                color: PixelTheme.text,
              ),
            ),
            
            // Email with pixel style
            Text(
              email,
              style: PixelTheme.bodyStyle.copyWith(
                color: PixelTheme.textLight,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Profile sections
            _buildProfileSection(
              icon: Icons.music_note,
              title: 'My Created Music',
              value: '$createdMusicCount',
              onTap: () {
                // TODO: Navigate to user created music list
              },
            ),
            
            _buildProfileSection(
              icon: Icons.favorite,
              title: 'My Favorite Music',
              value: '$favoriteMusicCount',
              onTap: () {
                // TODO: Navigate to user favorite music list
              },
            ),
            
            _buildProfileSection(
              icon: Icons.settings,
              title: 'Settings',
              onTap: () {
                // TODO: Navigate to settings page
              },
            ),
            
            _buildProfileSection(
              icon: Icons.cloud_upload,
              title: 'Test saving music to Firebase',
              onTap: () {
                testAddMusicToFirestore();
              },
            ),
            
            _buildSyncSection(context),
            
            _buildTestSplashSection(context),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  // Helper method to build profile sections with pixel style
  Widget _buildProfileSection({
    required IconData icon,
    required String title,
    String? value,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: PixelTheme.surface,
        border: Border.all(color: PixelTheme.text.withOpacity(0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                // Section icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    border: Border.all(color: PixelTheme.text.withOpacity(0.5), width: 1),
                    color: PixelTheme.surface,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: PixelTheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Section title
                Expanded(
                  child: Text(
                    title,
                    style: PixelTheme.bodyStyle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                // Section value (if provided)
                if (value != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: PixelTheme.text.withOpacity(0.3), width: 1),
                      color: PixelTheme.primary.withOpacity(0.1),
                    ),
                    child: Text(
                      value,
                      style: PixelTheme.bodyStyle.copyWith(
                        color: PixelTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                
                // Arrow icon
                if (value == null)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: PixelTheme.textLight,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Special section for sync functionality with progress indicator
  Widget _buildSyncSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: PixelTheme.surface,
        border: Border.all(color: PixelTheme.text.withOpacity(0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // Show the prompt for starting the sync
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Starting sync...',
                  style: PixelTheme.bodyStyle.copyWith(color: Colors.white),
                ),
                duration: Duration(seconds: 1),
                backgroundColor: PixelTheme.primary,
              )
            );
            
            // Call the sync method
            await MusicLibraryManager().forceSyncWithFirebase();
            
            // Show the prompt for completing the sync
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Sync completed! Last sync time: ${_formatTime(MusicLibraryManager().lastSyncTime)}',
                  style: PixelTheme.bodyStyle.copyWith(color: Colors.white),
                ),
                backgroundColor: PixelTheme.accent,
              )
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                // Section icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    border: Border.all(color: PixelTheme.text.withOpacity(0.5), width: 1),
                    color: PixelTheme.surface,
                  ),
                  child: Icon(
                    Icons.sync,
                    size: 20,
                    color: PixelTheme.accent,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Section content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sync music library',
                        style: PixelTheme.bodyStyle.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manually sync local music to the cloud',
                        style: PixelTheme.labelStyle,
                      ),
                    ],
                  ),
                ),
                
                // Sync indicator
                MusicLibraryManager().isSyncing
                  ? Container(
                      width: 24,
                      height: 24,
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(color: PixelTheme.accent, width: 1),
                      ),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PixelTheme.accent,
                      ),
                    )
                  : Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: PixelTheme.textLight,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Test Firebase connection method
  void _testFirebaseConnection(BuildContext context) async {
    // Show the loading dialog
    BuildContext? dialogContext;
    
    // Set timeout
    Timer? timeoutTimer;
    
    // Function to show the loading dialog
    void showLoadingDialog() {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) {
          dialogContext = ctx;
          return WillPopScope(
            onWillPop: () async => false,
            child: Center(
              child: Container(
                width: 80,
                height: 80,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PixelTheme.surface,
                  border: PixelTheme.pixelBorder,
                  boxShadow: PixelTheme.cardShadow,
                ),
                child: CircularProgressIndicator(
                  color: PixelTheme.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        },
      );
    }
    
    // Function to safely close the dialog
    void closeLoadingDialog() {
      if (dialogContext != null) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        dialogContext = null;
      }
    }
    
    // Show the loading dialog
    showLoadingDialog();
    
    // Set timeout
    timeoutTimer = Timer(const Duration(seconds: 15), () {
      print('Firebase connection test timeout');
      timeoutTimer = null;
      closeLoadingDialog();
      
      if (context.mounted) {
        _showResultDialog(
          context,
          'Connection timeout',
          'Firebase operation timeout, please check the network connection and try again.',
          false
        );
      }
    });
    
    try {
      // Check if Firebase is initialized
      print('Starting to test Firebase connection...');
      final apps = Firebase.apps;
      print('Firebase app count: ${apps.length}');
      if (apps.isEmpty) {
        print('No Firebase apps are initialized');
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          print('Successfully initialized Firebase in the Profile page');
        } catch (e) {
          print('Failed to initialize Firebase in the Profile page: $e');
          throw Exception('Firebase not initialized: $e');
        }
      } else {
        for (var app in apps) {
          print('Firebase app name: ${app.name}, options: ${app.options.projectId}');
        }
      }
      
      // Get Firestore instance
      final firestore = FirebaseFirestore.instance;
      print('Got the Firestore instance');
      
      try {
        // Create a test document
        print('Attempting to write a test document...');
        await firestore.collection('test').doc('connection-test').set({
          'timestamp': DateTime.now().toIso8601String(),
          'message': 'Connection test successful',
          'device': '${MediaQuery.of(context).size.width.toInt()}x${MediaQuery.of(context).size.height.toInt()}'
        }, SetOptions(merge: true));
        print('Test document written successfully');
        
        // Read the test document
        print('Attempting to read the test document...');
        final doc = await firestore.collection('test').doc('connection-test').get();
        print('Test document read successfully: ${doc.exists}');
        
        // Cancel the timeout timer
        timeoutTimer?.cancel();
        timeoutTimer = null;
        
        // Close the loading dialog
        closeLoadingDialog();
        
        if (doc.exists) {
          // Show the success message
          if (context.mounted) {
            _showResultDialog(
              context, 
              'Connection successful', 
              'Firebase connection is normal!\n\nData: ${doc.data()}',
              true
            );
          }
          print('Firebase connection test successful: ${doc.data()}');
        } else {
          if (context.mounted) {
            _showResultDialog(
              context, 
              'Connection exception', 
              'Document exists but data is empty',
              false
            );
          }
        }
      } catch (firestoreError) {
        print('Firestore operation failed: $firestoreError');
        
        // Cancel the timeout timer
        timeoutTimer?.cancel();
        timeoutTimer = null;
        
        // Close the loading dialog
        closeLoadingDialog();
        
        if (context.mounted) {
          _showResultDialog(
            context, 
            'Firestore error', 
            'Failed to write or read test data, please check the Firestore rules settings.\n\nError information: $firestoreError',
            false
          );
        }
      }
    } catch (e) {
      // Cancel the timeout timer
      timeoutTimer?.cancel();
      timeoutTimer = null;
      
      // Close the loading dialog
      closeLoadingDialog();
      
      // Show the error message
      if (context.mounted) {
        _showResultDialog(
          context, 
          'Connection failed', 
          'Firebase connection error: $e\n\nFirebase app count: ${Firebase.apps.length}',
          false
        );
      }
      print('Firebase connection test failed: $e');
    }
  }
  
  // Show the result dialog with pixel style
  void _showResultDialog(BuildContext context, String title, String message, bool success) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: PixelTheme.surface,
            border: PixelTheme.pixelBorder,
            boxShadow: PixelTheme.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: PixelTheme.text, width: 2)),
                  color: success ? PixelTheme.accent.withOpacity(0.1) : PixelTheme.error.withOpacity(0.1),
                ),
                child: Row(
                  children: [
                    Icon(
                      success ? Icons.check_circle : Icons.error,
                      color: success ? PixelTheme.accent : PixelTheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: PixelTheme.titleStyle,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Text(
                    message,
                    style: PixelTheme.bodyStyle,
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: PixelTheme.text, width: 1)),
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: PixelTheme.surface,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'OK',
                    style: PixelTheme.bodyStyle.copyWith(
                      color: success ? PixelTheme.accent : PixelTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add test method
  Future<void> testAddMusicToFirestore() async {
    try {
      final testMusic = MusicItem(
        id: 'test_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Test music',
        prompt: 'Test prompt',
        audioUrl: 'https://example.com/test.mp3',
        status: 'complete',
        createdAt: DateTime.now(),
        latitude: 39.9042,
        longitude: 116.4074,
        locationName: 'Test location',
        weatherData: {'temperature': 25, 'weather': 'sunny'},
      );
      
      print('Attempting to save test music to Firestore...');
      await FirebaseService().addMusic(testMusic);
      print('Test music saved successfully!');
    } catch (e) {
      print('Test music save failed: $e');
    }
  }

  // Helper method to format time
  String _formatTime(DateTime time) {
    if (time.millisecondsSinceEpoch == 0) return 'Never synced';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  Widget _buildTestSplashSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, top: 12),
      decoration: BoxDecoration(
        color: PixelTheme.surface,
        border: Border.all(color: PixelTheme.primary, width: 2),
        boxShadow: PixelTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => 
                  SplashScreen(
                    nextScreen: Navigator.of(context).canPop() 
                      ? const Material(child: Center(child: Text('Back to Profile')))
                      : const Material(child: Center(child: Text('Error'))),
                    onSplashComplete: () {
                      Future.delayed(Duration.zero, () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      });
                    },
                  ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                // Button Icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    border: Border.all(color: PixelTheme.primary, width: 1),
                    color: PixelTheme.primary.withOpacity(0.1),
                  ),
                  child: Icon(
                    Icons.play_circle_outline,
                    size: 20,
                    color: PixelTheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                
                // BUtton text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Splash Screen',
                        style: PixelTheme.bodyStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          color: PixelTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View the app startup animation again',
                        style: PixelTheme.labelStyle,
                      ),
                    ],
                  ),
                ),
                
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: PixelTheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 