import 'package:flutter/material.dart';

enum MusicVibe {
  calm,
  energetic,
  cozy,
  chill,
  gentle,
  uplifting,
  melancholic,
  mystical,
  dreamy,
  dark,
  bright,
  natureInspired,
  // Add more as needed
}

enum MusicGenre {
  jazz,
  lofi,
  ambient,
  environmentAmbient,
  downtempo,
  newAge,
  classical,
  cultureMusic,
  ambientElectronic,
  // Add more as needed
}

enum MusicScene {
  meditation,        // Meditation
  deepWork,          // Deep Work
  readingWriting,    // Reading & Writing
  stressRelief,      // Stress Relief
  sensoryAwakening,  // Sensory Awakening
  housework,         // Housework
  quickTasks,        // Quick Tasks
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
      case MusicVibe.gentle:
        return 'Gentle';
      case MusicVibe.uplifting:
        return 'Uplifting';
      case MusicVibe.melancholic:
        return 'Melancholic';
      case MusicVibe.mystical:
        return 'Mystical';
      case MusicVibe.dreamy:
        return 'Dreamy';
      case MusicVibe.dark:
        return 'Dark';
      case MusicVibe.bright:
        return 'Bright';
      case MusicVibe.natureInspired:
        return 'Nature-inspired';
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
      case MusicVibe.gentle:
        return Icons.air;
      case MusicVibe.uplifting:
        return Icons.emoji_emotions;
      case MusicVibe.melancholic:
        return Icons.cloud;
      case MusicVibe.mystical:
        return Icons.auto_awesome;
      case MusicVibe.dreamy:
        return Icons.nightlight_round;
      case MusicVibe.dark:
        return Icons.nights_stay;
      case MusicVibe.bright:
        return Icons.wb_sunny;
      case MusicVibe.natureInspired:
        return Icons.nature;
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
      case MusicGenre.downtempo:
        return 'Downtempo';
      case MusicGenre.newAge:
        return 'New Age';
      case MusicGenre.classical:
        return 'Classical';
      case MusicGenre.cultureMusic:
        return 'Culture Music';
      case MusicGenre.ambientElectronic:
        return 'Ambient Electronic';
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
      case MusicGenre.downtempo:
        return Icons.slow_motion_video;
      case MusicGenre.newAge:
        return Icons.insights;
      case MusicGenre.classical:
        return Icons.piano;
      case MusicGenre.cultureMusic:
        return Icons.public;
      case MusicGenre.ambientElectronic:
        return Icons.electric_bolt;
      default:
        return Icons.music_note;
    }
  }
}

// MusicSceneExtension
extension MusicSceneExtension on MusicScene {
  String get name {
    switch (this) {
      case MusicScene.meditation:
        return 'Meditation';
      case MusicScene.deepWork:
        return 'Deep Work';
      case MusicScene.readingWriting:
        return 'Reading & Writing';
      case MusicScene.stressRelief:
        return 'Stress Relief';
      case MusicScene.sensoryAwakening:
        return 'Sensory Awakening';
      case MusicScene.housework:
        return 'Housework';
      case MusicScene.quickTasks:
        return 'Quick Tasks';
      default:
        return '';
    }
  }
  
  IconData get icon {
    switch (this) {
      case MusicScene.meditation:
        return Icons.self_improvement;
      case MusicScene.deepWork:
        return Icons.work;
      case MusicScene.readingWriting:
        return Icons.menu_book;
      case MusicScene.stressRelief:
        return Icons.sentiment_satisfied_alt;
      case MusicScene.sensoryAwakening:
        return Icons.visibility;
      case MusicScene.housework:
        return Icons.cleaning_services;
      case MusicScene.quickTasks:
        return Icons.task_alt;
      default:
        return Icons.category;
    }
  }
  
  // Get preferences based on scene
  Map<String, dynamic> get preferences {
    switch (this) {
      case MusicScene.meditation:
        return {
          'vibe': MusicVibe.gentle,
          'genre': MusicGenre.environmentAmbient,
        };
      case MusicScene.deepWork:
        return {
          'vibe': MusicVibe.calm,
          'genre': MusicGenre.ambient,
        };
      case MusicScene.readingWriting:
        return {
          'vibe': MusicVibe.gentle,
          'genre': MusicGenre.classical,
        };
      case MusicScene.stressRelief:
        return {
          'vibe': MusicVibe.uplifting,
          'genre': MusicGenre.newAge,
        };
      case MusicScene.sensoryAwakening:
        return {
          'vibe': MusicVibe.dreamy,
          'genre': MusicGenre.ambientElectronic,
        };
      case MusicScene.housework:
        return {
          'vibe': MusicVibe.energetic,
          'genre': MusicGenre.ambient,
        };
      case MusicScene.quickTasks:
        return {
          'vibe': MusicVibe.uplifting,
          'genre': MusicGenre.downtempo,
        };
      default:
        return {
          'vibe': null,
          'genre': null,
        };
    }
  }
} 