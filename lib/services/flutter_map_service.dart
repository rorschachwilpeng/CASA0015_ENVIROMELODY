import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../screens/home_screen.dart'; //Import FlagInfo class

// Move to class external 
typedef ZoomChangedCallback = void Function(double zoom);

// Flutter Map Map Service
class FlutterMapService extends ChangeNotifier {
  // Singleton Pattern
  static final FlutterMapService _instance = FlutterMapService._internal();
  factory FlutterMapService() => _instance;
  FlutterMapService._internal();
  
  // Default location: London (latitude 51.5074, longitude -0.1278)
  final LatLng _defaultLocation = const LatLng(51.5074, -0.1278);
  
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
      // Check if location service is enabled
      serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) {
          developer.log('Location services are disabled', name: 'FlutterMapService');
          return false;
        }
      }
      
      // Check location permission
      permissionStatus = await _locationService.hasPermission();
      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await _locationService.requestPermission();
        if (permissionStatus != PermissionStatus.granted) {
          developer.log('Location permissions are denied', name: 'FlutterMapService');
          return false;
        }
      }
      
      // Get current location
      await getCurrentLocation();
      
      // Only move when _autoMoveToCurrentLocation is true
      if (_autoMoveToCurrentLocation && _mapController != null) {
        await moveToCurrentLocation();
      }
      
      return true;
    } catch (e) {
      developer.log('Error checking location permission: $e', name: 'FlutterMapService');
      return false;
    }
  }
  
  // Get current location
  Future<void> getCurrentLocation() async {
    try {
      // Ensure a reasonable default value is set even if there is a timeout
      final locationData = await _locationService.getLocation()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        print("DEBUG: Get location timeout");
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
        return _currentLocation!;
      });
      
      _currentLocation = locationData;
      developer.log('Current location: ${locationData.latitude}, ${locationData.longitude}', 
                  name: 'FlutterMapService');
    } catch (e) {
      // Ensure a default value is set even if there is an error
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
      print("DEBUG: Error getting location: $e");
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
      
      // Add safety check to avoid using a destroyed controller
      try {
        // Check if the map controller is still valid
        var testPoint = _mapController!.center; // Try to access the property to verify the controller state
        
        _mapController!.move(
          LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
          COUNTRY_ZOOM_LEVEL
        );
        print("Successfully moved map to current location");
      } catch (e) {
        print("Failed to move map: $e");
        // Do not throw an exception here, handle the error gracefully
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
}