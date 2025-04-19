import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'dart:async';
import '../models/music_item.dart';
import '../services/firebase_service.dart';
import '../services/music_library_manager.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mock user data
    const String username = "Music Lover";
    const String email = "music_lover@example.com";
    const int createdMusicCount = 15;
    const int favoriteMusicCount = 8;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.blue,
              child: Icon(
                Icons.person,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              username,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              email,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('My Created Music'),
              trailing: Text(
                '$createdMusicCount',
                style: const TextStyle(fontSize: 18),
              ),
              onTap: () {
                // TODO: Navigate to user created music list
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('My Favorite Music'),
              trailing: Text(
                '$favoriteMusicCount',
                style: const TextStyle(fontSize: 18),
              ),
              onTap: () {
                // TODO: Navigate to user favorite music list
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                // TODO: Navigate to settings page
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: const Text('Test saving music to Firebase'),
              onTap: () {
                testAddMusicToFirestore();
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.sync),
              title: Text('Sync music library'),
              subtitle: Text('Manually sync local music to the cloud'),
              trailing: MusicLibraryManager().isSyncing 
                  ? CircularProgressIndicator() 
                  : Icon(Icons.arrow_forward_ios),
              onTap: () async {
                // Show the prompt for starting the sync
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Starting sync...'), duration: Duration(seconds: 1))
                );
                
                // Call the sync method
                await MusicLibraryManager().forceSyncWithFirebase();
                
                // Show the prompt for completing the sync
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sync completed! Last sync time: ${_formatTime(MusicLibraryManager().lastSyncTime)}'))
                );
              },
            ),
            const Divider(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement logout functionality
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
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
          return const WillPopScope(
            onWillPop: null,
            child: Center(
              child: CircularProgressIndicator(),
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
  
  // Show the result dialog
  void _showResultDialog(BuildContext context, String title, String message, bool success) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        icon: Icon(
          success ? Icons.check_circle : Icons.error,
          color: success ? Colors.green : Colors.red,
          size: 48,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
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

  // Add this helper method to format time
  String _formatTime(DateTime time) {
    if (time.millisecondsSinceEpoch == 0) return 'Never synced';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
} 