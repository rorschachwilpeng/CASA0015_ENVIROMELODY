import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/music_item.dart';
import '../utils/device_id_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'dart:typed_data';

class FirebaseService {
  // Singleton pattern
  static final FirebaseService _instance = FirebaseService._internal();
  
  factory FirebaseService() => _instance;
  
  FirebaseService._internal();
  
  // Firebase instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Device ID manager
  final DeviceIdManager _deviceIdManager = DeviceIdManager();
  
  // Device ID cache
  String? _deviceId;
  
  // Get current user ID, use anonymous ID if not logged in
  String get userId => _auth.currentUser?.uid ?? 'anonymous';
  
  // Get device ID
  Future<String> get deviceId async => _deviceId ??= await _deviceIdManager.getDeviceId();
  
  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;
  
  // Get music collection reference - modified to use device ID
  Future<CollectionReference> get musicCollection async => 
      _firestore.collection('devices').doc(await deviceId).collection('musicItems');
  
  // Add to FirebaseService class
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  // Initialize - ensure user is logged in (if not, anonymous login)
  // and load device ID
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('Firebase service starting initialization...');
      // Initialize device ID
      _deviceId = await _deviceIdManager.getDeviceId();
      print('Device ID: $_deviceId');
      
      // Still keep anonymous login for Firebase Storage permissions
      if (_auth.currentUser == null) {
        try {
          await _auth.signInAnonymously();
          print('Anonymous account created');
        } catch (e) {
          print('Anonymous login failed: $e');
        }
      }
      
      // Ensure device data exists
      await _ensureDeviceDocument();
      
      _isInitialized = true;
      print('Firebase service initialized successfully');
    } catch (e) {
      print('Firebase service initialization failed: $e');
      rethrow;
    }
  }
  
  // Ensure device document exists
  Future<void> _ensureDeviceDocument() async {
    try {
      final docRef = _firestore.collection('devices').doc(await deviceId);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        // Create device data document
        await docRef.set({
          'created_at': FieldValue.serverTimestamp(),
          'last_seen': FieldValue.serverTimestamp(),
          'device_id': await deviceId,
        });
        print('Create device document: ${await deviceId}');
      } else {
        // Update device last activity time
        await docRef.update({
          'last_seen': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Failed to ensure device document exists: $e');
    }
  }
  
  // Add music to Firestore - modified to use device ID
  Future<void> addMusic(MusicItem music) async {
    try {
      final collection = await musicCollection;
      await collection.doc(music.id).set(music.toJson());
      print('Music added to Firestore: ${music.id}');
    } catch (e) {
      print('Failed to add music to Firestore: $e');
      rethrow;
    }
  }
  
  // Get all music list - modified to use device ID
  Future<List<MusicItem>> getAllMusic() async {
    try {
      final collection = await musicCollection;
      final snapshot = await collection
          .orderBy('created_at', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return MusicItem.fromJson(data);
      }).toList();
    } catch (e) {
      print('Failed to get all music list: $e');
      return [];
    }
  }
  
  // Listen to music list changes - modified to use device ID
  Stream<List<MusicItem>> musicListStream() async* {
    try {
      final collection = await musicCollection;
      
      await for (final snapshot in collection
          .orderBy('created_at', descending: true)
          .snapshots()) {
        yield snapshot.docs.map((doc) {
          return MusicItem.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();
      }
    } catch (e) {
      print('Failed to listen to music list changes: $e');
      yield [];
    }
  }
  
  // Delete music - modified to use device ID
  Future<bool> deleteMusic(String musicId) async {
    try {
      final collection = await musicCollection;
      await collection.doc(musicId).delete();
      print('Music deleted from Firestore: $musicId');
      return true;
    } catch (e) {
      print('Failed to delete music: $e');
      return false;
    }
  }
  
  // Upload audio file to Storage - modified to include device ID
  Future<String> uploadAudioFile(File file, String fileName) async {
    try {
      print('Preparing to upload file to Firebase Storage...');
      print('File path: ${file.path}');
      print('Target file name: $fileName');
      
      // Read file data
      final Uint8List fileData = await file.readAsBytes();
      print('Read file data successfully, size: ${fileData.length} bytes');
      
      // Ensure Firebase Storage is initialized
      final FirebaseStorage storage = FirebaseStorage.instance;
      print('Firebase Storage instance obtained');
      
      // Create storage reference path - use the same way as testing
      // Do not use nested directories, use the root path or simple path directly
      final storageRef = storage.ref().child(fileName);
      print('Create storage reference: $fileName');
      
      // Upload file data instead of file object
      print('Starting to upload file data...');
      final uploadTask = storageRef.putData(
        fileData,
        SettableMetadata(contentType: 'audio/mp3') // Add metadata
      );
      
      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('Upload progress: ${progress.toStringAsFixed(2)}%');
      });
      
      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;
      print('File uploaded successfully');
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('Download URL obtained: $downloadUrl');
      
      return downloadUrl;
    } on FirebaseException catch (e) {
      print('Firebase Storage error: [${e.code}] ${e.message}');
      
      // More error handling...
      rethrow;
    }
  }
  
  // Delete audio file in Storage
  Future<void> deleteAudioFile(String audioUrl) async {
    try {
      // Extract file path from URL
      final ref = _storage.refFromURL(audioUrl);
      await ref.delete();
      print('Audio file deleted from Storage');
    } catch (e) {
      print('Failed to delete audio file: $e');
    }
  }
  
  // Batch delete music - modified to use device ID
  Future<int> deleteMultipleMusic(List<String> musicIds) async {
    int successCount = 0;
    final collection = await musicCollection;
    
    for (final id in musicIds) {
      try {
        // Get music data to get audio URL first
        final docSnap = await collection.doc(id).get();
        if (docSnap.exists) {
          final data = docSnap.data() as Map<String, dynamic>;
          final audioUrl = data['audio_url'] as String?;
          
          // Delete Firestore document
          await collection.doc(id).delete();
          
          // If there is an audio URL and it is a Storage URL, delete the file
          if (audioUrl != null && audioUrl.startsWith('https://firebasestorage.googleapis.com')) {
            await deleteAudioFile(audioUrl);
          }
          
          successCount++;
        }
      } catch (e) {
        print('Failed to delete music $id: $e');
      }
    }
    
    return successCount;
  }
  
  // Add this test method to the FirebaseService class
  Future<bool> testStorageConnection() async {
    try {
      print('===== Testing Firebase Storage connection =====');
      
      // Get storage reference information
      final storageRef = _storage.ref();
      print('Bucket name: ${storageRef.bucket}');
      
      // Create a test reference path
      final testRef = storageRef.child('test-connection');
      print('Test reference path: ${testRef.fullPath}');
      
      // Create a small test file
      final testContent = 'Test content ${DateTime.now()}';
      final testBytes = utf8.encode(testContent);
      
      // Try to upload
      print('Trying to upload test data...');
      await testRef.putData(Uint8List.fromList(testBytes));
      print('Test data uploaded successfully');
      
      // Try to download
      final url = await testRef.getDownloadURL();
      print('Test data URL obtained: $url');
      
      // Optional: delete test file
      await testRef.delete();
      print('Test data cleaned up');
      
      print('✓ Storage connection test successful');
      print('===== Testing completed =====');
      return true;
    } on FirebaseException catch (e) {
      print('✗ Storage connection test failed: [${e.code}] ${e.message}');
      
      // Detailed diagnostic information
      if (e.code == 'object-not-found') {
        print('Warning: Storage may not be properly configured or the path does not exist');
      } else if (e.code == 'unauthorized') {
        print('Warning: Insufficient permissions, please check Storage security rules');
        print('Suggestion: Temporarily set to: allow read, write: if true');
      } else if (e.code == 'storage/bucket-not-found') {
        print('Warning: Storage bucket does not exist, please create Storage in Firebase console');
      }
      
      print('===== Testing completed =====');
      return false;
    } catch (e) {
      print('✗ Storage connection test unknown error: $e');
      print('===== Testing completed =====');
      return false;
    }
  }
} 