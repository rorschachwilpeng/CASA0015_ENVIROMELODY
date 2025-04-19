import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'dart:developer' as developer;

class DeviceIdManager {
  // Singleton pattern
  static final DeviceIdManager _instance = DeviceIdManager._internal();
  factory DeviceIdManager() => _instance;
  DeviceIdManager._internal();
  
  // Key for storing device ID
  static const String _deviceIdKey = 'device_id';
  
  // Device ID cache
  String? _deviceId;
  
  // Get device ID
  Future<String> getDeviceId() async {
    // If there is a cache, return it directly
    if (_deviceId != null) {
      return _deviceId!;
    }
    
    try {
      // Get from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      String? storedId = prefs.getString(_deviceIdKey);
      
      if (storedId != null && storedId.isNotEmpty) {
        _deviceId = storedId;
        developer.log('Loaded device ID from local storage: $_deviceId', name: 'DeviceIdManager');
        return storedId;
      }
      
      // No stored ID, generate new ID
      final String newId = await _generateDeviceId();
      
      // Save to SharedPreferences
      await prefs.setString(_deviceIdKey, newId);
      _deviceId = newId;
      
      developer.log('Generated new device ID: $_deviceId', name: 'DeviceIdManager');
      return newId;
    } catch (e) {
      developer.log('Failed to get device ID: $e', name: 'DeviceIdManager');
      
      // Generate random fallback ID
      final fallbackId = 'fallback_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
      _deviceId = fallbackId;
      return fallbackId;
    }
  }
  
  // Generate device unique identifier
  Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceId = '';
    
    try {
      if (kIsWeb) {
        // Web platform
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceId = 'web_${webInfo.browserName}_${webInfo.platform}_${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isAndroid) {
        // Android platform
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = 'android_${androidInfo.id}_${androidInfo.device}';
      } else if (Platform.isIOS) {
        // iOS platform
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = 'ios_${iosInfo.identifierForVendor}';
      } else {
        // Other platforms
        deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
      }
    } catch (e) {
      developer.log('Failed to generate device ID: $e', name: 'DeviceIdManager');
      deviceId = 'error_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
    }
    
    return deviceId;
  }
  
  // Reset device ID (use with caution)
  Future<bool> resetDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceIdKey);
      _deviceId = null;
      return true;
    } catch (e) {
      developer.log('Failed to reset device ID: $e', name: 'DeviceIdManager');
      return false;
    }
  }
}
