import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingService {
  // OpenStreetMap的Nominatim API
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';
  
  // 搜索地点并返回经纬度坐标
  Future<List<GeocodingResult>> searchPlaces(String query) async {
    if (query.isEmpty) {
      return [];
    }
    
    // 准备请求参数
    final params = {
      'q': query,
      'format': 'json',
      'limit': '5', // 限制结果数量
      'addressdetails': '1',
    };
    
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
      
      // 添加合适的用户代理头部，这是Nominatim API的要求
      final response = await http.get(uri, headers: {
        'User-Agent': 'SoundscapeApp/1.0',
      });
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        return data.map((item) => GeocodingResult(
          name: item['display_name'],
          latitude: double.parse(item['lat']),
          longitude: double.parse(item['lon']),
          type: item['type'],
          address: item['address'] != null ? 
            Address.fromJson(item['address']) : null,
        )).toList();
      } else {
        print('搜索地点失败: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('搜索地点时出错: $e');
      return [];
    }
  }
}

class GeocodingResult {
  final String name;
  final double latitude;
  final double longitude;
  final String? type;
  final Address? address;
  
  GeocodingResult({
    required this.name, 
    required this.latitude, 
    required this.longitude, 
    this.type,
    this.address,
  });
  
  LatLng get latLng => LatLng(latitude, longitude);
  
  @override
  String toString() => name;
}

class Address {
  final String? road;
  final String? city;
  final String? state;
  final String? country;
  
  Address({
    this.road,
    this.city,
    this.state,
    this.country,
  });
  
  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      road: json['road'],
      city: json['city'] ?? json['town'] ?? json['village'],
      state: json['state'],
      country: json['country'],
    );
  }
  
  @override
  String toString() {
    final parts = <String>[];
    if (road != null) parts.add(road!);
    if (city != null) parts.add(city!);
    if (state != null) parts.add(state!);
    if (country != null) parts.add(country!);
    
    return parts.join(', ');
  }
} 