import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/music_item.dart';
import 'dart:developer' as developer;
import 'firebase_service.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'event_bus.dart';
import 'flutter_map_service.dart';

// Add to the top of the file, before the class definition
typedef MusicDeletedCallback = void Function(String musicId);

class MusicLibraryManager extends ChangeNotifier {
  // Singleton instance
  static final MusicLibraryManager _instance = MusicLibraryManager._internal();
  
  // Factory constructor to get the singleton instance
  factory MusicLibraryManager() => _instance;
  
  // Firebase service
  final FirebaseService _firebaseService = FirebaseService();
  
  // Music library list
  List<MusicItem> _musicLibrary = [];
  
  // Whether it has been initialized
  bool _initialized = false;
  
  // SharedPreferences key
  final String _storageKey = 'music_library';
  
  // Whether to use Firebase
  bool _useFirebase = true;
  
  // Get whether to use Firebase
  bool get useFirebase => _useFirebase;
  
  // Set whether to use Firebase
  set useFirebase(bool value) {
    _useFirebase = value;
    notifyListeners();
  }
  
  // Internal constructor
  MusicLibraryManager._internal();
  
  // Get all music
  List<MusicItem> get allMusic => List.unmodifiable(_musicLibrary);
  
  // New variables
  Timer? _syncTimer;
  bool _isSyncing = false;
  DateTime _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration _syncInterval = const Duration(minutes: 5); // Automatic sync interval
  
  // Record locally modified music IDs
  Set<String> _locallyModifiedMusicIds = {};
  
  // Connection status
  bool _isOnline = true;
  
  // Add callback list
  final List<MusicDeletedCallback> _musicDeletedCallbacks = [];

  // Add a method to register callbacks
  void addMusicDeletedCallback(MusicDeletedCallback callback) {
    _musicDeletedCallbacks.add(callback);
    print('Music deletion callback registered, current callback count: ${_musicDeletedCallbacks.length}');
  }

  // Add a method to remove callbacks
  void removeMusicDeletedCallback(MusicDeletedCallback callback) {
    _musicDeletedCallbacks.remove(callback);
    print('Music deletion callback removed, current callback count: ${_musicDeletedCallbacks.length}');
  }
  
  // Initialize and load from storage
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Initialize Firebase
      if (_useFirebase) {
        await _firebaseService.initialize();
        print('Firebase service initialized successfully');
        
        // Load music from Firebase
        await _loadFromFirebase();
        
        // Start periodic sync
        _startPeriodicSync();
        
        // Monitor network status
        _monitorConnectivity();
      } else {
        // Load from local storage
        await loadFromStorage();
      }
      
      // Fix invalid URLs
      await fixInvalidUrls();
      
      _initialized = true;
      notifyListeners();
      print('Music library initialized: ${_musicLibrary.length} songs');
    } catch (e) {
      print('Music library initialization failed: $e');
    }
  }
  
  // Load music from Firebase
  Future<void> _loadFromFirebase() async {
    try {
      _musicLibrary = await _firebaseService.getAllMusic();
      print('Loaded music library from Firebase: ${_musicLibrary.length} songs');
    } catch (e) {
      print('Failed to load music library from Firebase: $e');
      // Fallback to local storage
      await loadFromStorage();
    }
  }
  
  // Monitor Firebase music changes
  Stream<List<MusicItem>> get musicListStream {
    if (_useFirebase) {
      return _firebaseService.musicListStream();
    } else {
      // If not using Firebase, return an empty stream
      return Stream.value(_musicLibrary);
    }
  }
  
  // Add music
  Future<void> addMusic(MusicItem music) async {
    // Check if the music has a valid ID
    final String id = music.id.isEmpty ? const Uuid().v4() : music.id;
    final musicWithId = music.id.isEmpty ? music.copyWith(id: id) : music;
    
    // Check if the music already exists with the same ID
    final existingIndex = _musicLibrary.indexWhere((item) => item.id == musicWithId.id);
    
    if (existingIndex >= 0) {
      // Update existing music
      _musicLibrary[existingIndex] = musicWithId;
    } else {
      // Add new music
      _musicLibrary.add(musicWithId);
    }
    
    if (_useFirebase) {
      // Check if the audio is a local file, if so, upload to Firebase Storage
      if (musicWithId.audioUrl.startsWith('file://')) {
        await _uploadAudioToFirebase(musicWithId);
      } else {
        // Add directly to Firestore
        await _firebaseService.addMusic(musicWithId);
      }
    } else {
      // Save to local storage
      await saveToStorage();
    }
    
    debugPrint('Music added to library: ${musicWithId.title}');
    notifyListeners();
    
    // After completion, add this ID to the locally modified list
    _locallyModifiedMusicIds.add(music.id);
  }
  
  // Upload audio to Firebase Storage
  Future<void> _uploadAudioToFirebase(MusicItem music) async {
    print('===== Start uploading audio to Firebase =====');
    try {
      // Check if the URL is a local file
      if (!music.audioUrl.startsWith('file://')) {
        print('Not a local file path, add directly to Firestore: ${music.audioUrl}');
        await _firebaseService.addMusic(music);
        return;
      }
      
      // Extract file path
      final filePath = music.audioUrl.replaceFirst('file://', '');
      print('Local file path: $filePath');
      final file = File(filePath);
      
      if (await file.exists()) {
        print('File exists, size: ${await file.length()} bytes');
        
        // Generate file name
        final fileName = '${music.id}${path.extension(filePath)}';
        print('Upload file name: $fileName');
        
        // Upload file
        print('Start uploading file to Firebase Storage...');
        final downloadUrl = await _firebaseService.uploadAudioFile(file, fileName);
        print('File uploaded successfully, download URL: $downloadUrl');
        
        // Create a music object with the new URL
        final updatedMusic = music.copyWith(audioUrl: downloadUrl);
        print('Updated music object audio URL');
        
        // Update local list
        final index = _musicLibrary.indexWhere((item) => item.id == music.id);
        if (index >= 0) {
          _musicLibrary[index] = updatedMusic;
          print('Updated music object in local list');
        }
        
        // Save to Firestore
        print('Save updated music metadata to Firestore...');
        await _firebaseService.addMusic(updatedMusic);
        print('Audio file uploaded and saved to Firestore: ${updatedMusic.id}');
      } else {
        print('File does not exist: $filePath');
        // Still save metadata
        print('File does not exist, only save metadata to Firestore');
        await _firebaseService.addMusic(music);
      }
    } catch (e) {
      print('Failed to upload audio to Firebase: $e');
      print('Exception type: ${e.runtimeType}');
      if (e is Error) {
        print('Exception stack trace: ${e.stackTrace}');
      }
      throw Exception('Failed to upload audio to Firebase: $e');
    } finally {
      print('===== Upload audio to Firebase completed =====');
    }
  }
  
  // Remove music
  Future<bool> removeMusic(String id) async {
    // Save the music information to be deleted, for later cleanup of flags
    String? musicTitle;
    MusicItem? musicToDelete;  // Declare outside the try block
    try {
      musicToDelete = _musicLibrary.firstWhere((music) => music.id == id);
      musicTitle = musicToDelete.title;
    } catch (e) {
      // The music may not exist, continue processing
    }
    
    final previousLength = _musicLibrary.length;
    
    // Find the music to delete
    _musicLibrary.removeWhere((music) => music.id == id);
    
    // Check if the removal is successful
    final removed = previousLength > _musicLibrary.length;
    
    if (removed) {
      if (_useFirebase && musicToDelete != null && musicToDelete.id.isNotEmpty) {  // Add null check
        // Delete from Firebase
        await _firebaseService.deleteMusic(id);
        
        // If it is a Firebase Storage URL, also delete the file
        if (musicToDelete.audioUrl.startsWith('https://firebasestorage.googleapis.com')) {
          await _firebaseService.deleteAudioFile(musicToDelete.audioUrl);
        }
      } else {
        // Save to local storage
        await saveToStorage();
      }
      
      debugPrint('Music removed from library: $id');
      
      // Add code: Notify all registered callbacks
      print('Trigger music deletion callback, music ID: $id, callback count: ${_musicDeletedCallbacks.length}');
      for (var callback in _musicDeletedCallbacks) {
        callback(id);
      }
      
      notifyListeners();
      
      // Add logic to clean up map markers
      try {
        print('Attempt to clean up map markers, music ID: $id, title: $musicTitle');
        final mapService = FlutterMapService();
        mapService.cleanupFlagsByMusicInfo(id, musicTitle);
      } catch (e) {
        print('Error cleaning up map markers: $e');
      }
    }
    
    return removed;
  }
  
  // Get music details
  MusicItem? getMusicById(String id) {
    try {
      return _musicLibrary.firstWhere((music) => music.id == id);
    } catch (e) {
      return null;
    }
  }
  
  // Save to storage
  Future<void> saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert the music library to a JSON string list
      final jsonList = _musicLibrary.map((music) => jsonEncode(music.toJson())).toList();
      
      // Save the string list
      await prefs.setStringList(_storageKey, jsonList);
      
      debugPrint('Music library saved to local storage: ${_musicLibrary.length} songs');
    } catch (e) {
      debugPrint('Failed to save music library: $e');
    }
  }
  
  // Load from storage
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get the string list
      final jsonList = prefs.getStringList(_storageKey) ?? [];
      
      // Convert to MusicItem list
      _musicLibrary = jsonList.map((jsonStr) {
        try {
          final json = jsonDecode(jsonStr);
          return MusicItem.fromJson(json);
        } catch (e) {
          debugPrint('Failed to parse music item: $e');
          return null;
        }
      }).whereType<MusicItem>().toList();
      
      debugPrint('Load music library from local storage: ${_musicLibrary.length} songs');
    } catch (e) {
      debugPrint('Failed to load music library: $e');
      _musicLibrary = [];
    }
  }
  
  // Clear the library
  Future<void> clearLibrary() async {
    _musicLibrary.clear();
    
    if (_useFirebase) {
      // The function to clear the library from Firebase needs to be implemented carefully
      print('Warning: Not supported to clear all music from Firebase in bulk');
    } else {
      await saveToStorage();
    }
    
    debugPrint('Music library cleared');
    notifyListeners();
  }
  
  // Add a fix method
  Future<void> fixInvalidUrls() async {
    bool hasChanges = false;
    
    for (int i = 0; i < _musicLibrary.length; i++) {
      final music = _musicLibrary[i];
      
      // Check if it contains placeholder URL
      if (music.audioUrl.contains('your-api-base-url.com')) {
        // Extract the actual file path
        String originalUrl = music.audioUrl;
        String newUrl = '';
        
        // Try to extract the local path part
        final pathMatch = RegExp(r'/Users/.+\.mp3').firstMatch(originalUrl);
        if (pathMatch != null) {
          newUrl = pathMatch.group(0) ?? '';
          if (!newUrl.startsWith('file://')) {
            newUrl = 'file://$newUrl';
          }
        }
        
        if (newUrl.isNotEmpty) {
          _musicLibrary[i] = music.copyWith(audioUrl: newUrl);
          hasChanges = true;
          
          developer.log('Fixed audio URL: $originalUrl -> $newUrl', name: 'MusicLibraryManager');
        }
      }
    }
    
    if (hasChanges) {
      if (_useFirebase) {
        // Update Firebase for each fixed item
        for (final music in _musicLibrary) {
          if (music.audioUrl.startsWith('file://')) {
            await _uploadAudioToFirebase(music);
          }
        }
      } else {
        await saveToStorage();
      }
      
      developer.log('Fixed invalid audio URL', name: 'MusicLibraryManager');
      notifyListeners();
    }
  }
  
  // Delete multiple music
  Future<int> removeMultipleMusic(List<String> ids) async {
    int removedCount = 0;
    
    if (_useFirebase) {
      // Use Firebase to delete multiple music
      removedCount = await _firebaseService.deleteMultipleMusic(ids);
      
      // Sync delete music from local list
      _musicLibrary.removeWhere((music) => ids.contains(music.id));
      
      // Notify all callbacks
      print('Batch delete triggered callback, music ID count: ${ids.length}');
      for (String id in ids) {
        for (var callback in _musicDeletedCallbacks) {
          callback(id);
        }
      }
    } else {
      // Delete from local list
      for (String id in ids) {
        final previousLength = _musicLibrary.length;
        _musicLibrary.removeWhere((music) => music.id == id);
        
        // Check if the deletion is successful
        if (previousLength > _musicLibrary.length) {
          removedCount++;
          
          // Notify all callbacks
          print('Single delete triggered callback, music ID: $id');
          for (var callback in _musicDeletedCallbacks) {
            callback(id);
          }
        }
      }
      
      // Save to local storage
      await saveToStorage();
    }
    
    if (removedCount > 0) {
      debugPrint('Removed $removedCount songs from library');
      notifyListeners();
    }
    
    return removedCount;
  }
  
  // Download audio from remote URL and upload to Firebase
  Future<MusicItem> downloadAndUploadAudio(MusicItem music) async {
    if (!_useFirebase) {
      return music; // If not using Firebase, return directly
    }
    
    try {
      // Check if the URL is already a Firebase URL
      if (music.audioUrl.startsWith('https://firebasestorage.googleapis.com')) {
        return music;
      }
      
      // Ensure the URL is valid
      if (!music.audioUrl.startsWith('http')) {
        print('Invalid audio URL: ${music.audioUrl}');
        return music;
      }
      
      // Download file from remote
      final response = await http.get(Uri.parse(music.audioUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download audio file: ${response.statusCode}');
      }
      
      // Create a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${music.id}.mp3');
      await tempFile.writeAsBytes(response.bodyBytes);
      
      // Upload to Firebase Storage
      final fileName = '${music.id}.mp3';
      final downloadUrl = await _firebaseService.uploadAudioFile(tempFile, fileName);
      
      // Update music item
      final updatedMusic = music.copyWith(audioUrl: downloadUrl);
      
      // Save to Firestore
      await _firebaseService.addMusic(updatedMusic);
      
      // Delete temporary file
      await tempFile.delete();
      
      print('Downloaded and uploaded audio to Firebase: ${music.id}');
      return updatedMusic;
    } catch (e) {
      print('Failed to download and upload audio: $e');
      return music; // Return the original music item when error
    }
  }

  // Monitor network connection status
  void _monitorConnectivity() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;
      
      // When offline changes to online, try to sync
      if (!wasOnline && _isOnline && _useFirebase) {
        print('Network restored, start syncing data...');
        syncWithFirebase();
      }
      
      if (wasOnline != _isOnline) {
        print('Network status changed: ${_isOnline ? "Online" : "Offline"}');
        notifyListeners();
      }
    });
  }
  
  // Start periodic sync
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      if (_useFirebase && _isOnline) {
        syncWithFirebase();
      }
    });
  }
  
  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
  
  // Main sync method
  Future<void> syncWithFirebase() async {
    if (!_useFirebase || _isSyncing || !_isOnline) return;
    
    try {
      _isSyncing = true;
      print('Start syncing data with Firebase...');
      
      // 1. Push local changes to Firebase first
      await _pushLocalChangesToFirebase();
      
      // 2. Then pull the latest data from Firebase
      await _pullChangesFromFirebase();
      
      _lastSyncTime = DateTime.now();
      print('Data synced, current library has ${_musicLibrary.length} songs');
    } catch (e) {
      print('Failed to sync data: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  // Push local changes to Firebase
  Future<void> _pushLocalChangesToFirebase() async {
    if (_locallyModifiedMusicIds.isEmpty) {
      print('No local changes to push');
      return;
    }
    
    print('Push local changes to Firebase: ${_locallyModifiedMusicIds.length} items');
    
    for (final id in _locallyModifiedMusicIds.toList()) {
      try {
        final musicIndex = _musicLibrary.indexWhere((item) => item.id == id);
        if (musicIndex >= 0) {
          final music = _musicLibrary[musicIndex];
          
          // For local files, upload to Firebase Storage
          if (music.audioUrl.startsWith('file://')) {
            await _uploadAudioToFirebase(music);
          } else {
            // Directly update Firestore data
            await _firebaseService.addMusic(music);
          }
          
          _locallyModifiedMusicIds.remove(id);
          print('Synced "${music.title}" to Firebase');
        }
      } catch (e) {
        print('Failed to sync music $id to Firebase: $e');
      }
    }
  }
  
  // Pull latest changes from Firebase
  Future<void> _pullChangesFromFirebase() async {
    print('Pull latest changes from Firebase...');
    
    try {
      // Get the latest music list
      final List<MusicItem> cloudMusic = await _firebaseService.getAllMusic();
      
      // Create a map of local and cloud music for quick lookup
      final Map<String, MusicItem> localMusicMap = {
        for (var music in _musicLibrary) music.id: music
      };
      
      final Map<String, MusicItem> cloudMusicMap = {
        for (var music in cloudMusic) music.id: music
      };
      
      // Handle music in cloud but not in local (new)
      for (final cloudItem in cloudMusic) {
        final localItem = localMusicMap[cloudItem.id];
        
        if (localItem == null) {
          // Local does not have this music, add to local
          _musicLibrary.add(cloudItem);
          print('Add cloud music to local: ${cloudItem.title}');
        } else {
          // Local has this music, check if it needs to be updated
          // If local version is not modified and cloud version is updated, update local version
          if (!_locallyModifiedMusicIds.contains(cloudItem.id) && 
              (cloudItem.createdAt.isAfter(localItem.createdAt) || 
               cloudItem.audioUrl != localItem.audioUrl)) {
            
            final index = _musicLibrary.indexOf(localItem);
            _musicLibrary[index] = cloudItem;
            print('Update local music: ${cloudItem.title}');
          }
        }
      }
      
      // Music in local but not in cloud, only handle in specific cases
      // For example: If confirmed that the cloud record is deleted, consider deleting local record
      // But for data safety, here we do not automatically delete local data
      
      // Save updated local library
      await saveToStorage();
      notifyListeners();
      
    } catch (e) {
      print('Failed to pull data from Firebase: $e');
      throw e;
    }
  }
  
  // Enhanced add music method
  Future<void> addMusicAndSync(MusicItem music) async {
    // Ensure there is an ID
    final String id = music.id.isEmpty ? const Uuid().v4() : music.id;
    final musicWithId = music.id.isEmpty ? music.copyWith(id: id) : music;
    
    // Set creation time
    final now = DateTime.now();
    final musicWithTimestamp = musicWithId.copyWith(createdAt: now);
    
    // Add to local library
    await addMusic(musicWithTimestamp);
    
    // Mark as locally modified
    _locallyModifiedMusicIds.add(musicWithTimestamp.id);
    
    // If online and Firebase enabled, try to sync immediately
    if (_useFirebase && _isOnline) {
      try {
        // Sync to Firebase
        if (musicWithTimestamp.audioUrl.startsWith('file://')) {
          await _uploadAudioToFirebase(musicWithTimestamp);
        } else {
          await _firebaseService.addMusic(musicWithTimestamp);
        }
        
        // Sync successfully, remove from local modified list
        _locallyModifiedMusicIds.remove(musicWithTimestamp.id);
        print('Music "${musicWithTimestamp.title}" has been synced immediately to Firebase');
      } catch (e) {
        print('Failed to sync music immediately to Firebase: $e');
        print('Will retry next sync');
      }
    }
  }
  
  // Enhanced delete music method
  Future<bool> deleteMusicAndSync(String id) async {
    bool success = await removeMusic(id);
    
    if (success) {
      // If this ID is in the local modified list, remove it
      _locallyModifiedMusicIds.remove(id);
      
      // If online and Firebase enabled, delete from Firebase immediately
      if (_useFirebase && _isOnline) {
        try {
          await _firebaseService.deleteMusic(id);
          print('Music $id has been deleted from Firebase');
        } catch (e) {
          print('Failed to delete music from Firebase: $e');
        }
      }
    }
    
    return success;
  }
  
  // Public method to manually trigger sync
  Future<void> forceSyncWithFirebase() async {
    if (!_useFirebase) {
      print('Firebase sync is not enabled');
      return;
    }
    
    if (!_isOnline) {
      print('Device is currently offline, cannot sync');
      return;
    }
    
    return syncWithFirebase();
  }
  
  // Get sync status
  bool get isSyncing => _isSyncing;
  
  // Get last sync time
  DateTime get lastSyncTime => _lastSyncTime;
  
  // Get network status
  bool get isOnline => _isOnline;
  
  // Get pending sync items count
  int get pendingSyncItemsCount => _locallyModifiedMusicIds.length;
} 