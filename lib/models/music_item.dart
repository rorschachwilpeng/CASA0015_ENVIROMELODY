import 'package:flutter/foundation.dart';
import 'weather_service.dart';

class MusicItem {
  final String id;
  final String title;
  final String prompt;
  final String audioUrl;
  final String status;
  final DateTime createdAt;
  
  // Optional: Add a field to represent the music source/API
  final String source;
  
  // 新增位置相关字段
  final double? latitude;
  final double? longitude;
  final String? locationName;
  
  // 新增天气数据字段
  final Map<String, dynamic>? weatherData;
  
  MusicItem({
    required this.id,
    required this.title,
    required this.prompt,
    required this.audioUrl,
    required this.status,
    required this.createdAt,
    this.source = 'stability', // Default source is stability
    // 新增字段初始化
    this.latitude,
    this.longitude,
    this.locationName,
    this.weatherData,
  });
  
  // From JSON constructor
  factory MusicItem.fromJson(Map<String, dynamic> json) {
    String audioUrl = json['audio_url'] ?? json['audioUrl'] ?? '';
    
    // Check if it contains placeholder URL, if it does, try to fix it
    if (audioUrl.contains('your-api-base-url.com')) {
      final pathMatch = RegExp(r'/Users/.+\.mp3').firstMatch(audioUrl);
      if (pathMatch != null) {
        String newUrl = pathMatch.group(0) ?? '';
        if (!newUrl.startsWith('file://')) {
          audioUrl = 'file://$newUrl';
        } else {
          audioUrl = newUrl;
        }
      }
    }
    
    return MusicItem(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled Music',
      prompt: json['prompt'] ?? '',
      audioUrl: audioUrl,
      status: json['status'] ?? 'unknown',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      source: json['source'] ?? 'stability',
      // 添加新字段的解析
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      locationName: json['location_name'],
      weatherData: json['weather_data'],
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'prompt': prompt,
      'audio_url': audioUrl,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'source': source,
      // 添加新字段
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'weather_data': weatherData,
    };
  }
  
  // Create from existing SunoMusic object
  factory MusicItem.fromSunoMusic(dynamic sunoMusic) {
    if (sunoMusic == null) return MusicItem.empty();
    
    return MusicItem(
      id: sunoMusic.id,
      title: sunoMusic.title,
      prompt: sunoMusic.prompt,
      audioUrl: sunoMusic.audioUrl,
      status: sunoMusic.status,
      createdAt: sunoMusic.createdAt,
      source: 'stability',
      latitude: sunoMusic.latitude,
      longitude: sunoMusic.longitude,
      locationName: sunoMusic.locationName,
      weatherData: sunoMusic.weatherData,
    );
  }
  
  // Empty object, used for initialization or error handling
  factory MusicItem.empty() {
    return MusicItem(
      id: '',
      title: '',
      prompt: '',
      audioUrl: '',
      status: 'empty',
      createdAt: DateTime.now(),
      source: 'stability',
    );
  }
  
  // Copy and modify
  MusicItem copyWith({
    String? id,
    String? title,
    String? prompt,
    String? audioUrl,
    String? status,
    DateTime? createdAt,
    String? source,
    // 添加新字段
    double? latitude,
    double? longitude,
    String? locationName,
    Map<String, dynamic>? weatherData,
  }) {
    return MusicItem(
      id: id ?? this.id,
      title: title ?? this.title,
      prompt: prompt ?? this.prompt,
      audioUrl: audioUrl ?? this.audioUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
      // 添加新字段
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      weatherData: weatherData ?? this.weatherData,
    );
  }
  
  @override
  String toString() {
    return 'MusicItem{id: $id, title: $title, prompt: $prompt, status: $status}';
  }
  
  // 从 MusicItem 获取 WeatherData 对象
  WeatherData? getWeatherData() {
    if (weatherData == null) return null;
    return WeatherData.fromJsonMap(weatherData!);
  }
  
  // 静态方法：创建带有天气数据的 MusicItem
  static MusicItem createWithWeather({
    required String id,
    required String title,
    required String prompt,
    required String audioUrl,
    required String status,
    required DateTime createdAt,
    String source = 'stability',
    WeatherData? weatherData,
    LocationData? locationData,
  }) {
    return MusicItem(
      id: id,
      title: title,
      prompt: prompt,
      audioUrl: audioUrl,
      status: status,
      createdAt: createdAt,
      source: source,
      latitude: locationData?.latitude,
      longitude: locationData?.longitude,
      locationName: locationData?.getFormattedLocation(),
      weatherData: weatherData?.toJson(),
    );
  }
} 