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
  
  // 播放列表
  List<MusicItem> _playlist = [];
  
  // 当前播放索引
  int _currentIndex = -1;
  
  // 是否启用自动播放下一首
  bool _autoPlayEnabled = true;
  
  // 获取当前播放列表
  List<MusicItem> get playlist => List.unmodifiable(_playlist);
  
  // 获取当前播放索引
  int get currentIndex => _currentIndex;
  
  // 判断是否有下一首歌曲
  bool get hasNext => _playlist.isNotEmpty && _currentIndex < _playlist.length - 1;
  
  // 判断是否有上一首歌曲
  bool get hasPrevious => _playlist.isNotEmpty && _currentIndex > 0;
  
  // 获取/设置自动播放下一首功能
  bool get autoPlayEnabled => _autoPlayEnabled;
  set autoPlayEnabled(bool value) {
    _autoPlayEnabled = value;
    notifyListeners();
  }
  
  // 添加一个唯一的监听器使播放结束后直接执行回调
  StreamSubscription<Duration>? _durationSubscription;
  
  // 互斥锁变量，防止playNext被多次同时调用
  bool _isPlayNextExecuting = false;
  
  // Internal constructor
  AudioPlayerManager._internal() {
    // 配置播放器
    _configurePlayer();
    
    // 方法1：通过processingStateStream监听
    _player.processingStateStream.listen((state) {
      print("处理状态变化: $state");
      if (state == ProcessingState.completed) {
        print("方法1检测到播放完成");
        _handlePlaybackCompletion();
      }
    });
    
    // 方法2：通过playerStateStream监听
    _player.playerStateStream.listen((state) {
      print("播放状态变化: playing=${state.playing}, state=${state.processingState}");
      if (state.processingState == ProcessingState.completed) {
        print("方法2检测到播放完成");
        _handlePlaybackCompletion();
      }
      notifyListeners();
    });
    
    // 方法3：直接使用onPlayerComplete回调
    _player.playbackEventStream.listen((event) {
      print("播放事件: ${event.processingState}");
      if (event.processingState == ProcessingState.completed) {
        print("方法3检测到播放完成");
        _handlePlaybackCompletion();
      }
    });
    
    // 位置监听，用于更新进度条
    _player.positionStream.listen((position) {
      // 检查是否接近结束
      Duration? duration = _player.duration;
      if (duration != null && position >= duration - const Duration(milliseconds: 500)) {
        print("检测到接近结束位置: $position / $duration");
      }
      notifyListeners();
    });
  }
  
  // 统一处理播放完成
  void _handlePlaybackCompletion() {
    print("开始处理播放完成事件");
    
    // 确保在主线程中执行，并添加短延迟
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_autoPlayEnabled && hasNext) {
        print("自动播放下一首: 当前索引=$_currentIndex, 列表长度=${_playlist.length}");
        playNext().then((success) {
          print("播放下一首结果: $success");
        }).catchError((error) {
          print("播放下一首出错: $error");
        });
      } else {
        print("自动播放已禁用或没有下一首: autoPlay=$_autoPlayEnabled, hasNext=$hasNext");
      }
    });
  }
  
  // 配置播放器设置
  void _configurePlayer() {
    // 设置音频会话配置
    try {
      _player.setLoopMode(LoopMode.off); // 关闭循环播放单曲
      _player.setAutomaticallyWaitsToMinimizeStalling(true); // 减少卡顿
      
      // 添加播放器错误监听
      _player.playbackEventStream.listen((event) {}, 
        onError: (Object e, StackTrace st) {
          print('播放器错误: $e');
          print('错误堆栈: $st');
        }
      );
      
      // 确保设置了监听器
      _setupCompletionHandler();
      
      print("播放器配置完成");
    } catch (e) {
      print("播放器配置失败: $e");
    }
  }
  
  // 设置播放完成处理器
  void _setupCompletionHandler() {
    // 取消之前的订阅
    _durationSubscription?.cancel();
    
    // 创建新的订阅
    _durationSubscription = _player.positionStream.listen((position) {
      Duration? totalDuration = _player.duration;
      if (totalDuration != null) {
        // 检查是否达到结束位置（接近总时长）
        if (position >= totalDuration - const Duration(milliseconds: 200) && position > Duration.zero) {
          print("通过位置检测到歌曲播放完成: $position / $totalDuration");
          
          // 直接尝试播放下一首（延迟执行以避免状态冲突）
          if (_player.processingState != ProcessingState.loading && 
              _player.processingState != ProcessingState.buffering) {
            _handlePlaybackCompletion();
          }
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
    print("开始播放音乐: ID=$musicId");
    
    try {
      // 保存音乐信息
      if (musicItem != null) {
        _currentMusic = musicItem;
        print("已保存当前播放音乐信息: ${musicItem.title}");
        
        // 更新播放列表和当前索引
        int existingIndex = _playlist.indexWhere((item) => item.id == musicId);
        if (existingIndex >= 0) {
          // 如果歌曲已在播放列表中，直接设置当前索引
          _currentIndex = existingIndex;
          print("歌曲已在播放列表中，索引: $_currentIndex");
        } else {
          // 否则，添加到播放列表并设置为当前歌曲
          _playlist.add(musicItem);
          _currentIndex = _playlist.length - 1;
          print("歌曲已添加到播放列表，索引: $_currentIndex");
        }
      }
      
      // 如果同一首歌曲已经在播放，则不做任何事
      if (_currentMusicId == musicId && _player.playing) {
        print("相同歌曲已在播放中，不重新播放");
        return;
      }
      
      // 设置当前音乐ID（播放操作前）
      _currentMusicId = musicId;
      
      // 播放前通知监听器更新UI
      notifyListeners();
      
      // 如果另一首歌曲正在播放，先停止它
      if (_player.playing) {
        print("停止当前播放的音乐");
        await _player.stop();
      }
      
      // 尝试设置音频源并播放
      print("设置音频URL: ${audioUrl.substring(0, math.min(50, audioUrl.length))}...");
      await _player.setUrl(audioUrl);
      
      // 重新设置完成处理器
      _setupCompletionHandler();
      
      print("开始播放");
      await _player.play();
      
      // 播放后通知监听器更新UI
      notifyListeners();
      print("播放开始成功");
    } catch (e) {
      print('播放音乐失败: $e');
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
    // 不再清除 _currentMusicId，只暂停播放
    // _currentMusicId = null; // 移除此行
    notifyListeners();
  }
  
  // Play next song
  Future<bool> playNext() async {
    // 如果正在执行，则返回
    if (_isPlayNextExecuting) {
      print("playNext 正在执行中，跳过重复调用");
      return false;
    }
    
    // 设置互斥锁
    _isPlayNextExecuting = true;
    
    try {
      // 检查是否有下一首
      if (!hasNext) {
        print("没有下一首歌曲可播放");
        return false;
      }
      
      // 检查列表是否为空
      if (_playlist.isEmpty) {
        print("播放列表为空");
        return false;
      }
      
      // 确保索引在有效范围内
      int nextIndex = _currentIndex + 1;
      if (nextIndex >= _playlist.length) {
        print("已到达播放列表末尾");
        return false;
      }
      
      // 更新索引
      _currentIndex = nextIndex;
      print("切换到下一首歌曲，索引: $_currentIndex / ${_playlist.length}");
      
      // 获取下一首歌曲
      MusicItem nextMusic = _playlist[_currentIndex];
      print("即将播放: ${nextMusic.title}");
      
      // 播放下一首
      await playMusic(nextMusic.id, nextMusic.audioUrl, musicItem: nextMusic);
      print("成功开始播放下一首歌曲");
      return true;
    } catch (e) {
      print('播放下一首歌曲失败: $e');
      return false;
    } finally {
      // 释放互斥锁
      _isPlayNextExecuting = false;
    }
  }
  
  // Play previous song
  Future<bool> playPrevious() async {
    if (!hasPrevious) {
      print("没有上一首歌曲");
      return false;
    }
    
    try {
      // Move to previous index
      _currentIndex--;
      print("移动到上一首歌曲，索引: $_currentIndex");
      MusicItem prevMusic = _playlist[_currentIndex];
      
      // Play previous song
      print("播放上一首: ${prevMusic.title}, ID: ${prevMusic.id}");
      await playMusic(prevMusic.id, prevMusic.audioUrl, musicItem: prevMusic);
      return true;
    } catch (e) {
      print('播放上一首失败: $e');
      return false;
    }
  }
  
  // Set playlist
  void setPlaylist(List<MusicItem> songs, {int initialIndex = 0}) {
    if (songs.isEmpty) {
      print("播放列表为空，不设置");
      return;
    }
    
    _playlist = List.from(songs);
    _currentIndex = initialIndex.clamp(0, _playlist.length - 1);
    
    print("设置播放列表: ${_playlist.length}首歌, 起始索引: $_currentIndex");
    
    // If initial index is provided, immediately play that song
    if (_playlist.isNotEmpty) {
      final initialSong = _playlist[_currentIndex];
      print("开始播放列表中的歌曲: ${initialSong.title}, ID: ${initialSong.id}");
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
    // 取消订阅
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
} 