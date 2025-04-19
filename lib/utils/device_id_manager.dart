import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'dart:developer' as developer;

class DeviceIdManager {
  // 单例模式
  static final DeviceIdManager _instance = DeviceIdManager._internal();
  factory DeviceIdManager() => _instance;
  DeviceIdManager._internal();
  
  // 存储设备ID的key
  static const String _deviceIdKey = 'device_id';
  
  // 设备ID缓存
  String? _deviceId;
  
  // 获取设备ID
  Future<String> getDeviceId() async {
    // 如果已有缓存，直接返回
    if (_deviceId != null) {
      return _deviceId!;
    }
    
    try {
      // 从SharedPreferences获取
      final prefs = await SharedPreferences.getInstance();
      String? storedId = prefs.getString(_deviceIdKey);
      
      if (storedId != null && storedId.isNotEmpty) {
        _deviceId = storedId;
        developer.log('从本地存储加载设备ID: $_deviceId', name: 'DeviceIdManager');
        return storedId;
      }
      
      // 没有存储的ID，生成新ID
      final String newId = await _generateDeviceId();
      
      // 保存到SharedPreferences
      await prefs.setString(_deviceIdKey, newId);
      _deviceId = newId;
      
      developer.log('生成新设备ID: $_deviceId', name: 'DeviceIdManager');
      return newId;
    } catch (e) {
      developer.log('获取设备ID失败: $e', name: 'DeviceIdManager');
      
      // 生成随机备用ID
      final fallbackId = 'fallback_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
      _deviceId = fallbackId;
      return fallbackId;
    }
  }
  
  // 生成设备唯一标识符
  Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceId = '';
    
    try {
      if (kIsWeb) {
        // Web平台
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceId = 'web_${webInfo.browserName}_${webInfo.platform}_${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isAndroid) {
        // Android平台
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = 'android_${androidInfo.id}_${androidInfo.device}';
      } else if (Platform.isIOS) {
        // iOS平台
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = 'ios_${iosInfo.identifierForVendor}';
      } else {
        // 其他平台
        deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
      }
    } catch (e) {
      developer.log('生成设备ID失败: $e', name: 'DeviceIdManager');
      deviceId = 'error_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
    }
    
    return deviceId;
  }
  
  // 重置设备ID（慎用）
  Future<bool> resetDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceIdKey);
      _deviceId = null;
      return true;
    } catch (e) {
      developer.log('重置设备ID失败: $e', name: 'DeviceIdManager');
      return false;
    }
  }
}
