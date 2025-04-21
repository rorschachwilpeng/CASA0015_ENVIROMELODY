import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../screens/home_screen.dart'; //Import FlagInfo class
import '../services/music_library_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Move to class external 
typedef ZoomChangedCallback = void Function(double zoom);

// Flutter Map Map Service
class FlutterMapService extends ChangeNotifier {
  // Singleton Pattern
  static final FlutterMapService _instance = FlutterMapService._internal();
  factory FlutterMapService() => _instance;
  FlutterMapService._internal();
  
  // Default location: Beijing (latitude 39.9042, longitude 116.4074)
  final LatLng _defaultLocation = const LatLng(39.9042, 116.4074);
  
  // Location Service
  final Location _locationService = Location();
  
  // Current Location
  LocationData? _currentLocation;
  LatLng? get currentLatLng => _currentLocation != null 
      ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!) 
      : _defaultLocation;
  
  // Map Controller
  MapController? _mapController;
  
  // Marker Collection
  final List<Marker> _markers = [];
  List<Marker> get markers => _markers;
  
  // Add constant at the top of the class
  static const double COUNTRY_ZOOM_LEVEL = 6.0; // Country zoom level
  
  // Add zoom scale related properties
  double _currentZoom = COUNTRY_ZOOM_LEVEL;
  double get currentZoom => _currentZoom;
  
  // Marker size reference value
  static const double BASE_ZOOM = 10.0; // Base zoom level
  static const double BASE_MARKER_SIZE = 30.0; // Base marker size
  
  // Zoom change callback
  ZoomChangedCallback? _onZoomChanged;
  
  // Set zoom change callback
  void setZoomChangedCallback(ZoomChangedCallback callback) {
    _onZoomChanged = callback;
  }
  
  // Calculate marker size based on zoom level
  double calculateMarkerSize(double baseSize) {
    // Zoom factor: the larger the zoom level, the smaller the marker; the smaller the zoom level, the larger the marker
    double zoomFactor = math.pow(0.85, _currentZoom - BASE_ZOOM).toDouble();
    // Limit minimum/maximum size
    return math.max(15.0, math.min(baseSize * zoomFactor, 50.0));
  }
  
  // Update current zoom level
  void updateZoom(double zoom) {
    _currentZoom = zoom;
    // Notify listener of zoom change
    if (_onZoomChanged != null) {
      _onZoomChanged!(_currentZoom);
    }
  }
  
  // Add a property to control whether to automatically move to the current location
  bool _autoMoveToCurrentLocation = false;
  
  // Modify initMap method, add a parameter to control whether to automatically move
  void initMap(MapController controller, {bool autoMoveToCurrentLocation = false}) {
    _mapController = controller;
    _autoMoveToCurrentLocation = autoMoveToCurrentLocation;
    _checkLocationPermission();
  }
  
  // Check location permission
  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled;
    PermissionStatus permissionStatus;
    
    try {
      // 检查位置服务是否启用
      serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        print("DEBUG: Location service not enabled, requesting service");
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) {
          print("DEBUG: User denied enabling location service");
          return false;
        }
      }
      
      // 检查位置权限
      permissionStatus = await _locationService.hasPermission();
      print("DEBUG: Current permission status: $permissionStatus");
      
      if (permissionStatus == PermissionStatus.denied) {
        print("DEBUG: Permission denied, requesting permission");
        permissionStatus = await _locationService.requestPermission();
        print("DEBUG: After request, permission status: $permissionStatus");
        
        if (permissionStatus != PermissionStatus.granted && 
            permissionStatus != PermissionStatus.grantedLimited) {
          print("DEBUG: User denied location permission");
          return false;
        }
      }
      
      print("DEBUG: Location permission granted: $permissionStatus");
      return true;
    } catch (e) {
      print("DEBUG: Error checking location permission: $e");
      return false;
    }
  }
  
  // Add this method to detect whether the app is running on an emulator
  Future<bool> _isRunningOnEmulator() async {
    try {
      // This is a simple check, more complex detection might require platform-specific code
      final locationData = await _locationService.getLocation()
          .timeout(const Duration(seconds: 3), onTimeout: () {
        return LocationData.fromMap({
          'latitude': 0,
          'longitude': 0,
          'accuracy': 0,
          'altitude': 0,
          'speed': 0,
          'speed_accuracy': 0,
          'heading': 0,
          'time': DateTime.now().millisecondsSinceEpoch.toDouble(),
        });
      });
      
      // If the location is always 0,0 or cannot be quickly obtained, it's likely on an emulator
      if (locationData.latitude == 0 && locationData.longitude == 0) {
        return true;
      }
      
      return false;
    } catch (e) {
      print("DEBUG: Error detecting emulator: $e");
      return true; // If there's an error, assume on an emulator
    }
  }
  
  // Get current location
  Future<void> getCurrentLocation() async {
    try {
      print("DEBUG: Starting to get location...");
      
      // Check permission
      bool permissionGranted = await checkLocationPermission();
      if (!permissionGranted) {
        print("DEBUG: Location permission not granted");
        _useDefaultLocation();
        return;
      }
      
      print("DEBUG: Attempting to get location...");
      
      // Detect whether running on an emulator
      bool isEmulator = await _isRunningOnEmulator();
      
      if (isEmulator) {
        print("DEBUG: Detected possible emulator, using simulated location");
        // Use London coordinates as simulated location
        _currentLocation = LocationData.fromMap({
          'latitude': 51.5074,
          'longitude': -0.1278,
          'accuracy': 10.0,
          'altitude': 0.0,
          'speed': 0.0,
          'speed_accuracy': 0.0,
          'heading': 0.0,
          'time': DateTime.now().millisecondsSinceEpoch.toDouble(),
        });
        
        print("DEBUG: Simulated location set - London (51.5074, -0.1278)");
        return;
      }
      
      // Try to get real location on a device
      try {
        final locationData = await _locationService.getLocation()
            .timeout(const Duration(seconds: 10), onTimeout: () {
          print("DEBUG: Get location timeout");
          throw TimeoutException('Get location timeout');
        });
        
        if (locationData.latitude != null && locationData.longitude != null) {
          print("DEBUG: Location obtained - lat: ${locationData.latitude}, lng: ${locationData.longitude}");
          _currentLocation = locationData;
        } else {
          print("DEBUG: Invalid location data obtained");
          _useDefaultLocation();
        }
      } catch (e) {
        print("DEBUG: Error getting location: $e");
        _useDefaultLocation();
      }
    } catch (e) {
      print("DEBUG: getCurrentLocation overall error: $e");
      _useDefaultLocation();
    }
  }
  
  // Move to current location
  Future<void> moveToCurrentLocation() async {
    try {
      await getCurrentLocation();
      
      if (_mapController == null) {
        print("Map controller not initialized");
        return;
      }
      
      // Add stricter security checks
      try {
        // Try to access properties to verify controller state
        var testPoint = _mapController!.center;
        
        // Move map
        _mapController!.move(
          LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
          COUNTRY_ZOOM_LEVEL
        );
        print("Successfully moved map to current location");
      } catch (e) {
        print("Failed to move map: $e");
      }
    } catch (e) {
      print("Error moving to current location: $e");
    }
  }
  
  // Add marker
  void addMarker({
    required String id,
    required LatLng position,
    required String title,
    String? snippet,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    Widget? icon,
  }) {
    print('Add marker - ID: $id, position: ${position.latitude}, ${position.longitude}');
    print('Click event set: ${onTap != null}');
    
    // Remove markers with the same ID
    _markers.removeWhere((marker) => marker.key.toString().contains(id));
    
    // Add new marker
    final marker = Marker(
      point: position,
      width: 40, // Ensure a large enough click area
      height: 40, // Ensure a large enough click area
      builder: (context) {
        return GestureDetector(
          onTap: () {
            print('Marker clicked: $id');
            if (onTap != null) onTap();
          },
          onLongPress: onLongPress,
          child: icon ?? 
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, color: Colors.red, size: calculateMarkerSize(15.0)),
                if (title.isNotEmpty)
                  Text(
                    title, 
                    style: TextStyle(
                      fontSize: calculateMarkerSize(10.0),
                      fontWeight: FontWeight.bold
                    ),
                  ),
              ],
            ),
        );
      },
    );
    
    _markers.add(marker);
    
    // Ensure notification listener, so the marker will be displayed on the map
    notifyListeners();
  }
  
  // Add music marker
  void addMusicMarker({
    required String id,
    required String title,
    LatLng? position,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    final LatLng markerPosition = position ?? (currentLatLng ?? _defaultLocation);
    
    addMarker(
      id: 'music_$id',
      position: markerPosition,
      title: title,
      onTap: onTap,
      onLongPress: onLongPress,
      icon: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note, color: Colors.purple, size: calculateMarkerSize(15.0)),
            Text(
              title, 
              style: TextStyle(
                fontSize: calculateMarkerSize(10.0),
                fontWeight: FontWeight.bold
              ),
            ),
          ],
        ),
      ),
    );
    
    developer.log('Added music marker: $title at ${markerPosition.latitude}, ${markerPosition.longitude}', 
                 name: 'FlutterMapService');
  }
  
  // Remove marker
  void removeMarker(String id) {
    print('Start deleting marker: $id, current marker count: ${_markers.length}');
    
    // Print all marker IDs for debugging
    print('All marker IDs: ${_markers.map((m) => m.key.toString()).join(", ")}');
    
    // Try multiple matching methods
    int removedCount = 0;
    
    // 1. Use exact matching
    _markers.removeWhere((marker) {
      bool shouldRemove = marker.key.toString() == 'Key("$id")';
      if (shouldRemove) removedCount++;
      return shouldRemove;
    });
    
    // 2. If exact matching does not delete any markers, try containing matching
    if (removedCount == 0) {
      _markers.removeWhere((marker) {
        bool shouldRemove = marker.key.toString().contains(id);
        if (shouldRemove) removedCount++;
        return shouldRemove;
      });
    }
    
    print('Total deleted $removedCount markers, remaining ${_markers.length}');
    
    // Ensure notification listener, so the marker will be displayed on the map
    notifyListeners();
  }
  
  // Clear all markers
  void clearMarkers() {
    _markers.clear();
  }
  
  // Get default location
  LatLng getDefaultLocation() {
    return _defaultLocation;
  }
  
  // Calculate distance between two points (meters)
  double calculateDistance(LatLng start, LatLng end) {
    final Distance distance = const Distance();
    return distance.as(LengthUnit.Meter, start, end);
  }
  
  // Dispose resources
  void dispose() {
    // Flutter Map has no resources to dispose
  }
  
  // Add new method: clear all weather markers
  void clearAllWeatherMarkers() {
    _markers.removeWhere((marker) => marker.key.toString().contains('weather_'));
  }
  
  // Add new method: update marker click event
  void updateMarkerTapEvent(String id, VoidCallback? onTap) {
    // Find the marker with the matching ID
    int index = _markers.indexWhere((marker) => marker.key.toString().contains(id));
    
    if (index != -1) {
      // Get the original marker
      Marker oldMarker = _markers[index];
      
      // Create a new marker, copy all properties except the click event
      Marker newMarker = Marker(
        key: oldMarker.key,
        point: oldMarker.point,
        width: oldMarker.width,
        height: oldMarker.height,
        builder: (context) {
          // Assume the original builder created a GestureDetector
          // Here we need to wrap the original widget to update its onTap property
          // Note: This is a simplified example, the actual implementation may be more complex
          Widget originalWidget = oldMarker.builder(context);
          
          // If the original widget is a GestureDetector, we can try to copy and modify it
          if (originalWidget is GestureDetector) {
            return GestureDetector(
              onTap: onTap,
              onLongPress: originalWidget.onLongPress,
              child: originalWidget.child,
            );
          }
          
          // Otherwise, return the original widget (do not update the click event)
          return originalWidget;
        },
      );
      
      // Replace the old marker with the new marker
      _markers[index] = newMarker;
    }
  }
  
  // Add notifyListeners method, if not a subclass of ChangeNotifier
  void notifyListeners() {
    // Rebuild the dependent Widget
    super.notifyListeners();
  }
  
  // Add this method in the FlutterMapService class
  void clearAndRebuildMarkers(String excludeId) {
    // Save all markers except the specified ID
    final markersToKeep = _markers.where((marker) => !marker.key.toString().contains(excludeId)).toList();
    
    // Clear the marker list
    _markers.clear();
    
    // Add the retained markers
    _markers.addAll(markersToKeep);
    
    // Notify listener
    notifyListeners();
  }
  
  // Add persistent flag information mapping
  final Map<String, FlagInfo> _persistentFlagMap = {};
  // Getter for persistent flag information mapping
  Map<String, FlagInfo> get persistentFlagMap => _persistentFlagMap;
  
  // Save flag information
  void saveFlagInfo(String flagId, FlagInfo flagInfo) {
    _persistentFlagMap[flagId] = flagInfo;
    // Notify listener to update
    notifyListeners();
  }
  
  // Remove flag information
  void removeFlagInfo(String flagId) {
    print('Remove flag information: $flagId');
    // Remove from persistent mapping
    _persistentFlagMap.remove(flagId);
    // Also remove the corresponding marker
    removeMarker(flagId);
    // Notify listener to update
    notifyListeners();
  }
  
  // Add a new method to reset marker size
  void resetMarkersSize() {
    // Save all current marker information
    final List<Map<String, dynamic>> markersData = _markers.map((marker) {
      // Try to get the ID of the marker
      String id = marker.key.toString();
      id = id.replaceAll('Key("', '').replaceAll('")', '');
      
      // Get the position of the marker
      LatLng position = marker.point;
      
      // Recursively find the gesture detector and extract the click event
      VoidCallback? onTap;
      VoidCallback? onLongPress;
      
      // Marker type (normal or music)
      bool isMusic = id.contains('music_');
      
      return {
        'id': id,
        'position': position,
        'isMusic': isMusic,
      };
    }).toList();
    
    // Clear all markers
    _markers.clear();
    
    // Use fixed base size to recreate markers
    for (var markerData in markersData) {
      if (markerData['isMusic']) {
        // Recreate music marker
        addMusicMarker(
          id: markerData['id'],
          title: '',
          position: markerData['position'],
        );
      } else {
        // Recreate normal marker
        final flagId = markerData['id'];
        final position = markerData['position'];
        
        // Check if persistent flag information exists
        if (_persistentFlagMap.containsKey(flagId)) {
          addMarker(
            id: flagId,
            position: position,
            title: '',
            icon: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.flag,
                color: Colors.red,
                size: 15.0,  // Use fixed size instead of dynamic calculation
              ),
            ),
            onTap: () {
              // We need to handle the click event in HomeScreen
              print('Flag clicked: $flagId');
            },
            onLongPress: () {
              // We need to handle the long press event in HomeScreen
            },
          );
        }
      }
    }
    
    // Notify listener to update
    notifyListeners();
  }
  
  // Add a method to delete flags by music ID
  void deleteFlagsByMusicId(String musicId) {
    // Find all flags associated with the music
    List<String> flagsToDelete = [];
    
    _persistentFlagMap.forEach((flagId, flagInfo) {
      // Check if the flag is associated with the music
      if (flagInfo.musicTitle != null && flagInfo.musicTitle == musicId) {
        flagsToDelete.add(flagId);
      }
    });
    
    // Remove all found flags
    for (String flagId in flagsToDelete) {
      removeFlagInfo(flagId);
    }
    
    // Notify listener to update UI
    notifyListeners();
  }
  
  // Add a more general method to find flags by music information
  void cleanupFlagsByMusicInfo(String? musicId, String? musicTitle) {
    print('Cleanup music-related flags, ID: $musicId, title: $musicTitle');
    
    if (musicId == null && (musicTitle == null || musicTitle.isEmpty)) {
      print('Invalid query parameters, musicId and musicTitle are both null or invalid');
      return;
    }
    
    List<String> flagsToDelete = [];
    
    _persistentFlagMap.forEach((flagId, flagInfo) {
      if (flagInfo.musicTitle != null) {
        print('Checking flag $flagId: title="${flagInfo.musicTitle}"');
        
        // Try two matching methods
        bool shouldDelete = false;
        
        // 1. If the title matches exactly
        if (musicTitle != null && musicTitle.isNotEmpty && 
            flagInfo.musicTitle == musicTitle) {
          print('Title exact match: "${flagInfo.musicTitle}" == "$musicTitle"');
          shouldDelete = true;
        }
        
        // 2. If the title contains the music ID
        if (musicId != null && musicId.isNotEmpty && 
            flagInfo.musicTitle!.contains(musicId)) {
          print('Title contains ID: "${flagInfo.musicTitle}" contains "$musicId"');
          shouldDelete = true;
        }
        
        if (shouldDelete) {
          print('Found flag to delete: $flagId, title: "${flagInfo.musicTitle}"');
          flagsToDelete.add(flagId);
        }
      }
    });
    
    // Delete all found flags
    if (flagsToDelete.isNotEmpty) {
      print('Preparing to delete ${flagsToDelete.length} flags');
      for (String id in flagsToDelete) {
        removeFlagInfo(id);
        print('Deleted flag: $id');
      }
      notifyListeners();
    } else {
      print('No associated flags found to delete');
    }
  }
  
  // 检查位置权限 - 添加这个公共方法
  Future<bool> checkLocationPermission() async {
    return await _checkLocationPermission();
  }
  
  // 请求位置权限 - 添加这个公共方法
  Future<bool> requestLocationPermission() async {
    bool serviceEnabled;
    PermissionStatus permissionStatus;
    
    try {
      // 检查位置服务是否启用
      serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        print("DEBUG: 位置服务未启用，请求启用服务");
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) {
          print("DEBUG: 用户拒绝启用位置服务");
          return false;
        }
      }
      
      // 检查位置权限
      permissionStatus = await _locationService.hasPermission();
      print("DEBUG: 当前权限状态: $permissionStatus");
      
      if (permissionStatus == PermissionStatus.denied) {
        print("DEBUG: 权限被拒绝，请求权限");
        permissionStatus = await _locationService.requestPermission();
        print("DEBUG: 请求后，权限状态: $permissionStatus");
        
        if (permissionStatus != PermissionStatus.granted && 
            permissionStatus != PermissionStatus.grantedLimited) {
          print("DEBUG: 用户拒绝位置权限");
          return false;
        }
      }
      
      print("DEBUG: 位置权限已授予: $permissionStatus");
      return true;
    } catch (e) {
      print("DEBUG: 检查/请求位置权限时出错: $e");
      return false;
    }
  }
  
  // 获取当前权限状态的详细信息
  Future<PermissionStatus> getCurrentPermissionStatus() async {
    try {
      return await _locationService.hasPermission();
    } catch (e) {
      print('Error getting permission status: $e');
      return PermissionStatus.denied;
    }
  }
  
  // 公开请求位置权限的方法，返回详细的权限状态结果
  Future<PermissionStatus> requestLocationPermissionDetailed() async {
    bool serviceEnabled;
    PermissionStatus permissionStatus;
    
    try {
      // 检查位置服务是否启用
      serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) {
          print('Location services are disabled');
          return PermissionStatus.denied;
        }
      }
      
      // 检查位置权限
      permissionStatus = await _locationService.hasPermission();
      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await _locationService.requestPermission();
      }
      
      return permissionStatus;
    } catch (e) {
      print('Error requesting location permission: $e');
      return PermissionStatus.denied;
    }
  }
  
  // 保存权限状态
  Future<void> savePermissionStatus(PermissionStatus status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 将权限状态保存为字符串
      await prefs.setString('location_permission_status', status.toString());
      
      // 记录是否已请求过权限
      await prefs.setBool('location_permission_asked', true);
      
      print('Saved permission status: $status');
    } catch (e) {
      print('Error saving permission status: $e');
    }
  }
  
  // 检查是否需要再次请求权限
  Future<bool> shouldRequestPermissionAgain() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 如果从未请求过权限，则需要请求
      bool permissionAsked = prefs.getBool('location_permission_asked') ?? false;
      if (!permissionAsked) {
        return true;
      }
      
      // 获取保存的权限状态
      String? permissionStatusStr = prefs.getString('location_permission_status');
      if (permissionStatusStr == null) {
        return true;
      }
      
      // 如果权限状态是"仅限一次"或"拒绝"，则需要再次请求
      return permissionStatusStr == 'PermissionStatus.grantedLimited' || 
             permissionStatusStr == 'PermissionStatus.denied';
    } catch (e) {
      print('Error checking if permission should be requested again: $e');
      return true;
    }
  }
  
  // Add this method to use the default location
  void _useDefaultLocation() {
    _currentLocation = LocationData.fromMap({
      'latitude': _defaultLocation.latitude,
      'longitude': _defaultLocation.longitude,
      'accuracy': 0.0,
      'altitude': 0.0,
      'speed': 0.0,
      'speed_accuracy': 0.0,
      'heading': 0.0,
      'time': DateTime.now().millisecondsSinceEpoch.toDouble(),
    });
  }
}