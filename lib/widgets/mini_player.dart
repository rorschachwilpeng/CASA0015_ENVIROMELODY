// import 'package:flutter/material.dart';
// import '../services/audio_player_manager.dart';
// import '../models/music_item.dart';
// import '../services/music_library_manager.dart';

// class MiniPlayer extends StatefulWidget {
//   const MiniPlayer({Key? key}) : super(key: key);

//   @override
//   _MiniPlayerState createState() => _MiniPlayerState();
// }

// class _MiniPlayerState extends State<MiniPlayer> {
//   final AudioPlayerManager _audioPlayerManager = AudioPlayerManager();
//   final MusicLibraryManager _musicLibraryManager = MusicLibraryManager();
  
//   @override
//   void initState() {
//     super.initState();
//     _audioPlayerManager.addListener(_onPlayerChanged);
//   }
  
//   @override
//   void dispose() {
//     _audioPlayerManager.removeListener(_onPlayerChanged);
//     super.dispose();
//   }
  
//   void _onPlayerChanged() {
//     if (mounted) {
//       setState(() {});
//     }
//   }
  
//   // Get the current playing music
//   MusicItem? _getCurrentMusic() {
//     final currentId = _audioPlayerManager.currentMusicId;
//     if (currentId == null || currentId.startsWith('temp_')) {
//       return null;
//     }
    
//     return _musicLibraryManager.getMusicById(currentId);
//   }

//   @override
//   Widget build(BuildContext context) {
//     // If there is no currently playing music, return an empty container
//     if (_audioPlayerManager.currentMusicId == null) {
//       return const SizedBox.shrink();
//     }
    
//     final currentMusic = _getCurrentMusic();
//     final bool isPlaying = _audioPlayerManager.isPlaying;
    
//     // If the ID is a temporary ID and cannot get music information, display a simplified version
//     if (currentMusic == null) {
//       return Container(
//         height: 60,
//         decoration: BoxDecoration(
//           color: Theme.of(context).cardColor,
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.1),
//               blurRadius: 4,
//               offset: const Offset(0, -1),
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             Expanded(
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                 child: Text(
//                   '当前正在播放音乐',
//                   style: Theme.of(context).textTheme.titleMedium,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//             ),
//             IconButton(
//               icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
//               onPressed: () {
//                 if (isPlaying) {
//                   _audioPlayerManager.pauseMusic();
//                 } else {
//                   _audioPlayerManager.resumeMusic();
//                 }
//               },
//             ),
//             IconButton(
//               icon: const Icon(Icons.close),
//               onPressed: () {
//                 _audioPlayerManager.stopMusic();
//               },
//             ),
//           ],
//         ),
//       );
//     }
    
//     // Mini player
//     return Container(
//       height: 70,
//       decoration: BoxDecoration(
//         color: Theme.of(context).cardColor,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 4,
//             offset: const Offset(0, -1),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           // Music icon
//           Container(
//             width: 50,
//             height: 50,
//             margin: const EdgeInsets.all(10),
//             decoration: BoxDecoration(
//               color: Theme.of(context).primaryColor.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(4),
//             ),
//             child: const Icon(Icons.music_note),
//           ),
//           // Music information
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Text(
//                   currentMusic.title.isEmpty ? 'Untitled Music' : currentMusic.title,
//                   style: Theme.of(context).textTheme.titleMedium,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   currentMusic.prompt,
//                   style: Theme.of(context).textTheme.bodySmall,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ],
//             ),
//           ),
//         // Control buttons
//           IconButton(
//             icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
//             onPressed: () {
//               if (isPlaying) {
//                 _audioPlayerManager.pauseMusic();
//               } else {
//                 _audioPlayerManager.resumeMusic();
//               }
//             },
//           ),
//           IconButton(
//             icon: const Icon(Icons.close),
//             onPressed: () {
//               _audioPlayerManager.stopMusic();
//             },
//           ),
//         ],
//       ),
//     );
//   }
// } 