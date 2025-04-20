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
  final _progressBarKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    _audioPlayerManager.addListener(_onPlayerChanged);
    
    // Reset the mutex that might get stuck
    _audioPlayerManager.resetPlayNextMutex();
    
    // Add a playback completion listener
    _audioPlayerManager.audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        print("Song completed detected");
        // Give some time for automatic playback, if it doesn't switch automatically, check the mutex status
        Future.delayed(Duration(seconds: 1), () {
          if (_audioPlayerManager.isPlaying == false) {
            print("Auto play may have failed, resetting mutex");
            // Ensure AudioPlayerManager has this public method
            _audioPlayerManager.resetPlayNextMutex();
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
    _checkPlaylistStatus(); 
    
    // Try to play next song
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
    
    // Manually verify the calculation of hasNext
    if (_audioPlayerManager.playlist.isNotEmpty) {
      print("Manual check - Has next: ${_audioPlayerManager.currentIndex < _audioPlayerManager.playlist.length - 1}");
    }
  }
  
  void _handleProgressBarTap(double dx, Duration duration) {
    if (duration == Duration.zero) return;
    
    // Use the key of the progress bar to get the RenderBox
    final RenderBox? box = _progressBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    // Get the actual width of the progress bar
    final containerWidth = box.size.width;
    
    // Limit the drag range to the container
    dx = dx.clamp(0.0, containerWidth);
    
    // Calculate the progress ratio
    final progress = dx / containerWidth;
    
    // Calculate the corresponding time position
    final position = Duration(milliseconds: (duration.inMilliseconds * progress).round());
    
    // Drag to the corresponding position
    _audioPlayerManager.seekTo(position);
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
          color: PixelTheme.secondary,
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
        color: PixelTheme.secondary,
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
                    final progress = duration.inMilliseconds > 0
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 0.0;
                    
                    return Column(
                      children: [
                        // Dragable Progress Bar
                        GestureDetector(
                          onTapDown: (details) {
                            // Calculate the progress corresponding to the clicked position
                            _handleProgressBarTap(details.localPosition.dx, duration);
                          },
                          onHorizontalDragUpdate: (details) {
                            // Calculate the progress corresponding to the dragged position
                            _handleProgressBarTap(details.localPosition.dx, duration);
                          },
                          child: Container(
                            key: _progressBarKey,
                            height: 12,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: PixelTheme.text, width: 1),
                              color: Colors.white,
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final availableWidth = constraints.maxWidth;
                                final progressWidth = (availableWidth * progress)
                                    .clamp(0.0, availableWidth);
                                
                                return Stack(
                                  children: [
                                    // Progress bar fill part
                                    Container(
                                      width: progressWidth,
                                      color: PixelTheme.primary,
                                    ),
                                    // Progress bar drag indicator
                                    Positioned(
                                      left: progressWidth - 6,
                                      top: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 12,
                                        decoration: BoxDecoration(
                                          color: PixelTheme.primary.withOpacity(0.8),
                                          border: Border.all(color: PixelTheme.text, width: 1),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                            ),
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
          
          // Key part: Control buttons, ensure correct function calls
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Add debug logs to track click events
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
                // Modify the next song button code
                IconButton(
                  icon: Icon(
                    Icons.skip_next,
                    color: _audioPlayerManager.hasNext ? PixelTheme.primary : PixelTheme.textLight,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 24,
                  onPressed: () {
                    _checkPlaylistStatus(); 
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