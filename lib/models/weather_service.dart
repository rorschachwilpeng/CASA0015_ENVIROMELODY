import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Weather service class - responsible for communicating with the OpenWeather API to get weather data
class WeatherService {
  // Singleton pattern
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();
  
  // OpenWeather API key - replace with your actual API key
  final String _apiKey = '9a5b95af3b09cae239fea38a996a8094';
  
  // API base URL
  final String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  final String _geoUrl = 'http://api.openweathermap.org/geo/1.0';
  
  /// Get weather data based on latitude and longitude
  Future<WeatherData?> getWeatherByLocation(double latitude, double longitude) async {
    try {
      // Build API request URL - using metric units (Celsius)
      final url = '$_baseUrl/weather?lat=$latitude&lon=$longitude&units=metric&appid=$_apiKey';
      
      developer.log('Getting weather data: $url', name: 'WeatherService');
      
      // Send request and wait for response
      final response = await http.get(Uri.parse(url));
      
      // Check response status
      if (response.statusCode == 200) {
        // Parse JSON response
        final data = json.decode(response.body);
        final locationData = await getLocationInfo(latitude, longitude);
        
        return WeatherData.fromJson(data, locationData);
      } else {
        // Handle error response
        developer.log(
          'OpenWeather API error: ${response.statusCode}',
          name: 'WeatherService',
          error: response.body
        );
        return null;
      }
    } catch (e) {
      // Catch and log any exception
      developer.log(
        'Error getting weather data',
        name: 'WeatherService',
        error: e.toString()
      );
      return null;
    }
  }
  
  /// Get location information for specified coordinates (reverse geocoding)
  Future<LocationData?> getLocationInfo(double latitude, double longitude) async {
    try {
      // OpenWeather Geocoding API
      final url = '$_geoUrl/reverse?lat=$latitude&lon=$longitude&limit=1&appid=$_apiKey';
      
      developer.log('获取位置信息: $url', name: 'WeatherService');
      
      // Send request and wait for response
      final response = await http.get(Uri.parse(url));
      
      // Check response status
      if (response.statusCode == 200) {
        // Parse JSON response
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          return LocationData.fromJson(data[0]);
        }
        return null;
      } else {
        // Handle error response
        developer.log(
          'OpenWeather Geocoding API error: ${response.statusCode}',
          name: 'WeatherService',
          error: response.body
        );
        return null;
      }
    } catch (e) {
      // Catch and log any exception
      developer.log(
        'Error getting location information',
        name: 'WeatherService',
        error: e.toString()
      );
      return null;
    }
  }
  
  /// Get weather icon URL
  String getWeatherIconUrl(String iconCode) {
    return 'https://openweathermap.org/img/wn/$iconCode@2x.png';
  }
  
  /// Get 5-day weather forecast based on latitude and longitude
  Future<List<ForecastData>?> getForecastByLocation(double latitude, double longitude) async {
    try {
      // Build API request URL
      final url = '$_baseUrl/forecast?lat=$latitude&lon=$longitude&units=metric&appid=$_apiKey';
      
      developer.log('Getting weather forecast: $url', name: 'WeatherService');
      
      // Send request and wait for response
      final response = await http.get(Uri.parse(url));
      
      // Check response status
      if (response.statusCode == 200) {
        // Parse JSON response
        final data = json.decode(response.body);
        
        if (data['list'] != null && data['list'] is List) {
          final List<dynamic> forecastList = data['list'];
          return forecastList.map((item) => ForecastData.fromJson(item)).toList();
        }
        
        return [];
      } else {
        // Handle error response
        developer.log(
          'OpenWeather Forecast API error: ${response.statusCode}',
          name: 'WeatherService',
          error: response.body
        );
        return null;
      }
    } catch (e) {
      // Catch and log any exception
      developer.log(
        'Error getting weather forecast',
        name: 'WeatherService',
        error: e.toString()
      );
      return null;
    }
  }
}

/// Weather data model
class WeatherData {
  final String cityName;       // City name
  final String countryCode;    // Country code
  final double temperature;    // Temperature (Celsius)
  final double feelsLike;      // Feels like temperature
  final double tempMin;        // Minimum temperature
  final double tempMax;        // Maximum temperature
  final int humidity;          // Humidity (%)
  final double windSpeed;      // Wind speed (m/s)
  final int windDegree;        // Wind direction (degrees)
  final double? windGust;      // Wind gust speed (m/s, may be null)
  final int pressure;          // Pressure (hPa)
  final String weatherMain;    // Weather main condition (e.g. Rain, Snow, Clear)
  final String weatherDescription; // Weather detailed description
  final String weatherIcon;    // Weather icon code
  final int cloudsPercent;     // Cloud cover (%)
  final int visibility;        // Visibility (meters)
  final DateTime sunrise;      // Sunrise time
  final DateTime sunset;       // Sunset time
  final DateTime timestamp;    // Data retrieval timestamp
  final int timezone;          // Timezone offset (seconds)
  
  // Location information
  final LocationData? location;
  
  WeatherData({
    required this.cityName,
    required this.countryCode,
    required this.temperature,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.windSpeed,
    required this.windDegree,
    this.windGust,
    required this.pressure,
    required this.weatherMain,
    required this.weatherDescription,
    required this.weatherIcon,
    required this.cloudsPercent,
    required this.visibility,
    required this.sunrise,
    required this.sunset,
    required this.timestamp,
    required this.timezone,
    this.location,
  });
  
  /// Create WeatherData object from OpenWeather API JSON response
  factory WeatherData.fromJson(Map<String, dynamic> json, [LocationData? locationData]) {
    final weather = json['weather'][0];
    final main = json['main'];
    final wind = json['wind'];
    final clouds = json['clouds'];
    final sys = json['sys'];
    
    return WeatherData(
      cityName: json['name'] ?? 'Unknown',
      countryCode: sys['country'] ?? '',
      temperature: (main['temp'] ?? 0).toDouble(),
      feelsLike: (main['feels_like'] ?? 0).toDouble(),
      tempMin: (main['temp_min'] ?? 0).toDouble(),
      tempMax: (main['temp_max'] ?? 0).toDouble(),
      humidity: main['humidity'] ?? 0,
      windSpeed: (wind['speed'] ?? 0).toDouble(),
      windDegree: wind['deg'] ?? 0,
      windGust: wind['gust'] != null ? (wind['gust']).toDouble() : null,
      pressure: main['pressure'] ?? 0,
      weatherMain: weather['main'] ?? '',
      weatherDescription: weather['description'] ?? '',
      weatherIcon: weather['icon'] ?? '',
      cloudsPercent: clouds['all'] ?? 0,
      visibility: json['visibility'] ?? 0,
      sunrise: DateTime.fromMillisecondsSinceEpoch((sys['sunrise'] ?? 0) * 1000),
      sunset: DateTime.fromMillisecondsSinceEpoch((sys['sunset'] ?? 0) * 1000),
      timestamp: DateTime.fromMillisecondsSinceEpoch((json['dt'] ?? 0) * 1000),
      timezone: json['timezone'] ?? 0,
      location: locationData,
    );
  }
  
  /// Get weather period (morning, midday, evening, night)
  String getDayPeriod() {
    final hour = DateTime.now().hour;
    
    if (hour >= 5 && hour < 12) {
      return 'morning';
    } else if (hour >= 12 && hour < 17) {
      return 'midday';
    } else if (hour >= 17 && hour < 21) {
      return 'evening';
    } else {
      return 'night';
    }
  }
  
  /// Get weather condition description (for UI display)
  String getWeatherCondition() {
    return weatherDescription;
  }
  
  /// Map temperature to emotional description
  List<String> getTemperatureMood() {
    if (temperature >= 30) {
      return ['hot', 'energetic'];
    } else if (temperature >= 20) {
      return ['warm', 'cheerful'];
    } else if (temperature >= 10) {
      return ['cool', 'calm'];
    } else if (temperature >= 0) {
      return ['cold', 'melancholic'];
    } else {
      return ['freezing', 'contemplative'];
    }
  }
  
  /// Map weather condition to emotional description
  List<String> getWeatherMood() {
    final condition = weatherMain.toLowerCase();
    
    if (condition.contains('clear')) {
      return ['bright', 'cheerful'];
    } else if (condition.contains('cloud')) {
      return ['changing', 'thoughtful'];
    } else if (condition.contains('rain')) {
      return ['melancholic', 'introspective'];
    } else if (condition.contains('snow')) {
      return ['pure', 'quiet'];
    } else if (condition.contains('fog') || condition.contains('mist')) {
      return ['mysterious', 'vague'];
    } else if (condition.contains('wind') || condition.contains('storm')) {
      return ['restless', 'dynamic'];
    } else {
      return ['neutral', 'balanced'];
    }
  }
  
  /// Build music generation prompt
  String buildMusicPrompt() {
    final dayPeriod = getDayPeriod();
    final temperatureMoods = getTemperatureMood();
    final weatherMoods = getWeatherMood();
    final locationName = location?.getFormattedLocation() ?? cityName;
    
    return '''
A $dayPeriod photo taken at $locationName.
The weather is $weatherDescription and $temperature degrees. The date is ${timestamp.year}-${timestamp.month}-${timestamp.day}.
The mood is ${temperatureMoods[0]} and ${weatherMoods[0]}.
''';
  }
  
  /// Get weather icon URL
  String getIconUrl() {
    return 'https://openweathermap.org/img/wn/$weatherIcon@2x.png';
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'city_name': cityName,
      'country_code': countryCode,
      'temperature': temperature,
      'feels_like': feelsLike,
      'temp_min': tempMin,
      'temp_max': tempMax,
      'humidity': humidity,
      'wind_speed': windSpeed,
      'wind_degree': windDegree,
      'wind_gust': windGust,
      'pressure': pressure,
      'weather_main': weatherMain,
      'weather_description': weatherDescription,
      'weather_icon': weatherIcon,
      'clouds_percent': cloudsPercent,
      'visibility': visibility,
      'sunrise': sunrise.millisecondsSinceEpoch,
      'sunset': sunset.millisecondsSinceEpoch,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'timezone': timezone,
      'location': location?.toJson(),
    };
  }

  static WeatherData? fromJsonMap(Map<String, dynamic>? json) {
    if (json == null) return null;
    
    LocationData? locationData;
    if (json['location'] != null) {
      locationData = LocationData.fromJsonMap(json['location']);
    }
    
    return WeatherData(
      cityName: json['city_name'] ?? 'Unknown',
      countryCode: json['country_code'] ?? '',
      temperature: (json['temperature'] ?? 0).toDouble(),
      feelsLike: (json['feels_like'] ?? 0).toDouble(),
      tempMin: (json['temp_min'] ?? 0).toDouble(),
      tempMax: (json['temp_max'] ?? 0).toDouble(),
      humidity: json['humidity'] ?? 0,
      windSpeed: (json['wind_speed'] ?? 0).toDouble(),
      windDegree: json['wind_degree'] ?? 0,
      windGust: json['wind_gust']?.toDouble(),
      pressure: json['pressure'] ?? 0,
      weatherMain: json['weather_main'] ?? '',
      weatherDescription: json['weather_description'] ?? '',
      weatherIcon: json['weather_icon'] ?? '',
      cloudsPercent: json['clouds_percent'] ?? 0,
      visibility: json['visibility'] ?? 0,
      sunrise: DateTime.fromMillisecondsSinceEpoch(json['sunrise'] ?? 0),
      sunset: DateTime.fromMillisecondsSinceEpoch(json['sunset'] ?? 0),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
      timezone: json['timezone'] ?? 0,
      location: locationData,
    );
  }
}

/// Forecast data model
class ForecastData {
  final DateTime timestamp;    // Forecast time
  final double temperature;    // Temperature (Celsius)
  final double feelsLike;      // Feels like temperature
  final double tempMin;        // Minimum temperature
  final double tempMax;        // Maximum temperature
  final int humidity;          // Humidity (%)
  final double windSpeed;      // Wind speed (m/s)
  final int windDegree;        // Wind direction (degrees)
  final String weatherMain;    // Weather main condition
  final String weatherDescription; // Weather detailed description
  final String weatherIcon;    // Weather icon code
  final int cloudsPercent;     // Cloud cover (%)
  final int visibility;        // Visibility (meters)
  final double pop;            // Precipitation probability (0-1)
  
  ForecastData({
    required this.timestamp,
    required this.temperature,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.windSpeed,
    required this.windDegree,
    required this.weatherMain,
    required this.weatherDescription,
    required this.weatherIcon,
    required this.cloudsPercent,
    required this.visibility,
    required this.pop,
  });
  
  /// 从OpenWeather API JSON响应创建ForecastData对象
  factory ForecastData.fromJson(Map<String, dynamic> json) {
    final weather = json['weather'][0];
    final main = json['main'];
    final wind = json['wind'];
    final clouds = json['clouds'];
    
    return ForecastData(
      timestamp: DateTime.fromMillisecondsSinceEpoch((json['dt'] ?? 0) * 1000),
      temperature: (main['temp'] ?? 0).toDouble(),
      feelsLike: (main['feels_like'] ?? 0).toDouble(),
      tempMin: (main['temp_min'] ?? 0).toDouble(),
      tempMax: (main['temp_max'] ?? 0).toDouble(),
      humidity: main['humidity'] ?? 0,
      windSpeed: (wind['speed'] ?? 0).toDouble(),
      windDegree: wind['deg'] ?? 0,
      weatherMain: weather['main'] ?? '',
      weatherDescription: weather['description'] ?? '',
      weatherIcon: weather['icon'] ?? '',
      cloudsPercent: clouds['all'] ?? 0,
      visibility: json['visibility'] ?? 0,
      pop: (json['pop'] ?? 0).toDouble(),
    );
  }
  
  /// 获取天气图标URL
  String getIconUrl() {
    return 'https://openweathermap.org/img/wn/$weatherIcon@2x.png';
  }
  
  /// 获取格式化的时间字符串 (HH:MM)
  String getFormattedTime() {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

/// Location data model (for reverse geocoding)
class LocationData {
  final String name;           // City name
  final String country;        // Country code
  final String state;          // State/province
  final Map<String, String>? localNames; // Names in different languages
  final double latitude;       // Latitude
  final double longitude;      // Longitude
  
  LocationData({
    required this.name,
    required this.country,
    required this.state,
    this.localNames,
    required this.latitude,
    required this.longitude,
  });
  
  /// Create LocationData object from OpenWeather Geocoding API response
  factory LocationData.fromJson(Map<String, dynamic> json) {
    // Process localNames field, convert it to Map<String, String>
    Map<String, String>? localNames;
    if (json['local_names'] != null) {
      localNames = {};
      (json['local_names'] as Map<String, dynamic>).forEach((key, value) {
        if (value is String) {
          localNames![key] = value;
        }
      });
    }
    
    return LocationData(
      name: json['name'] ?? 'Unknown',
      country: json['country'] ?? '',
      state: json['state'] ?? '',
      localNames: localNames,
      latitude: (json['lat'] ?? 0).toDouble(),
      longitude: (json['lon'] ?? 0).toDouble(),
    );
  }
  
  /// Get formatted location string
  String getFormattedLocation() {
    if (state.isNotEmpty) {
      return '$name, $state';
    }
    return '$name, $country';
  }
  
  /// Get local name in specified language (if available)
  String? getLocalName(String languageCode) {
    return localNames?[languageCode];
  }
  
  /// Get Chinese name (if available)
  String? getChineseName() {
    return getLocalName('zh');
  }
  
  /// Convert to LatLng object (for map)
  LatLng toLatLng() {
    return LatLng(latitude, longitude);
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'country': country,
      'state': state,
      'local_names': localNames,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  static LocationData? fromJsonMap(Map<String, dynamic>? json) {
    if (json == null) return null;
    
    return LocationData(
      name: json['name'] ?? 'Unknown',
      country: json['country'] ?? '',
      state: json['state'] ?? '',
      localNames: json['local_names'] != null 
          ? Map<String, String>.from(json['local_names']) 
          : null,
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
    );
  }
}