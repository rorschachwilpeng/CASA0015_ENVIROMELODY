import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:developer' as developer;
import '../models/music_item.dart';

class AudioPlayerManager extends ChangeNotifier {
  // Singleton instance
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();
  
  // Factory constructor to get the singleton instance
  factory AudioPlayerManager() => _instance;
  
  // Audio player
  final AudioPlayer _player = AudioPlayer();
  
  // Current playing music ID
  String? _currentMusicId;
  
  // Storage current music information
  MusicItem? _currentMusic;
  
  // Playlist
  List<MusicItem> _playlist = [];
  
  // Current playing index
  int _currentIndex = -1;
  
  // Whether auto play next song is enabled
  bool _autoPlayEnabled = true;
  
  // Get current playlist
  List<MusicItem> get playlist => List.unmodifiable(_playlist);
  
  // Get current playing index
  int get currentIndex => _currentIndex;
  
  // Check if there is a next song
  bool get hasNext => _playlist.isNotEmpty && _currentIndex < _playlist.length - 1;
  
  // Check if there is a previous song
  bool get hasPrevious => _playlist.isNotEmpty && _currentIndex > 0;
  
  // Get/set auto play next song feature
  bool get autoPlayEnabled => _autoPlayEnabled;
  set autoPlayEnabled(bool value) {
    _autoPlayEnabled = value;
    notifyListeners();
  }
  
  // Add a unique listener to execute the callback after playback ends
  StreamSubscription<Duration>? _durationSubscription;
  
  // Mutex variable to prevent playNext from being called multiple times simultaneously
  bool _isPlayNextExecuting = false;
  
  // Add player visibility status
  bool _isPlayerVisible = false;
  
  // Add player visibility getter and setter
  bool get isPlayerVisible => _isPlayerVisible;
  void showPlayer() {
    _isPlayerVisible = true;
    notifyListeners();
    print('Player is now visible');
  }

  void hidePlayer() {
    _isPlayerVisible = false;
    notifyListeners();
    print('Player is now hidden');
  }
  
  // Add locking time record
  DateTime? _playNextLockTime;
  
  // Add prevent duplicate call flag
  bool _isHandlingCompletion = false;
  
  // Add debug mode flag
  bool _debugMode = true;
   
  void _log(String message) {
    if (_debugMode) {
      print("[AudioPlayerManager] $message");
    }
  }
  
  // Internal constructor
  AudioPlayerManager._internal() {
    // Configure the player
    _configurePlayer();
    
    // Method 1: Listen to processingStateStream
    _player.processingStateStream.listen((state) {
      print("ProcessingState: $state");
      if (state == ProcessingState.completed) {
        print("Method 1 detected playback completion");
        _handlePlaybackCompletion();
      }
    });
    
    // Method 2: Listen to playerStateStream
    _player.playerStateStream.listen((state) {
      print("PlayerState: playing=${state.playing}, state=${state.processingState}");
      if (state.processingState == ProcessingState.completed) {
        print("Detected playback completion from playerStateStream");
        _handlePlaybackCompletion();
      }
      notifyListeners();
    });
    
    // Method 3: Use onPlayerComplete callback directly
    _player.playbackEventStream.listen((event) {
      print("PlaybackEvent: ${event.processingState}");
      if (event.processingState == ProcessingState.completed) {
        print("Method 3 detected playback completion");
        _handlePlaybackCompletion();
      }
    });
    
    // Position listener, used to update the progress bar
    _player.positionStream.listen((position) {
      notifyListeners();  // 只用于UI更新，不检测播放完成
    });
  }
  
  // Handle playback completion
  void _handlePlaybackCompletion() {
    print("Begin to handle playback completion event");
    
    // If already handling, return
    if (_isHandlingCompletion) {
      print("Already handling completion, skipping duplicate call");
      return;
    }
    
    _isHandlingCompletion = true;
    
    // Ensure execution in the main thread and add a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        if (_autoPlayEnabled && hasNext) {
          print("Auto play next song: current index=$_currentIndex, list length=${_playlist.length}");
          // Ensure mutex lock is reset before calling playNext
          _isPlayNextExecuting = false;
          playNext().then((success) {
            print("Play next song result: $success");
          }).catchError((error) {
            print("Play next song error: $error");
          });
        } else {
          print("Auto play is disabled or there is no next song: autoPlay=$_autoPlayEnabled, hasNext=$hasNext");
        }
      } finally {
        _isHandlingCompletion = false;
      }
    });
  }
  
  // Configure player settings
  void _configurePlayer() {
    // Set audio session configuration
    try {
      _player.setLoopMode(LoopMode.off); // Disable loop playback of a single song
      _player.setAutomaticallyWaitsToMinimizeStalling(true); // Minimize stalling
      
      // Add player error listener
      _player.playbackEventStream.listen((event) {}, 
        onError: (Object e, StackTrace st) {
          print('Player error: $e');
          print('Error stack: $st');
        }
      );
      
      // Ensure the listener is set
      _setupCompletionHandler();
      
      print("Player configuration completed");
    } catch (e) {
      print("Player configuration failed: $e");
    }
  }
  
  // Set playback completion handler
  void _setupCompletionHandler() {
    // Cancel previous subscription
    _durationSubscription?.cancel();
    
    // Create a new subscription
    _durationSubscription = _player.positionStream.listen((position) {
      // 只记录日志，不触发自动播放
      Duration? totalDuration = _player.duration;
      if (totalDuration != null) {
        if (position >= totalDuration - const Duration(milliseconds: 200) && position > Duration.zero) {
          print("Position approaching end: $position / $totalDuration");
        }
      }
    });
  }
  
  // Get the current playing music ID
  String? get currentMusicId => _currentMusicId;
  
  // Whether it is playing - directly use player state
  bool get isPlaying => _player.playing;
  
  // Get current music
  MusicItem? get currentMusic => _currentMusic;
  
  // Play music
  Future<void> playMusic(String musicId, String audioUrl, {MusicItem? musicItem}) async {
    print("Start playing music: ID=$musicId");
    
    try {
      // Save music information
      if (musicItem != null) {
        _currentMusic = musicItem;
        print("Current playing music information saved: ${musicItem.title}");
        
        // Update playlist and current index
        int existingIndex = _playlist.indexWhere((item) => item.id == musicId);
        if (existingIndex >= 0) {
          // If the song is already in the playlist, set the current index directly
          _currentIndex = existingIndex;
          print("Song already in playlist, index: $_currentIndex");
        } else {
          // Otherwise, add to playlist and set as current song
          _playlist.add(musicItem);
          _currentIndex = _playlist.length - 1;
          print("Song added to playlist, index: $_currentIndex");
        }
      }
      
      // If the same song is already playing, do nothing
      if (_currentMusicId == musicId && _player.playing) {
        print("Same song is already playing, do not replay");
        showPlayer(); // Ensure the player is visible
        return;
      }
      
      // Set current music ID (before playback operation)
      _currentMusicId = musicId;
      
      // Notify listeners before playback
      showPlayer(); // Show the player
      notifyListeners();
      
      // If another song is playing, stop it first
      if (_player.playing) {
        print("Stop current playing music");
        await _player.stop();
      }
      
      // Try to set the audio source and play
      print("Setting audio URL: ${audioUrl.substring(0, math.min(50, audioUrl.length))}...");
      await _player.setUrl(audioUrl);
      
      // Reset completion handler
      _setupCompletionHandler();
      
      print("Start playing");
      await _player.play();
      
      // Notify listeners after playback
      notifyListeners();
      print("Playback started successfully");
    } catch (e) {
      print('Failed to play music: $e');
      // 确保在发生错误时也释放资源
      _isPlayNextExecuting = false;
      _isHandlingCompletion = false;
      notifyListeners();
      rethrow;
    }
  }
  
  // Pause playback
  Future<void> pauseMusic() async {
    if (_player.playing) {
      await _player.pause();
      notifyListeners();
    }
  }
  
  // Resume playback
  Future<void> resumeMusic() async {
    try {
      if (_currentMusicId != null && !_player.playing) {
        await _player.play();
        notifyListeners();
      }
    } catch (e) {
      print('Resume playback failed: $e');
      notifyListeners();
    }
  }
  
  // Stop playback
  Future<void> stopMusic() async {
    await _player.stop();
    // Do not clear _currentMusicId, only pause playback
    // _currentMusicId = null; // Remove this line
    notifyListeners();
  }
  
  // Play next song
  Future<bool> playNext() async {
    // If it is executing, check if it is timed out
    if (_isPlayNextExecuting) {
      if (_playNextLockTime != null && 
          DateTime.now().difference(_playNextLockTime!).inSeconds > 2) {
        // If locked for more than 2 seconds, force reset
        print("Play next locked for too long (${DateTime.now().difference(_playNextLockTime!).inSeconds}s), force reset");
        _isPlayNextExecuting = false;
      } else {
        print("playNext is executing, skip duplicate call");
        return false;
      }
    }
    
    // Set mutex lock and record time
    _isPlayNextExecuting = true;
    _playNextLockTime = DateTime.now();
    
    try {
      // Check if there is a next song
      if (!hasNext) {
        print("No next song to play");
        return false;
      }
      
      // Check if the playlist is empty
      if (_playlist.isEmpty) {
        print("Playlist is empty");
        return false;
      }
      
      // Ensure the index is within the valid range
      int nextIndex = _currentIndex + 1;
      if (nextIndex >= _playlist.length) {
        print("Reached the end of the playlist");
        return false;
      }
      
      // Update index
      _currentIndex = nextIndex;
      print("Switch to next song, index: $_currentIndex / ${_playlist.length}");
      
      // Get next song
      MusicItem nextMusic = _playlist[_currentIndex];
      print("Next song: ${nextMusic.title}");
      
      // Play next song
      await playMusic(nextMusic.id, nextMusic.audioUrl, musicItem: nextMusic);
      print("Successfully started playing next song");
      return true;
    } catch (e) {
      print('Failed to play next song: $e');
      return false;
    } finally {
      // Release mutex lock
      _isPlayNextExecuting = false;
      _playNextLockTime = null;
    }
  }
  
  // Play previous song
  Future<bool> playPrevious() async {
    if (!hasPrevious) {
      print("No previous song");
      return false;
    }
    
    try {
      // Move to previous index
      _currentIndex--;
      print("Move to previous song, index: $_currentIndex");
      MusicItem prevMusic = _playlist[_currentIndex];
      
      // Play previous song
      print("Previous song: ${prevMusic.title}, ID: ${prevMusic.id}");
      await playMusic(prevMusic.id, prevMusic.audioUrl, musicItem: prevMusic);
      return true;
    } catch (e) {
      print('Failed to play previous song: $e');
      return false;
    }
  }
  
  // Set playlist
  void setPlaylist(List<MusicItem> songs, {int initialIndex = 0}) {
    if (songs.isEmpty) {
      print("Playlist is empty, do not set");
      return;
    }
    
    _playlist = List.from(songs);
    _currentIndex = initialIndex.clamp(0, _playlist.length - 1);
    
    print("Set playlist: ${_playlist.length} songs, starting index: $_currentIndex");
    
    // If initial index is provided, immediately play that song
    if (_playlist.isNotEmpty) {
      final initialSong = _playlist[_currentIndex];
      print("Start playing the song in the playlist: ${initialSong.title}, ID: ${initialSong.id}");
      playMusic(initialSong.id, initialSong.audioUrl, musicItem: initialSong);
    }
  }
  
  // Seek to specific position
  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
    notifyListeners();
  }
  
  // Get current playback position
  Stream<Duration> get positionStream => _player.positionStream;
  
  // Get audio total duration
  Duration? get duration => _player.duration;
  
  // Add this getter to expose the audioPlayer
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  
  // Get current position
  Duration get position => _player.position;
  
  // Clean up resources
  @override
  void dispose() {
    // Cancel subscription
    _durationSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
  
  // Public method to dispose player
  void disposePlayer() {
    _player.dispose();
  }
  
  // Add this getter to expose the audioPlayer
  AudioPlayer get audioPlayer => _player;
  
  // Add this method to reset the playNext mutex
  void resetPlayNextMutex() {
    _isPlayNextExecuting = false;
    print("Play next mutex reset");
  }
} 