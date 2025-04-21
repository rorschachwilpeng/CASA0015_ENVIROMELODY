import 'package:flutter/material.dart';
import '../models/music_preference.dart';

class MusicPreferenceSelector extends StatefulWidget {
  final MusicVibe? initialVibe;
  final MusicGenre? initialGenre;
  final MusicScene? initialScene;
  final Function(MusicVibe?, MusicGenre?, MusicScene?) onPreferencesChanged;
  
  const MusicPreferenceSelector({
    Key? key,
    this.initialVibe,
    this.initialGenre,
    this.initialScene,
    required this.onPreferencesChanged,
  }) : super(key: key);
  
  @override
  _MusicPreferenceSelectorState createState() => _MusicPreferenceSelectorState();
}

class _MusicPreferenceSelectorState extends State<MusicPreferenceSelector> {
  MusicVibe? _selectedVibe;
  MusicGenre? _selectedGenre;
  MusicScene? _selectedScene;
  
  @override
  void initState() {
    super.initState();
    _selectedVibe = widget.initialVibe;
    _selectedGenre = widget.initialGenre;
    _selectedScene = widget.initialScene;
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Select Scene (Scene)'),
          _buildSceneSelector(),
          
          const SizedBox(height: 16),
          
          _buildSectionTitle('Select Vibe (Vibe)'),
          _buildVibeSelector(),
          
          const SizedBox(height: 16),
          
          _buildSectionTitle('Select Genre (Genre)'),
          _buildGenreSelector(),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.grey,
        ),
      ),
    );
  }
  
  Widget _buildSceneSelector() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: MusicScene.values.map((scene) {
        final isSelected = _selectedScene == scene;
        return _buildOptionCard(
          label: scene.name,
          icon: scene.icon,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedScene = null;
              } else {
                _selectedScene = scene;
                final prefs = scene.preferences;
                _selectedVibe = prefs['vibe'];
                _selectedGenre = prefs['genre'];
              }
            });
            widget.onPreferencesChanged(_selectedVibe, _selectedGenre, _selectedScene);
          },
        );
      }).toList(),
    );
  }
  
  Widget _buildVibeSelector() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: MusicVibe.values.map((vibe) {
        final isSelected = _selectedVibe == vibe;
        return _buildOptionCard(
          label: vibe.name,
          icon: vibe.icon,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              _selectedVibe = isSelected ? null : vibe;
              if (_selectedScene != null) {
                _selectedScene = null;
              }
            });
            widget.onPreferencesChanged(_selectedVibe, _selectedGenre, _selectedScene);
          },
        );
      }).toList(),
    );
  }
  
  Widget _buildGenreSelector() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: MusicGenre.values.map((genre) {
        final isSelected = _selectedGenre == genre;
        return _buildOptionCard(
          label: genre.name,
          icon: genre.icon,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              _selectedGenre = isSelected ? null : genre;
              if (_selectedScene != null) {
                _selectedScene = null;
              }
            });
            widget.onPreferencesChanged(_selectedVibe, _selectedGenre, _selectedScene);
          },
        );
      }).toList(),
    );
  }
  
  Widget _buildOptionCard({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected 
                ? [BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[800],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 