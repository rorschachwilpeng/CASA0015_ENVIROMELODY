import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/music_item.dart';
import '../services/music_library_manager.dart';
import 'dart:developer' as developer;
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../services/audio_player_manager.dart';
import 'dart:async'; // Add timer support
import '../widgets/audio_visualizer.dart';
import '../widgets/music_player_card.dart';
import '../services/playlist_manager.dart';
import '../theme/pixel_theme.dart'; // 导入像素主题

// Define the sort option enum
enum SortOption {
  newest, // newest created (default)
  oldest, // oldest created
  duration // duration
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final MusicLibraryManager _libraryManager = MusicLibraryManager();
  final AudioPlayerManager _audioPlayerManager = AudioPlayerManager();
  final PlaylistManager _playlistManager = PlaylistManager();
  
  bool _isLoading = true;
  
  // Add sort related state variables
  SortOption _currentSortOption = SortOption.newest; // Default to newest created
  List<MusicItem> _filteredMusicList = []; // Filtered music list after sorting
  
  // Search related state variables
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  Timer? _searchDebounce; // For implementing search throttling
  
  // Add new state variable
  bool _showMusicPlayer = false;
  
  // Multi-select related state variables
  bool _isMultiSelectMode = false;
  Set<String> _selectedMusicIds = <String>{};
  
  @override
  void initState() {
    super.initState();
    _loadLibrary();
    
    // Ensure the correct listeners are added
    _audioPlayerManager.addListener(_onAudioPlayerChanged);
    _libraryManager.addListener(_refreshLibrary);
    
    print("LibraryScreen: Initialization completed");
    
    // Set the text input listener
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    print("LibraryScreen: Destruction");
    
    // Remove listeners
    _audioPlayerManager.removeListener(_onAudioPlayerChanged);
    _libraryManager.removeListener(_refreshLibrary);
    _searchController.removeListener(_onSearchChanged);
    
    // Release resources
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    
    super.dispose();
  }
  
  void _onAudioPlayerChanged() {
    if (mounted) {
      setState(() {
        /*
        if (_audioPlayerManager.isPlaying && !_showMusicPlayer) {
          _showMusicPlayer = true;
        }
        */
      });
      //print("LibraryScreen: Playback state updated: Playing=${_audioPlayerManager.isPlaying}, Music ID=${_audioPlayerManager.currentMusicId}");
    }
  }
  
  void _refreshLibrary() {
    if (mounted) {
      setState(() {});
      _filterAndSortMusic(); // Refresh when the music library is updated
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when the page is visible
    _loadLibrary();
  }
  
  // Load the music library
  Future<void> _loadLibrary() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _libraryManager.initialize();
      
      // Apply sorting
      _filterAndSortMusic();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load music library: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Apply sorting method
  void _filterAndSortMusic() {
    if (!mounted) return;
    
    final allMusic = _libraryManager.allMusic;
    List<MusicItem> filteredList = [];
    
    // Apply search filtering
    if (_searchQuery.isEmpty) {
      filteredList = List<MusicItem>.from(allMusic);
    } else {
      final query = _searchQuery.toLowerCase();
      filteredList = allMusic.where((music) {
        final titleMatch = music.title.toLowerCase().contains(query);
        final promptMatch = music.prompt.toLowerCase().contains(query);
        final idMatch = music.id.toLowerCase().contains(query);
        return titleMatch || promptMatch || idMatch;
      }).toList();
    }
    
    // Apply sorting
    switch (_currentSortOption) {
      case SortOption.newest:
        filteredList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.oldest:
        filteredList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.duration:
        filteredList.sort((a, b) => a.title.length.compareTo(b.title.length));
        break;
    }
    
    if (mounted) {
      setState(() {
        _filteredMusicList = filteredList;
      });
    }
  }

  // Change sort option
  void _changeSortOption(SortOption option) {
    setState(() {
      _currentSortOption = option;
    });
    
    // Apply new sorting
    _filterAndSortMusic();
  }
  
  // Get sort option display text
  String _getSortOptionLabel(SortOption option) {
    switch (option) {
      case SortOption.newest:
        return 'Newest created';
      case SortOption.oldest:
        return 'Oldest created';
      case SortOption.duration:
        return 'Audio duration';
    }
  }
  
  // Build sort control UI
  Widget _buildSortControls() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Sorting method: ', style: TextStyle(color: Colors.grey[600])),
          DropdownButton<SortOption>(
            value: _currentSortOption,
            underline: Container(height: 1, color: Colors.grey[300]),
            icon: const Icon(Icons.arrow_drop_down),
            items: SortOption.values.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      option == SortOption.newest || option == SortOption.oldest 
                          ? Icons.access_time 
                          : Icons.timer,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(_getSortOptionLabel(option)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (option) {
              if (option != null) {
                _changeSortOption(option);
              }
            },
          ),
        ],
      ),
    );
  }
  
  // Play music
  Future<void> _playMusic(MusicItem music) async {
    try {
      print("Start playing music: ${music.title}, ID: ${music.id}");
      
      // Get the current list of all music
      final List<MusicItem> allMusic = _filteredMusicList;
      
      // Find the index of the currently selected music in the list
      final int currentIndex = allMusic.indexWhere((item) => item.id == music.id);
      print("Current song index: $currentIndex, list length: ${allMusic.length}");
      
      if (currentIndex >= 0) {
        // Use AudioPlayerManager to set the playlist and play the current song
        print("Setting playlist and starting playback");
        _audioPlayerManager.setPlaylist(allMusic, initialIndex: currentIndex);
      } else {
        print("Song not found in the list");
        // If the song index is not found, play the current song directly
        await _audioPlayerManager.playMusic(music.id, music.audioUrl, musicItem: music);
      }
      
      // If the player is not visible, show it
      // This line of code is no longer effective, because we removed the related player, and rely on the bottom MusicVisualizerPlayer
      // But keep it for code consistency
      if (!_showMusicPlayer) {
        setState(() {
          _showMusicPlayer = true;
        });
      }
    } catch (e) {
      print("Failed to play music: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play music: ${e.toString()}')),
        );
      }
    }
  }
  
  // Pause music
  void _pauseMusic() {
    _audioPlayerManager.pauseMusic();
  }
  
  // Delete music
  Future<void> _deleteMusic(String id) async {
    // Show the confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm deletion'),
        content: const Text('Are you sure you want to delete this music? This operation cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      // If the music is currently playing, stop playing
      if (_audioPlayerManager.currentMusicId == id && _audioPlayerManager.isPlaying) {
        _audioPlayerManager.stopMusic();
      }
      
      final removed = await _libraryManager.removeMusic(id);
      
      // Refresh the interface
      setState(() {});
      
      // Show the prompt
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(removed ? 'Music has been deleted' : 'Failed to delete'),
        ),
      );
    }
  }

  // Search text change processing
  void _onSearchChanged() {
    // Cancel the previous delay search (if any)
    _searchDebounce?.cancel();
    
    // Use Timer to implement throttling to prevent frequent searches
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
        });
        _filterAndSortMusic();
      }
    });
  }
  
  // Toggle search state
  void _toggleSearch() {
    if (!mounted) return;
    
    setState(() {
      _isSearching = !_isSearching;
      
      if (_isSearching) {
        // When searching, focus on the input box
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _searchFocusNode.requestFocus();
        });
      } else {
        // When disabling search, clear the search content
        _searchController.clear();
        _searchQuery = '';
        if (mounted) _filterAndSortMusic();
      }
    });
  }
  
  // Clear search content
  void _clearSearch() {
    if (!mounted) return;
    
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
    _filterAndSortMusic();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F4E3), 
      appBar: AppBar(
        title: _isSearching
            ? _buildSearchBar()
            : Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  'My Music Library',
                  style: PixelTheme.titleStyle.copyWith(
                    fontSize: 22,
                    letterSpacing: 0.5,
                    color: PixelTheme.primary,
                  ),
                ),
              ),
        backgroundColor: PixelTheme.surface,
        foregroundColor: PixelTheme.text,
        elevation: 0,
        centerTitle: true, 
        leading: _isSearching
            ? Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: PixelTheme.text, width: 1),
                  color: PixelTheme.surface,
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: PixelTheme.text, size: 18),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchController.clear();
                      _filterAndSortMusic();
                    });
                  },
                ),
              )
            : null,
        actions: [
          // 搜索按钮 - 复古风格
          if (!_isSearching)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(color: PixelTheme.text.withOpacity(0.5), width: 1),
                color: PixelTheme.surface,
              ),
              child: IconButton(
                icon: Icon(Icons.search, color: PixelTheme.text, size: 18),
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    _isSearching = true;
                    Future.delayed(
                      const Duration(milliseconds: 100),
                      () => _searchFocusNode.requestFocus(),
                    );
                  });
                },
              ),
            ),
          // 排序按钮 - 复古风格
          if (!_isSearching)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(color: PixelTheme.text.withOpacity(0.5), width: 1),
                color: PixelTheme.surface,
              ),
              child: IconButton(
                icon: Icon(Icons.sort, color: PixelTheme.text, size: 18),
                padding: EdgeInsets.zero,
                onPressed: _showSortOptionsDialog,
              ),
            ),
          // 刷新按钮 - 复古风格
          if (!_isSearching)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(color: PixelTheme.text.withOpacity(0.5), width: 1),
                color: PixelTheme.surface,
              ),
              child: IconButton(
                icon: Icon(Icons.refresh, color: PixelTheme.text, size: 18),
                padding: EdgeInsets.zero,
                onPressed: _loadLibrary,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // 排序信息栏 - 更精致的风格
          if (!_isSearching)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: PixelTheme.secondary.withOpacity(0.15),
                  border: Border(
                    bottom: BorderSide(color: PixelTheme.text.withOpacity(0.2), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sort, size: 14, color: PixelTheme.text),
                    const SizedBox(width: 8),
                    Text(
                      'Sorting method:',
                      style: PixelTheme.labelStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: PixelTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: PixelTheme.surface,
                        border: Border.all(color: PixelTheme.text.withOpacity(0.5), width: 1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _currentSortOption == SortOption.newest || _currentSortOption == SortOption.oldest
                                ? Icons.access_time
                                : Icons.timer,
                            size: 12,
                            color: PixelTheme.text,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getSortOptionLabel(_currentSortOption),
                            style: PixelTheme.labelStyle.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, size: 14, color: PixelTheme.text),
                        ],
                      ),
                    ),
                    Expanded(child: Container()),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: PixelTheme.surface,
                        border: Border.all(color: PixelTheme.text.withOpacity(0.5), width: 1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        'Number: ${_filteredMusicList.length}',
                        style: PixelTheme.labelStyle.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          Positioned(
            top: _isSearching && _searchQuery.isNotEmpty
                ? 40 
                : (_isSearching ? 0 : 40),
            left: 0,
            right: 0,
            bottom: 0,
            child: _isLoading
                ? Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: PixelTheme.surface,
                        border: Border.all(color: PixelTheme.text.withOpacity(0.5), width: 1),
                      ),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(PixelTheme.primary),
                      ),
                    ),
                  )
                : _filteredMusicList.isEmpty
                    ? _searchQuery.isNotEmpty
                        ? _buildPixelEmptySearchResultView()
                        : _buildPixelEmptyLibraryView()
                    : ListView.builder( // Use builder instead of separated,便于定制间距
                        padding: EdgeInsets.only(
                          bottom: 80, // Leave space for the bottom player
                          left: 12,
                          right: 12,
                          top: 8,
                        ),
                        itemCount: _filteredMusicList.length,
                        itemBuilder: (context, index) {
                          final music = _filteredMusicList[index];
                          final isPlaying = _audioPlayerManager.currentMusicId == music.id && 
                                          _audioPlayerManager.isPlaying;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: _isMultiSelectMode
                                ? _buildEnhancedMultiSelectListItem(
                                    music, 
                                    isPlaying, 
                                    _selectedMusicIds.contains(music.id),
                                  )
                                : _buildEnhancedRegularListItem(music, isPlaying, index),
                          );
                        },
                      ),
          ),
        ],
      ),

    );
  }
  
  // Build the empty view
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Your music library is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'After generating music, they will be automatically added here',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  // Show the music options menu
  void _showMusicOptions(MusicItem music) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Play'),
            onTap: () {
              Navigator.pop(context);
              _playMusic(music);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete'),
            onTap: () {
              Navigator.pop(context);
              _deleteMusic(music.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('View details'),
            onTap: () {
              Navigator.pop(context);
              _showMusicInfo(music);
            },
          ),
        ],
      ),
    );
  }

  // Add diagnostic method
  void _showMusicInfo(MusicItem music) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Music information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Title: ${music.title}'),
              const SizedBox(height: 8),
              Text('ID: ${music.id}'),
              const SizedBox(height: 8),
              Text('Prompt: ${music.prompt}'),
              const SizedBox(height: 8),
              Text('Created at: ${music.createdAt.toString()}'),
              const SizedBox(height: 16),
              Text('Audio URL:'),
              SelectableText(music.audioUrl), 
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Copy the URL to the clipboard
                  Clipboard.setData(ClipboardData(text: music.audioUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL has been copied to the clipboard')),
                  );
                },
                child: const Text('Copy URL'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  try {
                    // Check if the URL is accessible
                    final response = await http.head(Uri.parse(music.audioUrl));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('URL status: ${response.statusCode}')),
                    );
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to check URL: ${e.toString()}')),
                    );
                  }
                },
                child: const Text('Check URL accessibility'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Highlight the matching text
  Widget _highlightText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    
    final List<TextSpan> spans = [];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    
    int start = 0;
    int indexOfMatch;
    
    while (true) {
      indexOfMatch = lowerText.indexOf(lowerQuery, start);
      if (indexOfMatch < 0) {
        // No more matches
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }
      
      if (indexOfMatch > start) {
        // Add the non-matching part
        spans.add(TextSpan(text: text.substring(start, indexOfMatch)));
      }
      
      // Add the matching part (highlighted)
      spans.add(
        TextSpan(
          text: text.substring(indexOfMatch, indexOfMatch + query.length),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
            backgroundColor: Color(0x33AACCFF), // Semi-transparent background color
          ),
        ),
      );
      
      // Move to the next position
      start = indexOfMatch + query.length;
    }
    
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: spans,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // Build the search bar
  Widget _buildSearchBar() {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: PixelTheme.surface,
        border: Border.all(color: PixelTheme.text.withOpacity(0.3), width: 1),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: PixelTheme.bodyStyle.copyWith(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search music...',
          hintStyle: PixelTheme.labelStyle.copyWith(
            color: PixelTheme.textLight.withOpacity(0.7),
            fontSize: 12,
          ),
          prefixIcon: Icon(Icons.search, color: PixelTheme.text.withOpacity(0.5), size: 16),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: PixelTheme.text.withOpacity(0.5), size: 16),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }

  // Build the empty search result view
  Widget _buildPixelEmptySearchResultView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              border: Border.all(color: PixelTheme.text, width: 2),
              color: PixelTheme.surface,
            ),
            child: Icon(
              Icons.search_off,
              size: 60,
              color: PixelTheme.textLight,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No matching music',
            style: PixelTheme.titleStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'Try using different keywords to search',
            style: PixelTheme.bodyStyle,
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: PixelTheme.text, width: 2),
              color: PixelTheme.primary,
              boxShadow: PixelTheme.cardShadow,
            ),
            child: TextButton.icon(
              icon: Icon(Icons.clear, color: Colors.white, size: 18),
              label: Text(
                'Clear search',
                style: PixelTheme.bodyStyle.copyWith(color: Colors.white),
              ),
              onPressed: _clearSearch,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                backgroundColor: PixelTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Add multi-select mode toggle method
  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        // When exiting multi-select mode, clear the selected items
        _selectedMusicIds.clear();
      }
    });
  }

  // Add batch delete method
  Future<void> _deleteSelectedMusic() async {
    if (_selectedMusicIds.isEmpty) return;
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm delete'),
        content: Text('Are you sure you want to delete the selected ${_selectedMusicIds.length} music files? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      // If the currently playing music is also in the deletion list, stop playing first
      if (_selectedMusicIds.contains(_audioPlayerManager.currentMusicId) && 
          _audioPlayerManager.isPlaying) {
        _audioPlayerManager.stopMusic();
      }
      
      // Execute batch deletion
      final removedCount = await _libraryManager.removeMultipleMusic(_selectedMusicIds.toList());
      
      // Update the interface state
      setState(() {
        _selectedMusicIds.clear();
        _isMultiSelectMode = false;
      });
      
      // Show a prompt
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $removedCount music files')),
        );
      }
    }
  }

  // List item for multi-select mode
  Widget _buildMultiSelectListItem(MusicItem music, bool isPlaying, bool isSelected) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? Colors.blue.withOpacity(0.3)
            : Theme.of(context).primaryColor.withOpacity(0.1),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.blue)
            : const Icon(Icons.music_note),
      ),
      title: Text(
        music.title.isEmpty ? 'Untitled Music' : music.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            music.prompt.isEmpty ? 'No prompt' : music.prompt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            music.createdAt.toString().substring(0, 16),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selectedMusicIds.add(music.id);
            } else {
              _selectedMusicIds.remove(music.id);
            }
          });
        },
      ),
      onTap: () {
        setState(() {
          if (_selectedMusicIds.contains(music.id)) {
            _selectedMusicIds.remove(music.id);
          } else {
            _selectedMusicIds.add(music.id);
          }
        });
      },
    );
  }

  // List item for regular mode
  Widget _buildEnhancedRegularListItem(MusicItem music, bool isPlaying, int index) {
    return Dismissible(
      key: Key(music.id),
      background: Container(
        color: PixelTheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16.0),
        child: Icon(Icons.delete, color: Colors.white, size: 20),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => _buildPixelDialog(
            title: 'Confirm delete',
            content: 'Are you sure you want to delete this music file?',
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: PixelTheme.bodyStyle),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Delete', style: PixelTheme.bodyStyle.copyWith(color: PixelTheme.error)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) {
        if (mounted) {
          setState(() {
            _filteredMusicList.removeWhere((item) => item.id == music.id);
          });
        }
        
        if (_audioPlayerManager.currentMusicId == music.id && _audioPlayerManager.isPlaying) {
          _audioPlayerManager.stopMusic();
        }
        
        _libraryManager.removeMusic(music.id);
      },
      child: Container(
        decoration: BoxDecoration(
          color: PixelTheme.surface,
          border: Border.all(
            color: isPlaying ? PixelTheme.primary : PixelTheme.text.withOpacity(0.3), 
            width: isPlaying ? 2 : 1
          ),
          boxShadow: isPlaying 
              ? [BoxShadow(
                  color: PixelTheme.primary.withOpacity(0.15),
                  offset: Offset(2, 2),
                  blurRadius: 0,
                )]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: isPlaying ? PixelTheme.primary.withOpacity(0.3) : PixelTheme.text.withOpacity(0.1), 
                    width: 1
                  ),
                ),
                color: isPlaying
                    ? PixelTheme.primary.withOpacity(0.1)
                    : PixelTheme.surface,
              ),
              child: Center(
                child: Icon(
                  Icons.music_note, 
                  color: isPlaying ? PixelTheme.primary : PixelTheme.text.withOpacity(0.7), 
                  size: 22
                ),
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      music.title.isEmpty ? 'No title music' : music.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PixelTheme.bodyStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isPlaying ? PixelTheme.primary : PixelTheme.text,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      music.prompt.isEmpty ? 'No prompt' : music.prompt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PixelTheme.labelStyle.copyWith(
                        fontSize: 11,
                        color: PixelTheme.textLight,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      music.createdAt.toString().substring(0, 16),
                      style: PixelTheme.labelStyle.copyWith(
                        fontSize: 10,
                        color: PixelTheme.textLight.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            Container(
              width: 44,
              height: 44,
              margin: EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isPlaying ? PixelTheme.primary.withOpacity(0.7) : PixelTheme.text.withOpacity(0.2), 
                  width: 1
                ),
                color: isPlaying
                    ? PixelTheme.primary.withOpacity(0.1)
                    : PixelTheme.surface,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (isPlaying) {
                      _pauseMusic();
                    } else {
                      _playMusic(music);
                    }
                  },
                  child: Center(
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: isPlaying ? PixelTheme.primary : PixelTheme.text,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add or modify search status bar build method
  Widget _buildPixelSearchStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: PixelTheme.surface,
        border: Border(
          bottom: BorderSide(color: PixelTheme.text, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Search results: "${_searchQuery}" ${_filteredMusicList.isEmpty ? "(No match)" : "(${_filteredMusicList.length} items)"}',
              style: PixelTheme.labelStyle,
            ),
          ),
          if (_searchQuery.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: PixelTheme.text, width: 1),
                color: PixelTheme.surface,
              ),
              child: TextButton.icon(
                icon: Icon(Icons.clear, size: 14, color: PixelTheme.text),
                label: Text('Clear', style: PixelTheme.labelStyle),
                onPressed: _clearSearch,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(50, 28),
                  backgroundColor: PixelTheme.surface,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Add sort options dialog method
  void _showSortOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select sort option'),
        children: SortOption.values.map((option) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _changeSortOption(option);
            },
            child: Row(
              children: [
                Icon(
                  option == SortOption.newest || option == SortOption.oldest 
                      ? Icons.access_time 
                      : Icons.timer,
                  color: _currentSortOption == option 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey[600],
                ),
                const SizedBox(width: 16),
                Text(
                  _getSortOptionLabel(option),
                  style: TextStyle(
                    color: _currentSortOption == option 
                        ? Theme.of(context).primaryColor 
                        : null,
                    fontWeight: _currentSortOption == option 
                        ? FontWeight.bold 
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Add bottom sheet dialog method
  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.select_all),
            title: const Text('Multi-select mode'),
            onTap: () {
              Navigator.pop(context);
              _toggleMultiSelectMode();
            },
          ),
          ListTile(
            leading: const Icon(Icons.sort),
            title: const Text('Sort options'),
            onTap: () {
              Navigator.pop(context);
              _showSortOptionsDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Refresh list'),
            onTap: () {
              Navigator.pop(context);
              _loadLibrary();
            },
          ),
        ],
      ),
    );
  }

  // Build the empty library view
  Widget _buildEmptyLibraryView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Your music library is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'After generating music, they will be automatically added here',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Add pixel dialog method
  Widget _buildPixelDialog({
    required String title,
    required String content,
    List<Widget>? actions,
  }) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: PixelTheme.surface,
          border: PixelTheme.pixelBorder,
          boxShadow: PixelTheme.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: PixelTheme.text, width: 2)),
                color: PixelTheme.primary.withOpacity(0.1),
              ),
              child: Text(
                title,
                style: PixelTheme.titleStyle,
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                content,
                style: PixelTheme.bodyStyle,
              ),
            ),
            if (actions != null)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: PixelTheme.text, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions.map((action) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: action,
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Add pixel empty library view method
  Widget _buildPixelEmptyLibraryView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              border: Border.all(color: PixelTheme.text, width: 2),
              color: PixelTheme.surface,
            ),
            child: Icon(
              Icons.music_off,
              size: 60,
              color: PixelTheme.textLight,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your music library is empty',
            style: PixelTheme.titleStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'After generating music, they will be automatically added here',
            style: PixelTheme.bodyStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedMultiSelectListItem(MusicItem music, bool isPlaying, bool isSelected) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? Colors.blue.withOpacity(0.3)
            : Theme.of(context).primaryColor.withOpacity(0.1),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.blue)
            : const Icon(Icons.music_note),
      ),
      title: Text(
        music.title.isEmpty ? 'Untitled Music' : music.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            music.prompt.isEmpty ? 'No prompt' : music.prompt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            music.createdAt.toString().substring(0, 16),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selectedMusicIds.add(music.id);
            } else {
              _selectedMusicIds.remove(music.id);
            }
          });
        },
      ),
      onTap: () {
        setState(() {
          if (_selectedMusicIds.contains(music.id)) {
            _selectedMusicIds.remove(music.id);
          } else {
            _selectedMusicIds.add(music.id);
          }
        });
      },
    );
  }


  Widget _buildNavItem(IconData icon, String label, bool isActive, Function() onTap) {
    final activeColor = PixelTheme.primary;
    final inactiveColor = PixelTheme.text.withOpacity(0.7);
    
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon, 
            color: isActive ? activeColor : inactiveColor,
            size: 22,
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: PixelTheme.labelStyle.copyWith(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }

} 