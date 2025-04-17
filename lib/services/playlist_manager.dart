import 'package:flutter/foundation.dart';
import '../models/music_item.dart';
import '../services/audio_player_manager.dart';

/// Playlist manager, responsible for handling playlist-related functions
class PlaylistManager extends ChangeNotifier {
  // Singleton instance
  static final PlaylistManager _instance = PlaylistManager._internal();
  
  // Factory constructor to get singleton instance
  factory PlaylistManager() => _instance;
  
  // Internal constructor
  PlaylistManager._internal() {
    // Add listener to audio player when initialized
    _audioPlayerManager.addListener(_onAudioPlayerChanged);
  }
  
  // Audio player manager
  final AudioPlayerManager _audioPlayerManager = AudioPlayerManager();
  
  // Playlist
  List<MusicItem> _playlist = [];
  
  // Current playing index
  int _currentIndex = -1;
  
  // Get current playlist
  List<MusicItem> get playlist => List.unmodifiable(_playlist);
  
  // Get current playing index
  int get currentIndex => _currentIndex;
  
  // Check if there is a next song
  bool get hasNext => _playlist.isNotEmpty && _currentIndex < _playlist.length - 1;
  
  // Check if there is a previous song
  bool get hasPrevious => _playlist.isNotEmpty && _currentIndex > 0;
  
  // When the playback state changes
  void _onAudioPlayerChanged() {
    // If there is no music playing, it may be playback completion
    if (!_audioPlayerManager.isPlaying && _audioPlayerManager.currentMusicId == null) {
      _currentIndex = -1;
    }
    
    // Notify listeners
    notifyListeners();
  }
  
  // Set playlist
  void setPlaylist(List<MusicItem> songs, {int initialIndex = 0}) {
    if (songs.isEmpty) return;
    
    _playlist = List.from(songs);
    _currentIndex = initialIndex.clamp(0, _playlist.length - 1);
    
    // If an initial index is provided, play that song immediately
    if (_playlist.isNotEmpty) {
      final initialSong = _playlist[_currentIndex];
      _audioPlayerManager.playMusic(initialSong.id, initialSong.audioUrl, musicItem: initialSong);
    }
    
    notifyListeners();
  }
  
  // Play next song
  Future<bool> playNext() async {
    if (!hasNext) return false;
    
    try {
      // Move to the next index
      _currentIndex++;
      MusicItem nextMusic = _playlist[_currentIndex];
      
      // Play next song
      await _audioPlayerManager.playMusic(nextMusic.id, nextMusic.audioUrl, musicItem: nextMusic);
      notifyListeners();
      return true;
    } catch (e) {
      print('Failed to play next song: $e');
      return false;
    }
  }
  
  // Play previous song
  Future<bool> playPrevious() async {
    if (!hasPrevious) return false;
    
    try {
      // Move to the previous index
      _currentIndex--;
      MusicItem prevMusic = _playlist[_currentIndex];
      
      // Play previous song
      await _audioPlayerManager.playMusic(prevMusic.id, prevMusic.audioUrl, musicItem: prevMusic);
      notifyListeners();
      return true;
    } catch (e) {
      print('Failed to play previous song: $e');
      return false;
    }
  }
  
  // Clean up resources
  @override
  void dispose() {
    _audioPlayerManager.removeListener(_onAudioPlayerChanged);
    super.dispose();
  }
} 