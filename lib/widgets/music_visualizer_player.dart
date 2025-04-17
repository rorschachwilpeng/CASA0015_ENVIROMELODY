import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../widgets/audio_visualizer.dart';
import '../models/music_item.dart';
import '../services/audio_player_manager.dart';

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
  
  // Switch to next song
  void _playNextSong() async {
    final success = await _audioPlayerManager.playNext();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No next song')),
      );
    }
  }
  
  // Switch to previous song
  void _playPreviousSong() async {
    final success = await _audioPlayerManager.playPrevious();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No previous song')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Only check currentMusic instead of currentMusicId, because we need to display the player even if the music has been played
    final currentMusic = _audioPlayerManager.currentMusic;
    
    // If there is no current music information, do not display the player
    if (currentMusic == null) {
      return const SizedBox.shrink();
    }
    
    // Tidy Player
    if (!_showFullPlayer) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(
            top: BorderSide(color: Colors.grey.shade300, width: 0.5),
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
                // Music Note
                const Icon(Icons.music_note, color: Colors.purple, size: 20),
                const SizedBox(width: 10),
                // Music Information
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        currentMusic.title.isEmpty ? "Unnamed Music" : currentMusic.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Control Button
                StreamBuilder<PlayerState>(
                  stream: _audioPlayerManager.audioPlayer.playerStateStream,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data?.playing ?? false;
                    
                    return IconButton(
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: Colors.purple,
                      iconSize: 24,
                      onPressed: () {
                        if (isPlaying) {
                          _audioPlayerManager.pauseMusic();
                        } else {
                          _audioPlayerManager.resumeMusic();
                        }
                      },
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Colors.grey,
                  iconSize: 18,
                  onPressed: () {
                    _audioPlayerManager.stopMusic();
                  },
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
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Music Title and Collapse Button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                // Left Music Title
                const Icon(Icons.music_note, color: Colors.purple, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentMusic.title.isEmpty ? "Unnamed Music" : currentMusic.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Right Collapse Button and Close Button
                IconButton(
                  icon: const Icon(Icons.expand_more, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _showFullPlayer = false;
                    });
                  },
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    _audioPlayerManager.stopMusic();
                  },
                ),
              ],
            ),
          ),
          
          // Audio Visualization - More Compact
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: SizedBox(
              height: 45,
              child: AudioVisualizer(
                audioPlayer: _audioPlayerManager.audioPlayer,
                color: Colors.purple,
                backgroundColor: Colors.grey.shade100,
              ),
            ),
          ),
          
          // Progress Bar - More Compact
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
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
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                          ),
                          child: Slider(
                            value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
                            max: duration.inMilliseconds.toDouble(),
                            activeColor: Colors.purple,
                            inactiveColor: Colors.grey.shade300,
                            onChanged: (value) {
                              _audioPlayerManager.audioPlayer.seek(Duration(milliseconds: value.toInt()));
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(position),
                                style: const TextStyle(fontSize: 10),
                              ),
                              Text(
                                _formatDuration(duration),
                                style: const TextStyle(fontSize: 10),
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
          
          // Control Buttons 
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 24,
                  color: _audioPlayerManager.hasPrevious ? Colors.purple : Colors.grey,
                  onPressed: _audioPlayerManager.hasPrevious ? _playPreviousSong : null, 
                ),
                const SizedBox(width: 16),
                StreamBuilder<PlayerState>(
                  stream: _audioPlayerManager.audioPlayer.playerStateStream,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data?.playing ?? false;
                    print("PlayerState: ${snapshot.data?.playing}, ProcessingState: ${snapshot.data?.processingState}");
                    
                    return IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        size: 40,
                        color: Colors.purple,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        print("Button Clicked: Current Playback State = $isPlaying, Processing State = ${snapshot.data?.processingState}");
                        
                        if (isPlaying) {
                          print("Playing, executing pause");
                          _audioPlayerManager.pauseMusic();
                        } else {
                          print("Paused, executing resume");
                          _audioPlayerManager.resumeMusic();
                        }
                      },
                    );
                  },
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 24,
                  color: _audioPlayerManager.hasNext ? Colors.purple : Colors.grey,
                  onPressed: _audioPlayerManager.hasNext ? _playNextSong : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 