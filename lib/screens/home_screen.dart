import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/flutter_map_service.dart';
import '../models/weather_service.dart'; // Import weather service
import '../services/music_library_manager.dart'; // Import MusicLibraryManager
import '../models/music_item.dart';
import '../services/music_library_manager.dart';
import '../services/stability_audio_service.dart';
import '../utils/config.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import '../services/audio_player_manager.dart';
import '../models/music_preference.dart';
import '../widgets/music_preference_selector.dart';
import '../services/deepseek_api_service.dart';
import '../services/event_bus.dart';
import '../services/geocoding_service.dart';
import '../theme/pixel_theme.dart';
import 'package:location/location.dart';
import 'package:flutter/foundation.dart';

// Define FlagInfo class (put at the top of the file, all classes outside)
class FlagInfo {
  final LatLng position;
  final WeatherData? weatherData;
  final DateTime createdAt;
  final String? musicTitle; // If music is generated, store the music title
  
  FlagInfo({
    required this.position,
    this.weatherData,
    required this.createdAt,
    this.musicTitle,
  });
}

// Define a class to manage map state at the top of the file
class MapState {
  LatLng center;
  double zoom;
  bool isReady = false;
  
  MapState({
    required this.center,
    required this.zoom,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Flutter Map Service
  final FlutterMapService _mapService = FlutterMapService();
  
  // Weather service
  final WeatherService _weatherService = WeatherService();
  
  // Map Controller
  MapController _mapController = MapController();
  
  // State Variables
  bool _isMapReady = false;
  bool _isLoadingLocation = false;
  bool _isLoadingWeather = false; // New: weather data loading status
  bool _isPlacingFlag = false; // Whether placing a flag
  
  // Music Markers List
  final List<String> _musicMarkers = [];
  
  // Selected location and weather data
  LatLng? _selectedLocation;
  WeatherData? _weatherData;
  
  // Define a constant for the country zoom level
  static const double COUNTRY_ZOOM_LEVEL = 6.0; // Country zoom level
  
  // Track the time and position of the last tap
  DateTime? _lastTapTime;
  LatLng? _lastTapPosition;
  static const _doubleTapThreshold = Duration(milliseconds: 300); // Double tap threshold
  
  // Add in _HomeScreenState class
  final List<String> _weatherMarkerIds = [];
  
  // FlagInfo storage mapping
  final Map<String, FlagInfo> _flagInfoMap = {};
  
  // Add a static variable, used to control whether it is the first load
  static bool _isFirstLoad = true;
  
  // Add these variables in _HomeScreenState class
  LatLng? _mapCenterPosition;
  double? _mapZoomLevel = COUNTRY_ZOOM_LEVEL;
  
  // Use this status object
  late MapState _mapState;
  
  // Add in the class
  LatLng _currentCenter = LatLng(51.5074, -0.1278); // London default position
  double _currentZoom = 6.0;
  
  // Add these variables in _HomeScreenState class, used to save the last map state
  LatLng _lastMapCenter = LatLng(51.5074, -0.1278); // London default position
  double _lastMapZoom = 6.0; // Default zoom level
  bool _hasInitializedOnce = false; // Used to track whether it has been initialized
  
  // Add these variables in _HomeScreenState class
  MusicVibe? _selectedVibe;
  MusicGenre? _selectedGenre;
  
  // Add DeepSeekApiService instance in _HomeScreenState class
  final DeepSeekApiService _deepSeekApiService = DeepSeekApiService(
    apiKey: AppConfig.deepSeekApiKey,
  );
  
  // Add a new property in _HomeScreenState class
  StreamSubscription? _musicDeletedSubscription;
  
  // Add a new property in _HomeScreenState class
  final TextEditingController _searchController = TextEditingController();
  final GeocodingService _geocodingService = GeocodingService();
  List<GeocodingResult> _searchResults = [];
  bool _isSearching = false;
  
  @override
  void initState() {
    super.initState();
    
    // Initanize Map Controller
    _mapController = MapController();
    
    // Add Page LifeCycle Observer
    WidgetsBinding.instance.addObserver(this);
    
    // Init map status 
    _mapState = MapState(
      center: _mapService.getDefaultLocation(),
      zoom: COUNTRY_ZOOM_LEVEL,
    );
    
    _initMapService();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocationService();
      _loadPersistentFlags();
    });
    
    
    // Listen to map zoom and move events
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove) {
        // Update zoom level
        _mapService.updateZoom(event.zoom);
        // Update our own status variables
        _updateMapState();
      }
    });
    
    // Set zoom change callback, trigger interface redraw when zoom changes
    _mapService.setZoomChangedCallback((zoom) {
      if (mounted) {
        setState(() {
          // Empty setState, only used to trigger interface redraw, so all markers update size according to the new zoom level
        });
      }
    });
    
    // Add music deleted callback
    final libraryManager = MusicLibraryManager();
    libraryManager.addMusicDeletedCallback(_handleMusicDeleted);
    print('HomeScreen has registered music deleted callback');
    
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // You can check the status here and initialize
    if (!_isMapReady && _mapController != null) {
      _onMapReady();
    }
  }
  
  // Listen to page status changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When the application resumes from the background
      _selectedVibe = null;
      _selectedGenre = null;
      
      if (_hasInitializedOnce) {
        // If it has been initialized before, only recreate the controller but do not move to the current location
        _mapController = MapController();
        _initMapService();
        
        // Restore map position and zoom level after the next frame is drawn
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isMapReady && mounted) {
            try {
              if (_mapController != null) {
                // Add a safety check to ensure the map controller is ready
                if (isMapControllerReady()) {
                  _mapController.move(_lastMapCenter, _lastMapZoom);
                  // Reload all markers
                  _loadPersistentFlags();
                  print('Successfully restored map position: center=${_lastMapCenter}, zoom=${_lastMapZoom}');
                } else {
                  print('Map controller is not ready, cannot move map');
                  // Set a delay, try again later
                  Future.delayed(Duration(milliseconds: 500), () {
                    if (mounted && isMapControllerReady()) {
                      _mapController.move(_lastMapCenter, _lastMapZoom);
                      print('Successfully restored map position after delay');
                    }
                  });
                }
              }
            } catch (e) {
              print('Error restoring map position: $e');
            }
          }
        });
      }
    } else if (state == AppLifecycleState.paused) {
      // When the application enters the background, save the current map state
      try {
        _lastMapCenter = _mapController.center;
        _lastMapZoom = _mapController.zoom;
      } catch (e) {
        print('Error saving map state: $e');
      }
    }
  }
  
  void _initMapService() {
    // Only move to the current location when it is the first initialization
    _mapService.initMap(_mapController, autoMoveToCurrentLocation: !_hasInitializedOnce);
  }
  
  Future<void> _checkInitialLocationPermission() async {
    try {
      final hasPermission = await _mapService.checkLocationPermission();
      if (!hasPermission && mounted) {
        // If there is no permission, show the permission request dialog
        _showLocationPermissionDialog();
      } else {
        // If there is already permission, initialize the location service
        _initLocationService();
      }
    } catch (e) {
      print("DEBUG: Error checking initial permission: $e");
      // If there is an error, also initialize the location service
      _initLocationService();
    }
  }
  
  Future<void> _initLocationService() async {
    try {
      setState(() {
        _isLoadingLocation = true;
      });
      
      await _mapService.getCurrentLocation();
      
      if (_isMapReady) {
        await _mapService.moveToCurrentLocation();
      }
    } catch (e) {
      print("📍 Location error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    print('HomeScreen destroyed: cancel all subscriptions and asynchronous operations');
    
    // Remove music deleted callback
    final libraryManager = MusicLibraryManager();
    libraryManager.removeMusicDeletedCallback(_handleMusicDeleted);
    
    // Save current state
    try {
      _lastMapCenter = _mapController.center;
      _lastMapZoom = _mapController.zoom;
      print('Save map state: center=${_lastMapCenter}, zoom=${_lastMapZoom}');
    } catch (e) {
      print('Error saving map state: $e');
    }
    
    // Clean up map components
    _mapService.clearMarkers();
    WidgetsBinding.instance.removeObserver(this);
    _mapService.dispose();
    
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    
    super.dispose();
  }
  
  // When the map is ready
  void _onMapReady() {
    print("DEBUG: Map is ready");
    
    setState(() {
      _mapState.isReady = true;
      _isMapReady = true;
    });
    
    // Only execute when it is the first load
    if (_isFirstLoad && !_hasInitializedOnce) {
      _goToCurrentLocation();
      _isFirstLoad = false;
      _hasInitializedOnce = true;
    } else {
      // If it is not the first load, try to restore the last saved position
      try {
        _mapController.move(_lastMapCenter, _lastMapZoom);
        print("DEBUG: Successfully restored map position");
      } catch (e) {
        print('DEBUG: Error restoring map position: $e');
      }
    }
  }
  
  // Go to current location
  Future<void> _goToCurrentLocation() async {
    if (!_isMapReady || _mapController == null) {
      print("DEBUG: Map is not ready, trying again later");
      
      // If the map is not ready, delay execution
      Future.delayed(Duration(seconds: 1), () {
        if (mounted && _isMapReady) {
          _goToCurrentLocation();
        }
      });
      return;
    }
    
    setState(() {
      _isLoadingLocation = true;
    });
    
    // Use SchedulerBinding.addPostFrameCallback to safely display SnackBar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Getting your location...'))
        );
      }
    });
    
    try {
      // Add timeout mechanism
      bool locationObtained = false;
      Timer? timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!locationObtained && mounted) {
          print("DEBUG: Get location timeout (15 seconds)");
          setState(() {
            _isLoadingLocation = false;
          });
          
          // Safely display information
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Get location timeout, using default location.'))
              );
            }
          });
        }
      });
      
      // Get location permission first  
      bool hasPermission = await _mapService.requestLocationPermission();
      if (!hasPermission) {
        print("DEBUG: No location permission, showing permission request dialog");
        timeoutTimer.cancel();
        
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
          
          // Show permission request dialog
          _showLocationPermissionDialog();
        }
        return;
      }
      
      print("DEBUG: Getting current location");
      await _mapService.getCurrentLocation();
      
      if (_isMapReady && mounted) {
        print("DEBUG: Moving map to current locationp to current location");
        await _mapService.moveToCurrentLocation();
        locationObtained = true;
        timeoutTimer.cancel();
        
        // After getting the current location, display detailed information
        final currentPos = _mapService.currentLatLng;
        print("DEBUG: Current location - Latitude: ${currentPos?.latitude}, Longitude: ${currentPos?.longitude}");
        
        // Show location information
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Current Location: ${currentPos?.latitude.toStringAsFixed(4)}, ${currentPos?.longitude.toStringAsFixed(4)}'),
                duration: Duration(seconds: 4),
              )
            );
          }
        });
      }
    } catch (e) {
      print('DEBUG: Error getting location: $e');
      
      if (mounted) {
        // Use addPostFrameCallback to display error information
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cannot access your location: $e'))
            );
          }
        });
      }
    } finally {
      // Ensure status update
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }
  
  // Get weather data for the clicked location
  Future<void> _getWeatherForLocation(LatLng location, String flagId, [bool addMarker = true]) async {
    if (!_isMapReady) return;
    
    setState(() {
      _isLoadingWeather = true;
      _selectedLocation = location;
    });
    
    try {
      // Get weather data
      final weatherData = await _weatherService.getWeatherByLocation(
        location.latitude, 
        location.longitude
      );
      
      if (mounted) {
        setState(() {
          _weatherData = weatherData;
          
          // Create flag information
          FlagInfo flagInfo = FlagInfo(
            position: location,
            weatherData: weatherData,
            createdAt: DateTime.now(),
          );
          
          // Save to local status
          _flagInfoMap[flagId] = flagInfo;
          
          // Save to persistent service
          if (addMarker) {
            _mapService.saveFlagInfo(flagId, flagInfo);
          }
        });
      }
    } catch (e) {
      print('Error getting weather data: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get weather data')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
        });
      }
    }
  }

  // Modify _updateFlagMarkerTapEvent method
  void _updateFlagMarkerTapEvent(String flagId, WeatherData weatherData) {
    
    // Convert LocationData to LatLng
    LatLng latLng = LatLng(
      weatherData.location!.latitude,  // Adjust according to the actual LocationData structure
      weatherData.location!.longitude  // Adjust according to the actual LocationData structure
    );
    
    // Try multiple matching methods
    int removedCount = 0;
    
    // 1. Use exact matching
    _mapService.removeMarker(flagId);
    
    // 2. If exact matching does not delete any markers, try containing matching
    if (removedCount == 0) {
      _mapService.addMarker(
        id: flagId,
        position: latLng,
        title: '',
        icon: _buildFlagMarkerIcon(),
        onTap: () {
          _showFlagInfoWindow(flagId, latLng);
        },
        onLongPress: () {
          _showDeleteMarkerDialog(flagId);
        },
      );
    }
  }

  // Handle double-tap map events
  void _handleMapDoubleTap(TapPosition tapPosition, LatLng location) {
    print('Double tapped at: ${location.latitude}, ${location.longitude}');
    
    // Get weather data for the clicked location
    _getWeatherForLocation(location, '', false);
    
    // Move to the location and slightly zoom in
    _mapController.move(location, _mapController.zoom + 1);
  }
  
  // Build weather marker icon
  Widget _buildWeatherMarkerIcon() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        _getWeatherIcon(),
        color: _getWeatherColor(),
        size: _mapService.calculateMarkerSize(15.0),
      ),
    );
  }
  
  // Get weather icon based on weather condition
  IconData _getWeatherIcon() {
    if (_weatherData == null) return Icons.cloud;
    
    final condition = _weatherData!.weatherMain.toLowerCase();
    
    if (condition.contains('clear')) {
      return Icons.wb_sunny;
    } else if (condition.contains('cloud')) {
      return Icons.cloud;
    } else if (condition.contains('rain')) {
      return Icons.water_drop;
    } else if (condition.contains('snow')) {
      return Icons.ac_unit;
    } else if (condition.contains('fog') || condition.contains('mist')) {
      return Icons.cloud;
    } else if (condition.contains('wind') || condition.contains('storm')) {
      return Icons.air;
    } else {
      return Icons.cloud;
    }
  }
  
  // Get weather color based on weather condition
  Color _getWeatherColor() {
    if (_weatherData == null) return Colors.grey;
    
    final condition = _weatherData!.weatherMain.toLowerCase();
    
    if (condition.contains('clear')) {
      return Colors.orange;
    } else if (condition.contains('cloud')) {
      return Colors.blueGrey;
    } else if (condition.contains('rain')) {
      return Colors.blue;
    } else if (condition.contains('snow')) {
      return Colors.lightBlue;
    } else if (condition.contains('fog') || condition.contains('mist')) {
      return Colors.grey;
    } else if (condition.contains('wind') || condition.contains('storm')) {
      return Colors.deepPurple;
    } else {
      return Colors.grey;
    }
  }
  
  // Modify map click event processing method
  void _handleMapTap(TapPosition tapPosition, LatLng location) {
    _saveCurrentMapState(); // Save current map state
    
    print('Map clicked, placing flag mode: $_isPlacingFlag');
    
    if (_isPlacingFlag) {
      // Place flag at the clicked location
      _placeFlagAndGetWeather(location);
      
      // Reset marker status
      setState(() {
        _isPlacingFlag = false;
      });
      
    } else {
      // When not in flag placement mode, check if a nearby flag was clicked
      _checkFlagNearby(location);
    }
  }
  
  // Check if there is a nearby flag
  void _checkFlagNearby(LatLng tapLocation) {
    // Iterate through all flag information
    String? nearestFlagId;
    double minDistance = double.infinity;
    final double threshold = 0.005; // Threshold of about 500 meters
    
    _flagInfoMap.forEach((flagId, flagInfo) {
      final LatLng flagPos = flagInfo.position;
      
      // Calculate distance (simple Euclidean distance)
      final double dist = sqrt(
        pow(tapLocation.latitude - flagPos.latitude, 2) + 
        pow(tapLocation.longitude - flagPos.longitude, 2)
      );
      
      // If within the threshold and is the nearest, record this flag
      if (dist < threshold && dist < minDistance) {
        minDistance = dist;
        nearestFlagId = flagId;
      }
    });
    
    // If a nearby flag is found, display its information
    if (nearestFlagId != null) {
      final flagInfo = _flagInfoMap[nearestFlagId]!;
      _showFlagInfoWindow(nearestFlagId!, flagInfo.position);
    }
  }
  
  // Modify the place flag method
  void _placeFlagAndGetWeather(LatLng location) {
    print('Getting weather at: ${location.latitude}, ${location.longitude}');
    
    // Generate a unique identifier, but do not add the marker immediately
    String flagId = 'flag_${DateTime.now().millisecondsSinceEpoch}';
    
    // Move to the selected location
    _safelyMoveMap(location, _mapController.zoom);
    
    // Get weather data, but do not save to persistent storage
    _getWeatherForLocation(location, flagId, false); // Add parameter to indicate not to add marker
    
    // Refresh UI to display weather data, but do not show the marker
    setState(() {});
  }
  
  // Build flag marker icon
  Widget _buildFlagMarkerIcon() {
    return Container(
      // Add a transparent click area
      width: 40,
      height: 40,
      alignment: Alignment.center,
      color: Colors.transparent, // Transparent background, increase click area
      child: Icon(
        Icons.flag,
        color: Colors.red,
        size: 15.0, 
      ),
    );
  }
  
  // Add new method: display delete marker dialog
  void _showDeleteMarkerDialog(String markerId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete marker'),
        content: const Text('Are you sure you want to delete this marker?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              
              _deleteFlag(markerId);
              
              // If the marker to be deleted is a weather marker, also clear weather data
              if (markerId.contains('weather_')) {
                setState(() {
                  _weatherData = null;
                });
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PixelTheme.background, // Set yellow background
      appBar: AppBar(
        backgroundColor: PixelTheme.surface,
        title: Text(
          'ENVIROMELODY',
          style: TextStyle(
            ////fontFamily: 'DMMono', // Use monospaced font
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5, // Increase letter spacing
            color: PixelTheme.text,
          ),
        ),
        elevation: 0,
        shape: Border(
          bottom: BorderSide(
            color: PixelTheme.text,
            width: 2.0,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Map card design
          Container(
            margin: const EdgeInsets.fromLTRB(12, 70, 12, 80), // Leave space for top and bottom
            decoration: BoxDecoration(
              color: Colors.white,
              border: PixelTheme.pixelBorder,
              boxShadow: PixelTheme.cardShadow,
            ),
            child: ClipRRect(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  center: _isFirstLoad ? _mapService.getDefaultLocation() : _lastMapCenter,
                  zoom: _isFirstLoad ? COUNTRY_ZOOM_LEVEL : _lastMapZoom,
                  onMapReady: _onMapReady,
                  onTap: _handleMapTap,
                  onPositionChanged: _handleMapMoved,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.soundscape_app',
                  ),
                  MarkerLayer(
                    markers: _mapService.markers,
                  ),
                ],
              ),
            ),
          ),
          
          // Search bar design
          Positioned(
            top: 16,
            left: 12,
            right: 12,
            child: Container(
              decoration: BoxDecoration(
                color: PixelTheme.surface,
                border: PixelTheme.pixelBorder,
                boxShadow: PixelTheme.cardShadow,
              ),
              height: 48,
              child: TextField(
                controller: _searchController,
                style: PixelTheme.bodyStyle, // Use monospaced font
                decoration: InputDecoration(
                  hintText: 'Search location...',
                  hintStyle: TextStyle(
                    ////fontFamily: 'DMMono',
                    fontSize: 14,
                    color: PixelTheme.textLight,
                  ),
                  prefixIcon: Icon(Icons.search, size: 20, color: PixelTheme.text),
                  suffixIcon: _searchController.text.isNotEmpty
                    ? Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: PixelTheme.error,
                          border: Border.all(color: PixelTheme.text, width: 1),
                        ),
                        child: InkWell(
                          onTap: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                            });
                          },
                          child: Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      )
                    : _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                ),
                onSubmitted: _searchPlaces,
              ),
            ),
          ),
          
          // Search results list
          if (_searchResults.isNotEmpty)
            Positioned(
              top: 70,
              left: 12,
              right: 12,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.3,
                ),
                decoration: BoxDecoration(
                  color: PixelTheme.surface,
                  border: PixelTheme.pixelBorder,
                  boxShadow: PixelTheme.cardShadow,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, index) => Divider(
                    color: PixelTheme.text.withOpacity(0.3),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _selectSearchResult(result),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                result.type == 'city' ? Icons.location_city :
                                result.type == 'country' ? Icons.public :
                                Icons.location_on,
                                size: 18,
                                color: PixelTheme.text,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      result.name.split(',').first,
                                      style: PixelTheme.bodyStyle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      result.address?.toString() ?? result.name,
                                      style: PixelTheme.labelStyle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          
          // Bottom button bar
          Positioned(
            bottom: 16,
            left: 12,
            right: 12,
            child: Container(
              decoration: BoxDecoration(
                color: PixelTheme.surface,
                border: PixelTheme.pixelBorder,
                boxShadow: PixelTheme.cardShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPixelMapButton(
                      icon: _isPlacingFlag ? Icons.cancel : Icons.flag,
                      label: _isPlacingFlag ? 'Cancel flag' : 'Place flag',
                      onTap: _toggleFlagPlacementMode,
                      color: _isPlacingFlag ? PixelTheme.error : PixelTheme.primary,
                    ),
                    _buildPixelMapButton(
                      icon: Icons.my_location,
                      label: 'My location',
                      onTap: _goToCurrentLocation,
                      color: PixelTheme.accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Map zoom buttons
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPixelZoomButton(
                  icon: Icons.add,
                  onPressed: () {
                    double currentZoom = _mapZoomLevel ?? COUNTRY_ZOOM_LEVEL;
                    double newZoom = currentZoom + 1;
                    if (newZoom > 17) newZoom = 17;
                    
                    _safelyMoveMap(_mapCenterPosition ?? _mapService.getDefaultLocation(), newZoom);
                  },
                ),
                const SizedBox(height: 8),
                _buildPixelZoomButton(
                  icon: Icons.remove,
                  onPressed: () {
                    double currentZoom = _mapController.zoom;
                    double newZoom = currentZoom - 1;
                    if (newZoom < 3) newZoom = 3;
                    
                    _mapController.move(
                      _mapController.center,
                      newZoom
                    );
                  },
                ),
              ],
            ),
          ),
                
          // Weather information card
          if (_weatherData != null)
            Positioned(
              top: 75,
              left: 16,
              right: 16,
              child: _buildPixelWeatherCard(_weatherData!),
            ),
        
          // Loading indicator
          if (_isLoadingWeather)
            Positioned(
              top: 75,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: PixelTheme.surface,
                  border: PixelTheme.pixelBorder,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PixelTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Getting weather data...',
                      style: PixelTheme.labelStyle,
                    ),
                  ],
                ),
              ),
            ),
          
          // Place flag prompt bar
          if (_isPlacingFlag)
            Positioned(
              top: 70,
              left: 0,
              right: 0,
              child: Container(
                alignment: Alignment.center,
                color: PixelTheme.error.withOpacity(0.8),
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Click map to place flag',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        //fontFamily: 'DMMono',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // if (kDebugMode) // 导入 package:flutter/foundation.dart 来使用 kDebugMode
          //   Positioned(
          //     top: 120,
          //     right: 16,
          //     child: Container(
          //       width: 40,
          //       height: 40,
          //       decoration: BoxDecoration(
          //         color: Colors.red.withOpacity(0.7),
          //         borderRadius: BorderRadius.circular(20),
          //       ),
          //       child: IconButton(
          //         icon: Icon(Icons.location_searching, color: Colors.white, size: 20),
          //         onPressed: () {
          //           // 直接显示权限对话框
          //           _showLocationPermissionDialog();
          //         },
          //         tooltip: '请求位置权限',
          //       ),
          //     ),
          //   ),
        ],
      ),
    );
  }
  
  Widget _buildPixelWeatherCard(WeatherData weatherData) {
    final location = weatherData.location?.getFormattedLocation() ?? weatherData.cityName;
    
    return Container(
      decoration: BoxDecoration(
        color: PixelTheme.surface,
        border: Border.all(color: PixelTheme.text, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top title bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: PixelTheme.text, width: 2),
              ),
              color: PixelTheme.secondary.withOpacity(0.3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      //fontFamily: 'DMMono',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _weatherData = null;
                      for (var id in _weatherMarkerIds) {
                        _mapService.removeMarker(id);
                      }
                      _weatherMarkerIds.clear();
                    });
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      border: Border.all(color: PixelTheme.text, width: 1),
                      color: PixelTheme.error,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Weather information section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left temperature display
                Container(
                  width: 80,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: PixelTheme.text.withOpacity(0.3), width: 1),
                    color: Colors.white,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getWeatherIcon(),
                        color: _getWeatherColor(),
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${weatherData.temperature.toStringAsFixed(1)}°',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          //fontFamily: 'DMMono',
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Right detailed information
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weatherData.weatherDescription,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          //fontFamily: 'DMMono',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildWeatherDetailRow(
                        icon: Icons.water_drop_outlined,
                        label: 'Humidity',
                        value: '${weatherData.humidity}%'
                      ),
                      const SizedBox(height: 4),
                      _buildWeatherDetailRow(
                        icon: Icons.air,
                        label: 'Wind',
                        value: '${weatherData.windSpeed} m/s'
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Generate music button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: PixelTheme.text, width: 1),
              ),
              color: PixelTheme.primary.withOpacity(0.1),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  String tempFlagId = 'flag_temp_${DateTime.now().millisecondsSinceEpoch}';
                  
                  _flagInfoMap[tempFlagId] = FlagInfo(
                    position: LatLng(weatherData.location?.latitude ?? 0, 
                                   weatherData.location?.longitude ?? 0),
                    weatherData: weatherData,
                    createdAt: DateTime.now(),
                  );
                  
                  _showGenerateMusicDialog(weatherData, tempFlagId);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.music_note,
                        size: 16,
                        color: PixelTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Generate music based on weather',
                        style: TextStyle(
                          fontSize: 14,
                          //fontFamily: 'DMMono',
                          color: PixelTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Weather detail row
  Widget _buildWeatherDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: PixelTheme.textLight,
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            //fontFamily: 'DMMono',
            color: PixelTheme.textLight,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            //fontFamily: 'DMMono',
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _toggleFlagPlacementMode() {
    print('Switching to flag placement mode, current state: $_isPlacingFlag');
    
    setState(() {
      _isPlacingFlag = !_isPlacingFlag;
    });
    
    print('After switching: $_isPlacingFlag');
    
    if (_isPlacingFlag) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Click a location on the map to place a flag'),
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).clearSnackBars();
    }
  }

  void _showWeatherCard(WeatherData weatherData) {
    setState(() {
      _weatherData = weatherData;
      
      if (_selectedLocation == null || 
          (_selectedLocation!.latitude != weatherData.location?.latitude || 
           _selectedLocation!.longitude != weatherData.location?.longitude)) {
        
        _selectedLocation = LatLng(
          weatherData.location?.latitude ?? 0,
          weatherData.location?.longitude ?? 0
        );
        
        _mapController.move(_selectedLocation!, _mapController.zoom);
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Displaying weather information for ${weatherData.cityName}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMusicDetails(String title) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.album, color: Colors.purple),
                SizedBox(width: 10),
                Text('Music generated based on weather'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 10),
                Text(
                  'Created at ${DateTime.now().toString().substring(0, 16)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Playing music: $title')),
                    );
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share feature coming soon')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFlagInfoWindow(String flagId, LatLng position) {
    print('Trying to show flag info window: $flagId');
    
    final flagInfo = _flagInfoMap[flagId];
    if (flagInfo == null) {
      print('Error: Flag info not found for ID: $flagId');
      return;
    }
    
    print('Successfully found flag info, preparing to show window');
    
    _mapController.move(position, _mapController.zoom);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8, // Limit the maximum height
        ),
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView( // Make the entire content scrollable
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Flag Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              
              // Location Information
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Created Time
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Created at: ${flagInfo.createdAt.toString().substring(0, 16)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Weather Information
              if (flagInfo.weatherData != null) ...[
                const Divider(),
                const Text(
                  'Weather Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _getWeatherIconForData(flagInfo.weatherData!),
                      color: _getWeatherColorForData(flagInfo.weatherData!),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${flagInfo.weatherData!.cityName}: ${flagInfo.weatherData!.temperature.toStringAsFixed(1)}°C, ${flagInfo.weatherData!.weatherDescription}',
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Humidity: ${flagInfo.weatherData!.humidity}%, Wind Speed: ${flagInfo.weatherData!.windSpeed} m/s',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
              
              // Music Information (if available)
              if (flagInfo.musicTitle != null) ...[
                const Divider(),
                Row(
                  children: [
                    const Icon(Icons.music_note, size: 16, color: Colors.purple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Music Generated: ${flagInfo.musicTitle}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Button area
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, // Make the buttons stretch to fill the available width
                children: [
                  // Generate music button
                  if (flagInfo.musicTitle == null && flagInfo.weatherData != null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.music_note),
                      label: const Text('Generate Music'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showGenerateMusicDialog(flagInfo.weatherData!, flagId);
                      },
                    ),
                  
                  // Play music button
                  if (flagInfo.musicTitle != null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play Music'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        
                        // Find the corresponding music item in the music library
                        final libraryManager = MusicLibraryManager();
                        final musicItems = libraryManager.allMusic.where(
                          (item) => item.title == flagInfo.musicTitle
                        ).toList();
                        
                        if (musicItems.isNotEmpty) {
                          // Use the actual existing music item
                          final playerManager = AudioPlayerManager();
                          playerManager.playMusic(musicItems[0].id, musicItems[0].audioUrl);
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Playing music: ${flagInfo.musicTitle}')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to find music: ${flagInfo.musicTitle}')),
                          );
                        }
                      },
                    ),
                  
                  const SizedBox(height: 8), // Button spacing
                  
                  // Delete marker button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete Marker'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteFlag(flagId);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getWeatherIconForData(WeatherData weatherData) {
    final condition = weatherData.weatherMain.toLowerCase();
    
    if (condition.contains('clear')) {
      return Icons.wb_sunny;
    } else if (condition.contains('cloud')) {
      return Icons.cloud;
    } else if (condition.contains('rain')) {
      return Icons.water_drop;
    } else if (condition.contains('snow')) {
      return Icons.ac_unit;
    } else if (condition.contains('fog') || condition.contains('mist')) {
      return Icons.cloud;
    } else if (condition.contains('wind') || condition.contains('storm')) {
      return Icons.air;
    } else {
      return Icons.cloud;
    }
  }

  Color _getWeatherColorForData(WeatherData weatherData) {
    final condition = weatherData.weatherMain.toLowerCase();
    
    if (condition.contains('clear')) {
      return Colors.orange;
    } else if (condition.contains('cloud')) {
      return Colors.blueGrey;
    } else if (condition.contains('rain')) {
      return Colors.blue;
    } else if (condition.contains('snow')) {
      return Colors.lightBlue;
    } else if (condition.contains('fog') || condition.contains('mist')) {
      return Colors.grey;
    } else if (condition.contains('wind') || condition.contains('storm')) {
      return Colors.deepPurple;
    } else {
      return Colors.grey;
    }
  }

  void _deleteFlag(String flagId) {
    print('Starting to delete marker: $flagId');
    
    setState(() {
      // 1. Save all marker information to be retained (except the one to be deleted)
      Map<String, FlagInfo> flagsToKeep = {};
      _flagInfoMap.forEach((id, info) {
        if (id != flagId) {
          flagsToKeep[id] = info;
        }
      });
      
      // 2. Clear all existing markers
      _mapService.clearMarkers();
      _flagInfoMap.clear();
      
      // 3. Remove from service status
      _mapService.removeFlagInfo(flagId);
      
      // 4. Add all markers to be retained
      flagsToKeep.forEach((id, info) {
        _flagInfoMap[id] = info;
        
        // Add markers to the map again
        _mapService.addMarker(
          id: id,
          position: info.position,
          title: '',
          icon: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              Icons.flag,
              color: Colors.red,
              size: 15.0, //Use fixed size instead of dynamic calculation
            ),
          ),
          onTap: () {
            _showFlagInfoWindow(id, info.position);
          },
          onLongPress: () {
            _showDeleteMarkerDialog(id);
          },
        );
      });
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marker deleted')),
    );
  }

  void _loadPersistentFlags() {
    final persistentFlags = _mapService.persistentFlagMap;
    
    // First clear all markers
    _mapService.clearMarkers();
    
    setState(() {
      _flagInfoMap.clear(); // Clear local state
      _flagInfoMap.addAll(persistentFlags); // Add persistent state
      
      // Re-create markers for each flag, using fixed size
      _flagInfoMap.forEach((id, info) {
        _mapService.addMarker(
          id: id,
          position: info.position,
          title: '',
          icon: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              Icons.flag,
              color: Colors.red,
              size: 15.0, //Use fixed size instead of dynamic calculation
            ),
          ),
          onTap: () {
            _showFlagInfoWindow(id, info.position);
          },
          onLongPress: () {
            _showDeleteMarkerDialog(id);
          },
        );
      });
    });
  }

  void _updateMapState() {
    try {
      _mapCenterPosition = _mapController.center;
      _mapZoomLevel = _mapController.zoom;
    } catch (e) {
      print("Failed to get map state: $e");
      _mapCenterPosition = _mapService.getDefaultLocation();
      _mapZoomLevel = COUNTRY_ZOOM_LEVEL;
    }
  }

  void _safelyMoveMap(LatLng position, double zoom) {
    if (_mapController != null) {
      try {
        _mapController.move(position, zoom);
        _mapCenterPosition = position;
        _mapZoomLevel = zoom;
      } catch (e) {
        print('Failed to move map: $e');
        _mapCenterPosition = position;
        _mapZoomLevel = zoom;
      }
    }
  }

  void _handleMapMoved(MapPosition position, bool hasGesture) {
    setState(() {
      _currentCenter = position.center!;
      _currentZoom = position.zoom!;
      
      // Update the last map state
      _lastMapCenter = position.center!;
      _lastMapZoom = position.zoom!;
    });
  }

  bool isMapControllerReady() {
    if (_mapController == null) return false;
    
    try {
      // Try reading a property or calling a method
      var center = _mapController.center;
      return true; // If no exception is thrown, the controller is ready
    } catch (e) {
      return false; // If an exception is caught, the controller is not ready
    }
  }

  // Add a method to save the current map state
  void _saveCurrentMapState() {
    try {
      _lastMapCenter = _mapController.center;
      _lastMapZoom = _mapController.zoom;
    } catch (e) {
      print('Failed to save map state: $e');
    }
  }

  // Handle music deletion callback
  void _handleMusicDeleted(String musicId) {
    if (!mounted) {
      print('HomeScreen has been destroyed, ignoring music deletion notification');
      return;
    }
    
    print('HomeScreen received music deletion notification, musicId: $musicId');
    
    // Get music library
    final libraryManager = MusicLibraryManager();
    
    // Find all flags associated with the deleted music
    List<String> flagsToDelete = [];
    
    _flagInfoMap.forEach((flagId, flagInfo) {
      print('Checking flag $flagId, musicTitle: ${flagInfo.musicTitle}');
      
      if (flagInfo.musicTitle != null) {
        // Check directly if it is associated with the deleted music
        final allMusic = libraryManager.allMusic;
        
        // Since we do not directly store the mapping between music ID and flag, we need to find it through the title
        bool musicFound = false;
        for (var music in allMusic) {
          if (music.title == flagInfo.musicTitle) {
            musicFound = true;
            break;
          }
        }
        
        // If no matching music is found, delete this flag
        if (!musicFound) {
          print('Flag $flagId associated with music "${flagInfo.musicTitle}" has been deleted, preparing to delete flag');
          flagsToDelete.add(flagId);
        }
      }
    });
    
    // Delete all found flags
    if (flagsToDelete.isNotEmpty) {
      print('Need to delete ${flagsToDelete.length} flags');
      setState(() {
        for (String flagId in flagsToDelete) {
          _deleteFlag(flagId);
          print('Deleted flag $flagId');
        }
      });
    } else {
      print('No flags to delete found');
    }
  }

  // Add search method
  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _searchResults = [];
      });
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) return;
    
    setState(() {
      _isSearching = true;
    });
    
    try {
      final results = await _geocodingService.searchPlaces(query);
      
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      print('Error searching for location: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _selectSearchResult(GeocodingResult result) {
    // Move map to selected location
    _safelyMoveMap(result.latLng, 13.0); // Use appropriate zoom level
    
    // Clear search results
    setState(() {
      _searchResults = [];
      _searchController.clear();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Moved to: ${result.name}')),
    );
  }

  Widget _buildPixelMapButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            border: Border.all(color: color, width: 2),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: Icon(
                  icon,
                  size: 20,
                  color: color,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            //fontFamily: 'DMMono',
            color: PixelTheme.text,
          ),
        ),
      ],
    );
  }

  void _showGenerateMusicDialog(WeatherData weatherData, String flagId) {
    // Reset selection state when dialog opens
    _selectedVibe = null;
    _selectedGenre = null;
    MusicScene? _selectedScene = null;   
    
    // Use StatefulBuilder to allow setState inside the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Get screen size
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: screenWidth * 0.9,
                constraints: BoxConstraints(
                  maxHeight: screenHeight * 0.8,   
                ),
                decoration: BoxDecoration(
                  color: PixelTheme.surface,
                  border: Border.all(color: PixelTheme.text, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(6, 6),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: PixelTheme.text, width: 2),
                        ),
                        color: PixelTheme.secondary.withOpacity(0.3),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Generate music',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                border: Border.all(color: PixelTheme.text, width: 1),
                                color: PixelTheme.error,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content area
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Location and weather information
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: PixelTheme.text, width: 1),
                                  color: PixelTheme.background,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _getWeatherIconForData(weatherData),
                                      color: _getWeatherColorForData(weatherData),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            weatherData.cityName,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${weatherData.weatherDescription}, ${weatherData.temperature.toStringAsFixed(1)}°C',
                                            style: TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Scene selection
                              Text(
                                'Select Scene:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: PixelTheme.text.withOpacity(0.3), width: 1),
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: MusicScene.values.map((scene) {
                                    return _buildPixelChoiceChip(
                                      label: scene.name,
                                      selected: _selectedScene == scene,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            _selectedScene = scene;
                                            final prefs = scene.preferences;
                                            _selectedVibe = prefs['vibe'];
                                            _selectedGenre = prefs['genre'];
                                          } else {
                                            _selectedScene = null;
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Vibe selection
                              Text(
                                'Select Vibe:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: PixelTheme.text.withOpacity(0.3), width: 1),
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: MusicVibe.values.map((vibe) {
                                    return _buildPixelChoiceChip(
                                      label: vibe.name,
                                      selected: _selectedVibe == vibe,
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedVibe = selected ? vibe : null;
                                          // When manually selecting vibe, clear scene selection
                                          if (_selectedScene != null) {
                                            _selectedScene = null;
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Genre selection
                              Text(
                                'Select Style:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: PixelTheme.text.withOpacity(0.3), width: 1),
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: MusicGenre.values.map((genre) {
                                    return _buildPixelChoiceChip(
                                      label: genre.name,
                                      selected: _selectedGenre == genre,
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedGenre = selected ? genre : null;
                                          // When manually selecting genre, clear scene selection
                                          if (_selectedScene != null) {
                                            _selectedScene = null;
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Bottom button area
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: PixelTheme.text, width: 1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: PixelTheme.text, width: 2),
                            ),
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                backgroundColor: PixelTheme.surface,
                                foregroundColor: PixelTheme.text,
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: PixelTheme.text, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(2, 2),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                // Pass _selectedScene?.name as additional information
                                _generateMusicAndUpdateFlag(
                                  weatherData, 
                                  flagId, 
                                  null, // Keep original parameter structure
                                  _selectedScene?.name // Optional: pass scene name
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                backgroundColor: PixelTheme.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                'Generate Music',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  // Pixel style choice chip
  Widget _buildPixelChoiceChip({
    required String label,
    required bool selected,
    required Function(bool) onSelected,
  }) {
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? PixelTheme.primary : PixelTheme.surface,
          border: Border.all(
            color: selected ? PixelTheme.primary : PixelTheme.text,
            width: 1,
          ),
          boxShadow: selected ? [] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : PixelTheme.text,
            fontSize: 12,
            //fontFamily: 'DMMono',
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _generateMusicAndUpdateFlag(WeatherData weatherData, String flagId, [String? customPrompt, String? sceneName]) async {
    // Show pixel-style loading dialog
    showPixelLoadingDialog(context, 'Generating music...');
    
    try {
      String prompt;
      
      // If a custom prompt is provided, use it, otherwise use DeepSeek to generate
      if (customPrompt != null && customPrompt.isNotEmpty) {
        prompt = customPrompt;
      } else {
        // Use DeepSeek to generate an optimized prompt
        try {
          prompt = await _deepSeekApiService.generateMusicPrompt(
            weatherDescription: weatherData.weatherDescription,
            temperature: weatherData.temperature,
            humidity: weatherData.humidity,
            windSpeed: weatherData.windSpeed,
            cityName: weatherData.cityName,
            vibeName: _selectedVibe?.name,
            genreName: _selectedGenre?.name,
          );
        } catch (e) {
          print('Failed to generate prompt with DeepSeek: $e');
          // Fallback to weather service prompt
          prompt = weatherData.buildMusicPrompt();
          
          // Add music preferences
          if (_selectedVibe != null || _selectedGenre != null) {
            prompt += '\n\nMusic preferences: ';
            if (_selectedVibe != null) {
              prompt += '${_selectedVibe!.name} atmosphere, ';
            }
            if (_selectedGenre != null) {
              prompt += '${_selectedGenre!.name} style.';
            }
          }
        }
      }
      
      // Build music title, including preferences
      String musicTitle = '${weatherData.cityName} ${weatherData.weatherDescription} music';
      if (_selectedVibe != null || _selectedGenre != null) {
        musicTitle += ' - ';
        if (_selectedVibe != null) {
          musicTitle += '${_selectedVibe!.name} ';
        }
        if (_selectedGenre != null) {
          musicTitle += '${_selectedGenre!.name}';
        }
      }
      
      // Use StabilityAudioService to generate music
      final StabilityAudioService audioService = StabilityAudioService(
        apiKey: AppConfig.stabilityApiKey
      );
      
      final result = await audioService.generateMusic(
        prompt,
        outputFormat: "mp3",
        durationSeconds: 60, // Update to 60 seconds
        steps: 30,
        saveLocally: true,
      );
      
      // Get audio URL from result
      final audioUrl = result['audio_url'];
      // Ensure audioUrl starts with file://
      final String finalAudioUrl = audioUrl.startsWith('file://') 
          ? audioUrl 
          : 'file://$audioUrl';
      
      // Create a unique music ID
      final musicId = 'music_${DateTime.now().millisecondsSinceEpoch}';
      
      // Create MusicItem object
      final musicItem = MusicItem(
        id: musicId,
        title: musicTitle,
        prompt: prompt,
        audioUrl: finalAudioUrl,
        status: 'complete',
        createdAt: DateTime.now(),
      );
      
      // Add to MusicLibraryManager
      final MusicLibraryManager libraryManager = MusicLibraryManager();
      await libraryManager.addMusic(musicItem);
      
      if (mounted) {
        // Update local state
        if (_flagInfoMap.containsKey(flagId)) {
          setState(() {
            final flagInfo = _flagInfoMap[flagId]!;
            final updatedInfo = FlagInfo(
              position: flagInfo.position,
              weatherData: flagInfo.weatherData,
              createdAt: flagInfo.createdAt,
              musicTitle: musicTitle,
            );
            
            _flagInfoMap[flagId] = updatedInfo;
            
            // Add marker after music generation
            _mapService.addMarker(
              id: flagId,
              position: flagInfo.position,
              title: '',
              icon: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Icon(
                  Icons.flag,
                  color: Colors.red,
                  size: 15.0, 
                ),
              ),
              onTap: () {
                print('Flag clicked: $flagId');
                _showFlagInfoWindow(flagId, flagInfo.position);
              },
              onLongPress: () {
                _showDeleteMarkerDialog(flagId);
              },
            );
            
            // Save to persistent service
            _mapService.saveFlagInfo(flagId, updatedInfo);
          });
        }
        
        // Safely close loading dialog
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(); // Close loading dialog
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Music generated successfully: $musicTitle')),
        );
      }
      
    } catch (e) {
      print('Error generating music: $e');
      
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Music generation failed: $e')),
        );
      }
    }
  }

  Widget _buildPixelZoomButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: PixelTheme.surface,
        border: Border.all(color: PixelTheme.text, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              size: 16,
              color: PixelTheme.text,
            ),
          ),
        ),
      ),
    );
  }

  // Show pixel-style loading dialog
  void showPixelLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PixelTheme.surface,
              border: Border.all(color: PixelTheme.text, width: 2),
              boxShadow: PixelTheme.cardShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(PixelTheme.primary),
                ),
                const SizedBox(height: 24),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    //fontFamily: 'DMMono',
                    color: PixelTheme.text,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // Modify _showLocationPermissionDialog method
  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PixelTheme.surface,
            border: Border.all(color: PixelTheme.text, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Location Access',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: PixelTheme.text,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'EnviroMelody needs access to your location to create music based on your surroundings. Allow access to location information?',
                style: TextStyle(
                  color: PixelTheme.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: PixelTheme.text, width: 2),
                    ),
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Use default location
                        _safelyMoveMap(_mapService.getDefaultLocation(), COUNTRY_ZOOM_LEVEL);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: PixelTheme.surface,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Text(
                        'Not now',
                        style: TextStyle(
                          color: PixelTheme.textLight,
                        ),
                      ),
                    ),
                  ),
                  
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: PixelTheme.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          offset: const Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        // Request location permission
                        final permissionStatus = await _mapService.requestLocationPermissionDetailed();
  
                        // Save permission status
                        await _mapService.savePermissionStatus(permissionStatus);
                        
                        // Handle permission status
                        if (permissionStatus == PermissionStatus.granted || 
                            permissionStatus == PermissionStatus.grantedLimited) {
                          // Granted permission, get location
                          _initLocationService();
                        } else {
                          // Show prompt
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Location access denied, using default location.'))
                              );
                            }
                          });
                          
                          // Use default location
                          _safelyMoveMap(_mapService.getDefaultLocation(), COUNTRY_ZOOM_LEVEL);
                        }
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: PixelTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text(
                        'Allow',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _checkMapControllerReady() {
    // If the map is ready, return immediately
    if (_isMapReady) return;
    
    // Check if the map controller is ready
    if (isMapControllerReady()) {
      print("DEBUG: Map controller is ready");
      setState(() {
        _isMapReady = true;
        _mapState.isReady = true;
      });
      
      if (_isFirstLoad && !_hasInitializedOnce) {
        _goToCurrentLocation();
        _isFirstLoad = false;
        _hasInitializedOnce = true;
      }
    } else {
      // If not ready, delay checking
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          _checkMapControllerReady();
        }
      });
    }
  }
} 