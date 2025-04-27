import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../utils/config.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:async';
import 'dart:developer';

class SunoApiService {
  final http.Client _client = http.Client();
  final Logger _logger = Logger();
  
  final String baseUrl;
  
  SunoApiService({String? baseUrl}) 
      : baseUrl = baseUrl ?? AppConfig.sunoApiBaseUrl {
    _logger.i('SunoAPI: Initialized, base URL: ${this.baseUrl}');
  }
  
  // Test API connection - direct test of baseUrl
  Future<bool> testConnection() async {
    _logger.i('Testing API connection: $baseUrl');
    
    try {
      // Try the health check endpoint provided by API
      final url = baseUrl.endsWith('/api') 
          ? '$baseUrl/get_limit'  // If baseUrl already contains /api
          : '$baseUrl/api/get_limit';  // If baseUrl doesn't contain /api
          
      _logger.i('Test URL: $url');
      
      final response = await _client.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      _logger.i('API test response: ${response.statusCode}');
      
      // Only return true for 200 status code
      return response.statusCode == 200;
    } catch (e) {
      _logger.e('API connection test failed: $e');
      return false;
    }
  }
  
  // Get API quota information
  Future<dynamic> getApiLimits() async {
    _logger.i('Getting API quota information');
    
    try {
      // Use baseUrl directly, add get_limit without duplicating /api
      final url = baseUrl.endsWith('/api') 
          ? '$baseUrl/get_limit'  // If baseUrl already contains /api
          : '$baseUrl/api/get_limit';  // If baseUrl doesn't contain /api
          
      _logger.i('Get quota URL: $url');
      
      final response = await _client.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: AppConfig.apiRequestTimeoutSeconds));
      
      _logger.i('Quota response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get quota: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Failed to get quota: $e');
      throw e;
    }
  }
  
  // Generate music
  Future<dynamic> generateMusic(String prompt) async {
    _logger.i('Generate music request: $prompt');
    
    try {
      // Build the correct URL, avoid duplicating /api
      final url = baseUrl.endsWith('/api') 
          ? '$baseUrl/generate'  // If baseUrl already contains /api
          : '$baseUrl/api/generate';  // If baseUrl doesn't contain /api
          
      _logger.i('Generate music URL: $url');
      
      final requestBody = {
        'prompt': prompt,
        'wait_audio': true  // Key modification: Set to true, use synchronous mode
      };
      
      _logger.i('Request body: ${json.encode(requestBody)}');
      
      final response = await _client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: AppConfig.generateMusicTimeoutSeconds));
      
      _logger.i('Generation response: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        _logger.e('API error response: ${response.body}');
        throw Exception('Failed to generate music: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Failed to generate music: $e');
      throw e;
    }
  }
  
  // Get music information
  Future<dynamic> getMusicInfo(String id) async {
    _logger.i('Getting music information: ID=$id');
    
    try {
      // Build the correct URL, avoid duplicating /api
      final url = baseUrl.endsWith('/api') 
          ? '$baseUrl/get?ids=$id'  // If baseUrl already contains /api
          : '$baseUrl/api/get?ids=$id';  // If baseUrl doesn't contain /api
          
      _logger.i('Get music info URL: $url');
      
      final response = await _client.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: AppConfig.apiRequestTimeoutSeconds));
      
      _logger.i('Get info response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get music info: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Failed to get music info: $e');
      throw e;
    }
  }
  
  // Add new method to use custom_generate endpoint    
  Future<dynamic> generateCustomMusic({
    required String prompt, 
    String? tags,
    String? title,
    bool makeInstrumental = false,
    bool waitAudio = true  // Default set to true to use synchronous mode
  }) async {
    _logger.i('Generate custom music request:');
    _logger.i('- Prompt: $prompt');
    _logger.i('- Tags: $tags');
    _logger.i('- Title: $title');
    _logger.i('- Make instrumental: $makeInstrumental');
    _logger.i('- Wait audio: $waitAudio');
    
    try {
      // Build the correct URL, avoid duplicating /api
      final url = baseUrl.endsWith('/api') 
          ? '$baseUrl/custom_generate'  // If baseUrl already contains /api
          : '$baseUrl/api/custom_generate';  // If baseUrl doesn't contain /api
          
      _logger.i('Generate custom music URL: $url');
      
      // Build the request body, only include non-empty values
      final Map<String, dynamic> requestBody = {
        'prompt': prompt,
        'wait_audio': waitAudio,
      };
      
      // Add optional parameters (if provided)
      if (tags != null && tags.isNotEmpty) {
        requestBody['tags'] = tags;
      }
      
      if (title != null && title.isNotEmpty) {
        requestBody['title'] = title;
      }
      
      if (makeInstrumental) {
        requestBody['make_instrumental'] = true;
      }
      
      _logger.i('Request body: ${json.encode(requestBody)}');
      
      final response = await _client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: AppConfig.generateMusicTimeoutSeconds));
      
      _logger.i('Custom generation response code: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        var responseData = json.decode(response.body);
        _logger.i('Custom generation successful');
        return responseData;
      } else {
        _logger.e('API error response: ${response.body}');
        throw Exception('Failed to generate custom music: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Failed to generate custom music: $e');
      throw e;
    }
  }
  
  void dispose() {
    _client.close();
  }
} 