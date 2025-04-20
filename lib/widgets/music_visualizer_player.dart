import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../widgets/audio_visualizer.dart';
import '../models/music_item.dart';
import '../services/audio_player_manager.dart';
import '../theme/pixel_theme.dart';

class MusicVisualizerPlayer extends StatefulWidget {
  const MusicVisualizerPlayer({Key? key}) : super(key: key);

  @override
  _MusicVisualizerPlayerState createState() => _MusicVisualizerPlayerState();
}

class _MusicVisualizerPlayerState extends State<MusicVisualizerPlayer> {
  final AudioPlayerManager _audioPlayerManager = AudioPlayerManager();
  bool _showFullPlayer = false;
  
  @override
  void initState() {
    super.initState();
    _audioPlayerManager.addListener(_onPlayerChanged);
    
    // 重置可能卡住的互斥锁
    _audioPlayerManager.resetPlayNextMutex();
    
    // 添加播放完成监听
    _audioPlayerManager.audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        print("Song completed detected");
        // 给自动播放一些时间，如果没有自动切换，则检查互斥锁状态
        Future.delayed(Duration(seconds: 1), () {
          if (_audioPlayerManager.isPlaying == false) {
            print("Auto play may have failed, resetting mutex");
            // 请确保 AudioPlayerManager 中有这个公开方法
            _audioPlayerManager.resetPlayNextMutex();
            // 不要自动调用 playNext，让系统自己处理
          }
        });
      }
    });
  }
  
  @override
  void dispose() {
    _audioPlayerManager.removeListener(_onPlayerChanged);
    super.dispose();
  }
  
  void _onPlayerChanged() {
    if (mounted) {
      setState(() {});
    }
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
  
  void _playNextSong() async {
    print("===== NEXT SONG FUNCTION CALLED =====");
    _checkPlaylistStatus(); // 添加调试
    
    // 正常方式尝试
    final success = await _audioPlayerManager.playNext();
    print("Next song result: $success");
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No next song')),
      );
    }
  }
  
  void _playPreviousSong() async {
    print("===== PREVIOUS SONG FUNCTION CALLED =====");
    final success = await _audioPlayerManager.playPrevious();
    print("Previous song result: $success");
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No previous song')),
      );
    }
  }
  
  void _checkPlaylistStatus() {
    print("===== PLAYLIST STATUS =====");
    print("Current index: ${_audioPlayerManager.currentIndex}");
    print("Playlist length: ${_audioPlayerManager.playlist.length}");
    print("Has next: ${_audioPlayerManager.hasNext}");
    print("Has previous: ${_audioPlayerManager.hasPrevious}");
    
    // 手动验证hasNext的计算
    if (_audioPlayerManager.playlist.isNotEmpty) {
      print("Manual check - Has next: ${_audioPlayerManager.currentIndex < _audioPlayerManager.playlist.length - 1}");
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // If the player is not visible, return an empty component
    if (!_audioPlayerManager.isPlayerVisible) {
      return const SizedBox.shrink();
    }
    
    // Only show the player when there is current music information
    final currentMusic = _audioPlayerManager.currentMusic;
    if (currentMusic == null) {
      return const SizedBox.shrink();
    }
    
    // Tidy Player
    if (!_showFullPlayer) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: PixelTheme.surface,
          border: Border(
            top: BorderSide(color: PixelTheme.text, width: 2),
          ),
        ),
        child: InkWell(
          onTap: () {
            setState(() {
              _showFullPlayer = true;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Music Note Icon
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    border: Border.all(color: PixelTheme.text, width: 1),
                    color: PixelTheme.primary.withOpacity(0.2),
                  ),
                  child: Icon(Icons.music_note, color: PixelTheme.primary, size: 16),
                ),
                const SizedBox(width: 10),
                // Music Information
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        currentMusic.title.isEmpty ? "Unnamed Music" : currentMusic.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'DMMono',
                          color: PixelTheme.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      StreamBuilder<Duration?>(
                        stream: _audioPlayerManager.audioPlayer.durationStream,
                        builder: (context, durationSnapshot) {
                          final duration = durationSnapshot.data ?? Duration.zero;
                          return StreamBuilder<Duration>(
                            stream: _audioPlayerManager.audioPlayer.positionStream,
                            builder: (context, positionSnapshot) {
                              final position = positionSnapshot.data ?? Duration.zero;
                              return Text(
                                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                style: TextStyle(
                                  fontSize: 10, 
                                  fontFamily: 'DMMono',
                                  color: PixelTheme.textLight,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // 保留原功能代码，仅修改样式
                StreamBuilder<PlayerState>(
                  stream: _audioPlayerManager.audioPlayer.playerStateStream,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data?.playing ?? false;
                    
                    return Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        border: Border.all(color: PixelTheme.text, width: 1),
                        color: PixelTheme.primary.withOpacity(0.2),
                      ),
                      child: IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 14,
                          color: PixelTheme.primary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (isPlaying) {
                            _audioPlayerManager.pauseMusic();
                          } else {
                            _audioPlayerManager.resumeMusic();
                          }
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    border: Border.all(color: PixelTheme.text, width: 1),
                    color: PixelTheme.error.withOpacity(0.2),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 14,
                      color: PixelTheme.error,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      _audioPlayerManager.stopMusic();
                      _audioPlayerManager.hidePlayer();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Full Player
    return Container(
      decoration: BoxDecoration(
        color: PixelTheme.surface,
        border: Border(
          top: BorderSide(color: PixelTheme.text, width: 2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Music Title and Collapse Button
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: PixelTheme.text.withOpacity(0.3), width: 1),
              ),
            ),
            child: Row(
              children: [
                // Left Music Title
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    border: Border.all(color: PixelTheme.text, width: 1),
                    color: PixelTheme.primary.withOpacity(0.2),
                  ),
                  child: Icon(Icons.music_note, color: PixelTheme.primary, size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentMusic.title.isEmpty ? "Unnamed Music" : currentMusic.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'DMMono',
                      color: PixelTheme.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Right Collapse Button and Close Button
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    border: Border.all(color: PixelTheme.text, width: 1),
                    color: PixelTheme.surface,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.expand_more, size: 14, color: PixelTheme.text),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _showFullPlayer = false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    border: Border.all(color: PixelTheme.text, width: 1),
                    color: PixelTheme.error.withOpacity(0.2),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.close, size: 14, color: PixelTheme.error),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      _audioPlayerManager.stopMusic();
                      _audioPlayerManager.hidePlayer();
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Audio Visualization - More Compact
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                border: Border.all(color: PixelTheme.text, width: 1),
              ),
              child: AudioVisualizer(
                audioPlayer: _audioPlayerManager.audioPlayer,
                color: PixelTheme.primary,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          
          // Progress Bar - More Compact
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: StreamBuilder<Duration?>(
              stream: _audioPlayerManager.audioPlayer.durationStream,
              builder: (context, durationSnapshot) {
                final duration = durationSnapshot.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: _audioPlayerManager.audioPlayer.positionStream,
                  builder: (context, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;
                    
                    return Column(
                      children: [
                        // 使用LayoutBuilder修复进度条宽度问题
                        Container(
                          height: 12,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: PixelTheme.text, width: 1),
                            color: Colors.white,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final availableWidth = constraints.maxWidth;
                              final progress = position.inMilliseconds / 
                                  (duration.inMilliseconds > 0 ? duration.inMilliseconds : 1);
                              final progressWidth = (availableWidth * progress)
                                  .clamp(0.0, availableWidth);
                              
                              return Row(
                                children: [
                                  Container(
                                    width: progressWidth,
                                    color: PixelTheme.primary,
                                  ),
                                  Expanded(child: Container()),
                                ],
                              );
                            }
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(position),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'DMMono',
                                  color: PixelTheme.textLight,
                                ),
                              ),
                              Text(
                                _formatDuration(duration),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'DMMono',
                                  color: PixelTheme.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          
          // 关键部分：控制按钮，确保正确调用切换歌曲的函数
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 添加调试日志以跟踪点击事件
                IconButton(
                  icon: Icon(
                    Icons.skip_previous,
                    color: _audioPlayerManager.hasPrevious ? PixelTheme.primary : PixelTheme.textLight,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 24,
                  onPressed: _audioPlayerManager.hasPrevious ? _playPreviousSong : null,
                ),
                const SizedBox(width: 16),
                StreamBuilder<PlayerState>(
                  stream: _audioPlayerManager.audioPlayer.playerStateStream,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data?.playing ?? false;
                    final processingState = snapshot.data?.processingState;
                    print("Player state update: playing=$isPlaying, state=$processingState");
                    
                    return Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(color: PixelTheme.text, width: 2),
                        color: PixelTheme.primary.withOpacity(0.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: const Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 24,
                          color: PixelTheme.primary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          print("Play/Pause button clicked - current state: $isPlaying");
                          if (isPlaying) {
                            _audioPlayerManager.pauseMusic();
                          } else {
                            _audioPlayerManager.resumeMusic();
                          }
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                // 修改下一首按钮的代码
                IconButton(
                  icon: Icon(
                    Icons.skip_next,
                    color: _audioPlayerManager.hasNext ? PixelTheme.primary : PixelTheme.textLight,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 24,
                  onPressed: () {
                    _checkPlaylistStatus(); // 添加调试
                    if (_audioPlayerManager.hasNext) {
                      _playNextSong();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No next song (from button check)')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 