import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingService {
  // OpenStreetMap的Nominatim API
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';
  
  // Search for places and return latitude and longitude coordinates
  Future<List<GeocodingResult>> searchPlaces(String query) async {
    if (query.isEmpty) {
      return [];
    }
    
    // Prepare request parameters
    final params = {
      'q': query,
      'format': 'json',
      'limit': '5', // Limit result count
      'addressdetails': '1',
    };
    
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
      
      // Add a suitable user agent header, this is a requirement for the Nominatim API
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
        print('Search for places failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error searching for places: $e');
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