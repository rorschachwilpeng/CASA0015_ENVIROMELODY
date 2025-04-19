import 'package:flutter/material.dart';

enum MusicVibe {
  calm,
  energetic,
  cozy,
  chill,
  // Add more as needed
}

enum MusicGenre {
  jazz,
  lofi,
  ambient,
  environmentAmbient,
  // Add more as needed
}

// Extension method to make enums more user-friendly
extension MusicVibeExtension on MusicVibe {
  String get name {
    switch (this) {
      case MusicVibe.calm:
        return 'Calm';
      case MusicVibe.energetic:
        return 'Energetic';
      case MusicVibe.cozy:
        return 'Cozy';
      case MusicVibe.chill:
        return 'Chill';
      default:
        return '';
    }
  }
  
  IconData get icon {
    switch (this) {
      case MusicVibe.calm:
        return Icons.spa;
      case MusicVibe.energetic:
        return Icons.flash_on;
      case MusicVibe.cozy:
        return Icons.local_fire_department;
      case MusicVibe.chill:
        return Icons.ac_unit;
      default:
        return Icons.music_note;
    }
  }
}

extension MusicGenreExtension on MusicGenre {
  String get name {
    switch (this) {
      case MusicGenre.jazz:
        return 'Jazz';
      case MusicGenre.lofi:
        return 'Lofi';
      case MusicGenre.ambient:
        return 'Ambient';
      case MusicGenre.environmentAmbient:
        return 'Environment Ambient';
      default:
        return '';
    }
  }
  
  IconData get icon {
    switch (this) {
      case MusicGenre.jazz:
        return Icons.music_note;
      case MusicGenre.lofi:
        return Icons.headphones;
      case MusicGenre.ambient:
        return Icons.surround_sound;
      case MusicGenre.environmentAmbient:
        return Icons.nature;
      default:
        return Icons.music_note;
    }
  }
} 