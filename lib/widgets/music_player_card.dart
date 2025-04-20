// import 'package:flutter/material.dart';
// import 'package:just_audio/just_audio.dart';
// import '../widgets/audio_visualizer.dart';
// import '../models/music_item.dart';

// class MusicPlayerCard extends StatefulWidget {
//   final MusicItem musicItem;
//   final AudioPlayer audioPlayer;
//   final VoidCallback? onClose;
//   final VoidCallback? onPrevious;
//   final VoidCallback? onNext;
//   final bool hasPrevious;
//   final bool hasNext;
  
//   const MusicPlayerCard({
//     Key? key,
//     required this.musicItem,
//     required this.audioPlayer,
//     this.onClose,
//     this.onPrevious,
//     this.onNext,
//     this.hasPrevious = false,
//     this.hasNext = false,
//   }) : super(key: key);

//   @override
//   _MusicPlayerCardState createState() => _MusicPlayerCardState();
// }

// class _MusicPlayerCardState extends State<MusicPlayerCard> {
//   String _formatDuration(Duration duration) {
//     String twoDigits(int n) => n.toString().padLeft(2, '0');
//     String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
//     String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
//     return "$twoDigitMinutes:$twoDigitSeconds";
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       margin: const EdgeInsets.all(8),
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Padding(
//             padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
//             child: Row(
//               children: [
//                 const Icon(Icons.music_note, color: Colors.purple),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     widget.musicItem.title.isEmpty ? "Unnamed Music" : widget.musicItem.title,
//                     style: const TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//                 if (widget.onClose != null)
//                   IconButton(
//                     icon: const Icon(Icons.close, size: 20),
//                     padding: EdgeInsets.zero,
//                     constraints: const BoxConstraints(),
//                     onPressed: widget.onClose,
//                   ),
//               ],
//             ),
//           ),
          
//           // Audio Visualization Component
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 12),
//             child: AudioVisualizer(
//               audioPlayer: widget.audioPlayer,
//               color: Colors.purple,
//               backgroundColor: Colors.grey.shade100,
//             ),
//           ),
          
//           // Progress Bar
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             child: StreamBuilder<Duration?>(
//               stream: widget.audioPlayer.durationStream,
//               builder: (context, durationSnapshot) {
//                 final duration = durationSnapshot.data ?? Duration.zero;
//                 return StreamBuilder<Duration>(
//                   stream: widget.audioPlayer.positionStream,
//                   builder: (context, positionSnapshot) {
//                     final position = positionSnapshot.data ?? Duration.zero;
//                     return Column(
//                       children: [
//                         Slider(
//                           value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
//                           max: duration.inMilliseconds.toDouble(),
//                           activeColor: Colors.purple,
//                           inactiveColor: Colors.grey.shade300,
//                           onChanged: (value) {
//                             widget.audioPlayer.seek(Duration(milliseconds: value.toInt()));
//                           },
//                         ),
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 16),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Text(
//                                 _formatDuration(position),
//                                 style: const TextStyle(fontSize: 12),
//                               ),
//                               Text(
//                                 _formatDuration(duration),
//                                 style: const TextStyle(fontSize: 12),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
          
//           // Control Buttons
//           Padding(
//             padding: const EdgeInsets.all(8),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 IconButton(
//                   icon: const Icon(Icons.skip_previous),
//                   onPressed: widget.hasPrevious ? widget.onPrevious : null,
//                   color: widget.hasPrevious ? Colors.purple : Colors.grey,
//                 ),
//                 StreamBuilder<PlayerState>(
//                   stream: widget.audioPlayer.playerStateStream,
//                   builder: (context, snapshot) {
//                     final playerState = snapshot.data;
//                     final processingState = playerState?.processingState;
//                     final playing = playerState?.playing;
                    
//                     if (processingState == ProcessingState.loading ||
//                         processingState == ProcessingState.buffering) {
//                       return Container(
//                         width: 48,
//                         height: 48,
//                         padding: const EdgeInsets.all(8),
//                         child: const CircularProgressIndicator(
//                           valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
//                         ),
//                       );
//                     } else if (playing != true) {
//                       return IconButton(
//                         icon: const Icon(Icons.play_circle_filled),
//                         iconSize: 48,
//                         color: Colors.purple,
//                         onPressed: () {
//                           widget.audioPlayer.play().then((_) {
//                             print("Play button clicked: Starting playback");
//                           });
//                         },
//                       );
//                     } else {
//                       return IconButton(
//                         icon: const Icon(Icons.pause_circle_filled),
//                         iconSize: 48,
//                         color: Colors.purple,
//                         onPressed: () {
//                           widget.audioPlayer.pause().then((_) {
//                             print("Pause button clicked: Pausing playback");
//                           });
//                         },
//                       );
//                     }
//                   },
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.skip_next),
//                   onPressed: widget.hasNext ? widget.onNext : null,
//                   color: widget.hasNext ? Colors.purple : Colors.grey,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// } 