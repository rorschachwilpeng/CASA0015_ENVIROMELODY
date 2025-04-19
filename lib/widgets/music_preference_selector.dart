import 'package:flutter/material.dart';
import '../models/music_preference.dart';

class MusicPreferenceSelector extends StatefulWidget {
  final MusicVibe? initialVibe;
  final MusicGenre? initialGenre;
  final Function(MusicVibe?, MusicGenre?) onPreferencesChanged;
  
  const MusicPreferenceSelector({
    Key? key,
    this.initialVibe,
    this.initialGenre,
    required this.onPreferencesChanged,
  }) : super(key: key);
  
  @override
  _MusicPreferenceSelectorState createState() => _MusicPreferenceSelectorState();
}

class _MusicPreferenceSelectorState extends State<MusicPreferenceSelector> {
  MusicVibe? _selectedVibe;
  MusicGenre? _selectedGenre;
  
  @override
  void initState() {
    super.initState();
    _selectedVibe = widget.initialVibe;
    _selectedGenre = widget.initialGenre;
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
          // Vibe selection section
          _buildSectionTitle('Select Vibe (Vibe)'),
          _buildVibeSelector(),
          
          const SizedBox(height: 16),
          
          // Genre selection section
          _buildSectionTitle('Select Genre (Genre)'),
          _buildGenreSelector(),
        ],
      ),
    );
  }
  
  // Build section title
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
  
  // Build vibe selector
  Widget _buildVibeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: MusicVibe.values.map((vibe) {
          final isSelected = _selectedVibe == vibe;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildOptionCard(
              label: vibe.name,
              icon: vibe.icon,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  _selectedVibe = isSelected ? null : vibe;
                });
                widget.onPreferencesChanged(_selectedVibe, _selectedGenre);
              },
            ),
          );
        }).toList(),
      ),
    );
  }
  
  // Build genre selector
  Widget _buildGenreSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: MusicGenre.values.map((genre) {
          final isSelected = _selectedGenre == genre;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildOptionCard(
              label: genre.name,
              icon: genre.icon,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  _selectedGenre = isSelected ? null : genre;
                });
                widget.onPreferencesChanged(_selectedVibe, _selectedGenre);
              },
            ),
          );
        }).toList(),
      ),
    );
  }
  
  // Build option card
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