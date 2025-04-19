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
import '../services/deepseek_api_service.dart';  // 添加这一行
import '../services/event_bus.dart';

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
  
  // 在 _HomeScreenState 类中添加 DeepSeekApiService 实例
  final DeepSeekApiService _deepSeekApiService = DeepSeekApiService(
    apiKey: AppConfig.deepSeekApiKey,
  );
  
  // 在 _HomeScreenState 类中添加 StreamSubscription
  StreamSubscription? _musicDeletedSubscription;
  
  @override
  void initState() {
    super.initState();
    // Add page lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize map state
    _mapState = MapState(
      center: _mapService.getDefaultLocation(),
      zoom: COUNTRY_ZOOM_LEVEL,
    );
    
    _initMapService();
    
    // Asynchronous initialization
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
    
    // 添加音乐删除回调
    final libraryManager = MusicLibraryManager();
    libraryManager.addMusicDeletedCallback(_handleMusicDeleted);
    print('HomeScreen 已注册音乐删除回调');
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
      // 当应用从后台恢复时
      _selectedVibe = null;
      _selectedGenre = null;
      
      if (_hasInitializedOnce) {
        // 如果之前已经初始化过，只重新创建控制器但不移动到当前位置
        _mapController = MapController();
        _initMapService();
        
        // 在下一帧绘制后，恢复地图位置和缩放级别
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isMapReady && mounted) {
            try {
              if (_mapController != null) {
                // 添加安全检查，确保地图控制器已准备好
                if (isMapControllerReady()) {
                  _mapController.move(_lastMapCenter, _lastMapZoom);
                  // 重新加载所有标记
                  _loadPersistentFlags();
                  print('成功恢复地图位置：中心=${_lastMapCenter}，缩放=${_lastMapZoom}');
                } else {
                  print('地图控制器尚未准备好，无法移动地图');
                  // 设置一个延迟，稍后再尝试
                  Future.delayed(Duration(milliseconds: 500), () {
                    if (mounted && isMapControllerReady()) {
                      _mapController.move(_lastMapCenter, _lastMapZoom);
                      print('延迟后成功恢复地图位置');
                    }
                  });
                }
              }
            } catch (e) {
              print('恢复地图位置时出错: $e');
            }
          }
        });
      }
    } else if (state == AppLifecycleState.paused) {
      // 应用进入后台时，保存当前地图状态
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
    // 添加这行代码以确保所有异步操作都被取消
    print('HomeScreen 销毁：取消所有订阅和异步操作');
    
    // 移除音乐删除回调
    final libraryManager = MusicLibraryManager();
    libraryManager.removeMusicDeletedCallback(_handleMusicDeleted);
    
    // 保存当前状态
    try {
      _lastMapCenter = _mapController.center;
      _lastMapZoom = _mapController.zoom;
      print('保存地图状态：中心=${_lastMapCenter}，缩放=${_lastMapZoom}');
    } catch (e) {
      print('保存地图状态失败: $e');
    }
    
    // 清理地图组件
    _mapService.clearMarkers();
    WidgetsBinding.instance.removeObserver(this);
    _mapService.dispose();
    
    super.dispose();
  }
  
  // When the map is ready
  void _onMapReady() {
    print("DEBUG: The map is ready");
    setState(() {
      _mapState.isReady = true;
      _isMapReady = true;
    });
    
    // Only move to the current location when it is the first load and _hasInitializedOnce is false
    if (_isFirstLoad && !_hasInitializedOnce) {
      _goToCurrentLocation();
      _isFirstLoad = false;
      _hasInitializedOnce = true;
    } else {
      // If it is not the first load, restore to the last saved position
      try {
        _mapController.move(_lastMapCenter, _lastMapZoom);
      } catch (e) {
        print('Error restoring map position: $e');
      }
    }
  }
  
  // Go to current location
  Future<void> _goToCurrentLocation() async {
    if (!_isMapReady || _mapController == null) return;
    
    setState(() {
      _isLoadingLocation = true;
    });
    
    try {
      await _mapService.moveToCurrentLocation();
    } catch (e) {
      print('Error moving to current location: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot access your location')),
        );
      }
    } finally {
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
    // This method needs to be modified to support FlutterMapService
    // If FlutterMapService does not support updating the event of existing markers
    // You can consider removing and adding the marker again
    
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
    
    // 生成唯一标识符，但不立即添加标记
    String flagId = 'flag_${DateTime.now().millisecondsSinceEpoch}';
    
    // 移动到选定位置
    _safelyMoveMap(location, _mapController.zoom);
    
    // 获取天气数据，但不保存到持久化存储中
    _getWeatherForLocation(location, flagId, false); // 添加参数表示不添加标记
    
    // 刷新UI以显示天气数据，但不显示标记
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
            child: const Text('取消'),
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
      appBar: AppBar(
        title: const Text('Music Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _goToCurrentLocation,
            tooltip: 'Refresh map',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
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
          
          if (_isLoadingWeather)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('Getting weather data...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          
          if (_weatherData != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildWeatherCard(_weatherData!),
            ),
          
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildZoomButton(
                  icon: Icons.add,
                  onPressed: () {
                    double currentZoom = _mapZoomLevel ?? COUNTRY_ZOOM_LEVEL;
                    double newZoom = currentZoom + 1;
                    if (newZoom > 17) newZoom = 17;
                    
                    _safelyMoveMap(_mapCenterPosition ?? _mapService.getDefaultLocation(), newZoom);
                  },
                ),
                const SizedBox(height: 8),
                _buildZoomButton(
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
          
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMapButton(
                      icon: _isPlacingFlag ? Icons.cancel : Icons.flag,
                      label: _isPlacingFlag ? 'Cancel placement' : 'Place flag',
                      onTap: _toggleFlagPlacementMode,
                    ),
                    _buildMapButton(
                      icon: Icons.my_location,
                      label: 'My Location',
                      onTap: _goToCurrentLocation,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          if (_isPlacingFlag)
            Positioned(
              top: 70,
              left: 0,
              right: 0,
              child: Container(
                alignment: Alignment.center,
                color: Colors.red.withOpacity(0.7),
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Click map to place flag',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildWeatherCard(WeatherData weatherData) {
    final location = weatherData.location?.getFormattedLocation() ?? weatherData.cityName;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _weatherData = null;
                      for (var id in _weatherMarkerIds) {
                        _mapService.removeMarker(id);
                      }
                      _weatherMarkerIds.clear();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${weatherData.temperature.toStringAsFixed(1)}°',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Image.network(
                            weatherData.getIconUrl(),
                            width: 40,
                            height: 40,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                _getWeatherIcon(),
                                size: 40,
                                color: _getWeatherColor(),
                              );
                            },
                          ),
                        ],
                      ),
                      Text(
                        weatherData.weatherDescription,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWeatherDetailRow(
                        Icons.thermostat_outlined, 
                        'Feels like', 
                        '${weatherData.feelsLike.toStringAsFixed(1)}°C'
                      ),
                      const SizedBox(height: 4),
                      _buildWeatherDetailRow(
                        Icons.water_drop_outlined, 
                        'Humidity', 
                        '${weatherData.humidity}%'
                      ),
                      const SizedBox(height: 4),
                      _buildWeatherDetailRow(
                        Icons.air, 
                        'Wind speed', 
                        '${weatherData.windSpeed} m/s'
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.music_note),
                label: const Text('Generate music based on weather'),
                onPressed: () {
                  // 创建一个临时标记ID
                  String tempFlagId = 'flag_temp_${DateTime.now().millisecondsSinceEpoch}';
                  
                  // 保存天气信息但不添加标记
                  _flagInfoMap[tempFlagId] = FlagInfo(
                    position: LatLng(weatherData.location?.latitude ?? 0, 
                                    weatherData.location?.longitude ?? 0),
                    weatherData: weatherData,
                    createdAt: DateTime.now(),
                  );
                  
                  _showGenerateMusicDialog(weatherData, tempFlagId);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWeatherDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  // 替换原有的 _showGenerateMusicDialog 方法
  void _showGenerateMusicDialog(WeatherData weatherData, String flagId) {
    // Reset selection state each time dialog is opened
    _selectedVibe = null;
    _selectedGenre = null;
    
    // Use StatefulBuilder to allow setState inside dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Get screen dimensions
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: screenWidth * 0.85,
                height: screenHeight * 0.5,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      'Generate music for ${weatherData.cityName}\'s ${weatherData.weatherDescription} weather',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Scrollable content area
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Music preference selector
                            MusicPreferenceSelector(
                              initialVibe: _selectedVibe,
                              initialGenre: _selectedGenre,
                              onPreferencesChanged: (vibe, genre) {
                                setState(() {
                                  _selectedVibe = vibe;
                                  _selectedGenre = genre;
                                });
                              },
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Weather information card
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _getWeatherIconForData(weatherData),
                                        color: _getWeatherColorForData(weatherData),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Weather: ${weatherData.weatherDescription}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Temperature: ${weatherData.temperature.toStringAsFixed(1)}°C'),
                                  Text('Humidity: ${weatherData.humidity}%'),
                                  Text('Wind Speed: ${weatherData.windSpeed} m/s'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Button area
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            
                            // Generate music with AI-optimized prompt
                            _generateMusicAndUpdateFlag(weatherData, flagId);
                          },
                          child: const Text('Generate Music'),
                        ),
                      ],
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
  
  // 修改 _generateMusicAndUpdateFlag 方法
  Future<void> _generateMusicAndUpdateFlag(WeatherData weatherData, String flagId, [String? customPrompt]) async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Generating music...'),
            ),
          ],
        ),
      ),
    );
    
    try {
      String prompt;
      
      // 如果提供了自定义提示，则使用它，否则用DeepSeek生成
      if (customPrompt != null && customPrompt.isNotEmpty) {
        prompt = customPrompt;
      } else {
        // 使用DeepSeek生成优化的提示
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
          // 回退到天气服务提示
          prompt = weatherData.buildMusicPrompt();
          
          // 添加音乐偏好
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
      
      // 构建音乐标题，包括偏好
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
      
      // 使用StabilityAudioService生成音乐
      final StabilityAudioService audioService = StabilityAudioService(
        apiKey: AppConfig.stabilityApiKey
      );
      
      final result = await audioService.generateMusic(
        prompt,
        outputFormat: "mp3",
        durationSeconds: 20,
        steps: 30,
        saveLocally: true,
      );
      
      // 从结果中获取音频URL
      final audioUrl = result['audio_url'];
      // 确保audioUrl以file://开头
      final String finalAudioUrl = audioUrl.startsWith('file://') 
          ? audioUrl 
          : 'file://$audioUrl';
      
      // 创建唯一音乐ID
      final musicId = 'music_${DateTime.now().millisecondsSinceEpoch}';
      
      // 创建MusicItem对象
      final musicItem = MusicItem(
        id: musicId,
        title: musicTitle,
        prompt: prompt,
        audioUrl: finalAudioUrl,
        status: 'complete',
        createdAt: DateTime.now(),
      );
      
      // 添加到MusicLibraryManager
      final MusicLibraryManager libraryManager = MusicLibraryManager();
      await libraryManager.addMusic(musicItem);
      
      if (mounted) {
        // 更新本地状态
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
            
            // 音乐生成成功后，才添加标记到地图上
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
            
            // 保存到持久化服务
            _mapService.saveFlagInfo(flagId, updatedInfo);
          });
        }
        
        // 安全关闭对话框
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(); // 关闭加载对话框
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully generated music: $musicTitle')),
        );
      }
      
    } catch (e) {
      print('Error generating music: $e');
      
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop(); // 关闭加载对话框
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate music: $e')),
        );
      }
    }
  }
  
  Widget _buildMapButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
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
  
  Widget _buildZoomButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            spreadRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        padding: EdgeInsets.zero,
        iconSize: 20,
        onPressed: onPressed,
        tooltip: icon == Icons.add ? 'Zoom in' : 'Zoom out',
      ),
    );
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

  // 处理音乐删除的回调
  void _handleMusicDeleted(String musicId) {
    if (!mounted) {
      print('HomeScreen 已销毁，忽略音乐删除通知');
      return;
    }
    
    print('HomeScreen 收到音乐删除通知，musicId: $musicId');
    
    // 获取音乐库
    final libraryManager = MusicLibraryManager();
    
    // 查找所有与该音乐关联的标记
    List<String> flagsToDelete = [];
    
    _flagInfoMap.forEach((flagId, flagInfo) {
      print('检查标记 $flagId，musicTitle: ${flagInfo.musicTitle}');
      
      if (flagInfo.musicTitle != null) {
        // 直接检查是否与被删除的音乐ID关联
        final allMusic = libraryManager.allMusic;
        
        // 由于我们没有直接存储音乐ID和标记的映射关系，我们需要通过标题来查找
        bool musicFound = false;
        for (var music in allMusic) {
          if (music.title == flagInfo.musicTitle) {
            musicFound = true;
            break;
          }
        }
        
        // 如果没有找到匹配的音乐，则删除这个标记
        if (!musicFound) {
          print('标记 $flagId 关联的音乐 "${flagInfo.musicTitle}" 已被删除，准备删除标记');
          flagsToDelete.add(flagId);
        }
      }
    });
    
    // 删除找到的所有标记
    if (flagsToDelete.isNotEmpty) {
      print('需要删除 ${flagsToDelete.length} 个标记');
      setState(() {
        for (String flagId in flagsToDelete) {
          _deleteFlag(flagId);
          print('已删除标记 $flagId');
        }
      });
    } else {
      print('没有找到需要删除的标记');
    }
  }
} 