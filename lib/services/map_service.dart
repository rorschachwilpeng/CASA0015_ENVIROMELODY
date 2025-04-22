import 'dart:async';
import 'dart:math' as math; // Import math library
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'dart:developer' as developer;

class MapService {
  // Singleton Pattern
  static final MapService _instance = MapService._internal();
  factory MapService() => _instance;
  MapService._internal();
  
  // Default location: London (latitude 51.5074, longitude -0.1278)
  final LatLng _defaultLocation = const LatLng(51.5074, -0.1278);
  
  // Location Service
  final Location _locationService = Location();
  
  // Current Location
  LocationData? _currentLocation;
  LatLng? get currentLatLng => _currentLocation != null 
      ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!) 
      : _defaultLocation;
  
  // Google Map Controller
  Completer<GoogleMapController>? _controllerCompleter;
  GoogleMapController? _controller;
  
  // Marker Collection
  final Set<Marker> _markers = {};
  Set<Marker> get markers => _markers;
  
  // Current Map Type
  MapType _currentMapType = MapType.normal;
  MapType get currentMapType => _currentMapType;
  
  // Initialize Map
  void initMap(Completer<GoogleMapController> completer) {
    _controllerCompleter = completer;
    _checkLocationPermission();
  }
  
  // When the map controller is ready
  Future<void> onMapCreated(GoogleMapController controller) async {
    print("DEBUG: Map creation callback called");
    try {
      _controller = controller;
      print("DEBUG: Controller assigned");
      if (_controllerCompleter != null && !_controllerCompleter!.isCompleted) {
        _controllerCompleter!.complete(controller);
        print("DEBUG: Completer completed");
      } else {
        print("DEBUG: Completer is null or already completed");
      }
    } catch (e) {
      print("DEBUG: Map creation callback error: $e");
    }
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
          developer.log('Location services are disabled', name: 'MapService');
          return false;
        }
      }
      
      // Check location permission
      permissionStatus = await _locationService.hasPermission();
      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await _locationService.requestPermission();
        if (permissionStatus != PermissionStatus.granted) {
          developer.log('Location permissions are denied', name: 'MapService');
          return false;
        }
      }
      
      // Get current location
      await _getCurrentLocation();
      return true;
    } catch (e) {
      developer.log('Error checking location permission: $e', name: 'MapService');
      return false;
    }
  }
  
  // Get current location
  Future<void> _getCurrentLocation() async {
    try {
      // Add timeout handling
      final locationData = await _locationService.getLocation()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        print("DEBUG: Get location timeout");
        return LocationData.fromMap({
          'latitude': _defaultLocation.latitude,
          'longitude': _defaultLocation.longitude,
          'accuracy': 0.0,
          'altitude': 0.0,
          'speed': 0.0,
          'speed_accuracy': 0.0,
          'heading': 0.0,
          'time': DateTime.now().millisecondsSinceEpoch.toDouble(),
        });
      });
      
      _currentLocation = locationData;
      developer.log('Current location: ${locationData.latitude}, ${locationData.longitude}', 
                   name: 'MapService');
    } catch (e) {
      print("DEBUG: Error getting location: $e");
      developer.log('Error getting location: $e', name: 'MapService');
    }
  }
  
  // Move to current location
  Future<void> moveToCurrentLocation() async {
    try {
      print("DEBUG: moveToCurrentLocation started");
      print("DEBUG: Trying to get current location");
      await _getCurrentLocation();
      print("DEBUG: Current location retrieved");
      
      if (_controller == null) {
        print("DEBUG: Map controller is null, trying to get from completer");
        if (_controllerCompleter != null) {
          _controller = await _controllerCompleter!.future;
          print("DEBUG: Got controller from completer");
        } else {
          developer.log('Map controller not initialized', name: 'MapService');
          print("DEBUG: Controller completer is null, cannot get controller");
          return;
        }
      }
      
      print("DEBUG: Preparing to move camera");
      if (_currentLocation != null) {
        print("DEBUG: Using current location: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}");
        await _controller!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
              zoom: 15.0,
            ),
          ),
        );
      } else {
        print("DEBUG: Using default location: ${_defaultLocation.latitude}, ${_defaultLocation.longitude}");
        await _controller!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _defaultLocation,
              zoom: 12.0,
            ),
          ),
        );
      }
      print("DEBUG: Camera moved");
    } catch (e) {
      print("DEBUG: Error moving to current location: $e");
      developer.log('Error moving to current location: $e', name: 'MapService');
    }
  }
  
  // Set map type
  void setMapType(MapType mapType) {
    _currentMapType = mapType;
  }
  
  // Add marker
  void addMarker({
    required String id,
    required LatLng position,
    required String title,
    String? snippet,
    VoidCallback? onTap,
    BitmapDescriptor? icon,
  }) {
    final markerId = MarkerId(id);
    
    final marker = Marker(
      markerId: markerId,
      position: position,
      infoWindow: InfoWindow(
        title: title,
        snippet: snippet,
      ),
      icon: icon ?? BitmapDescriptor.defaultMarker,
      onTap: onTap,
    );
    
    _markers.add(marker);
  }
  
  // Remove marker
  void removeMarker(String id) {
    _markers.removeWhere((marker) => marker.markerId == MarkerId(id));
  }
  
  // Clear all markers
  void clearMarkers() {
    _markers.clear();
  }
  
  // Add music marker
  void addMusicMarker({
    required String id,
    required String title,
    LatLng? position,
    VoidCallback? onTap,
  }) {
    final LatLng markerPosition = position ?? (currentLatLng ?? _defaultLocation);
    
    addMarker(
      id: 'music_$id',
      position: markerPosition,
      title: title,
      snippet: 'Tap to play music',
      onTap: onTap,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
    );
    
    developer.log('Added music marker: $title at ${markerPosition.latitude}, ${markerPosition.longitude}', name: 'MapService');
  }
  
  // Get default location
  LatLng getDefaultLocation() {
    return _defaultLocation;
  }
  
  // Calculate distance between two points (meters)
  double calculateDistance(LatLng start, LatLng end) {
    // Use Haversine formula to calculate spherical distance
    const double earthRadius = 6371000; // Earth radius, unit: meters
    
    // Convert to radians
    final double startLatRad = start.latitude * (math.pi / 180);
    final double startLngRad = start.longitude * (math.pi / 180);
    final double endLatRad = end.latitude * (math.pi / 180);
    final double endLngRad = end.longitude * (math.pi / 180);
    
    // Half-great-circle formula
    final double dLat = endLatRad - startLatRad;
    final double dLng = endLngRad - startLngRad;
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(startLatRad) * math.cos(endLatRad) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  // Dispose resources
  void dispose() {
    _controller?.dispose();
  }
  
  // Add this public method
  Future<void> getCurrentLocation() async {
    return _getCurrentLocation();
  }
} 