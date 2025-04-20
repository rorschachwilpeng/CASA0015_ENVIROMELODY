import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;
import '../utils/config.dart';
import 'package:path_provider/path_provider.dart';

class StabilityAudioService {
  final http.Client _client = http.Client();
  final Logger _logger = Logger();
  
  final String apiKey;
  final String baseUrl = "https://api.stability.ai";
  final String endpoint = "/v2beta/audio/stable-audio-2/text-to-audio";
  
  StabilityAudioService({required this.apiKey}) {
    _logger.i('StabilityAudioService: Initialized with API key: ${apiKey.substring(0, 5)}...');
  }
  
  // Test API connection
  Future<bool> testConnection() async {
    _logger.i('Testing Stability AI API connection');
    
    try {
      // Simply try to call the API with a basic request that will fail with 400
      // but confirm the service is available
      final response = await _client.get(
        Uri.parse('$baseUrl/v2beta/audio/status'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));
      
      _logger.i('API test response: ${response.statusCode}');
      
      // Consider 400-499 as "API is available but with authentication/request issues"
      // 200-299 would be successful responses
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (e) {
      _logger.e('API connection test failed: $e');
      return false;
    }
  }
  
  // Generate music
  Future<Map<String, dynamic>> generateMusic(
    String prompt, {
    String outputFormat = "mp3",
    int durationSeconds = 60,
    int steps = 30,
    bool saveLocally = true,
  }) async {
    _logger.i('Starting Stability AI music generation');
    _logger.i('Prompt: $prompt');
    _logger.i('Settings: format=$outputFormat, duration=$durationSeconds, steps=$steps');

    try {
      // Calculate estimated credits cost
      final estimatedCost = 0.06 * steps + 9;
      _logger.i('Estimated cost: $estimatedCost credits');
      
      // Prepare request
      final url = Uri.parse('$baseUrl$endpoint');
      
      // Create multipart request
      final request = http.MultipartRequest('POST', url);
      
      // Set headers
      request.headers.addAll({
        'Authorization': 'Bearer $apiKey',
        'Accept': 'audio/*'
      });
      
      // Add form fields
      request.fields['prompt'] = prompt;
      request.fields['output_format'] = outputFormat;
      request.fields['duration'] = durationSeconds.toString();
      request.fields['steps'] = steps.toString();
      
      // Add empty file field (required by API)
      request.files.add(http.MultipartFile.fromString(
        'none', '', filename: 'none'
      ));
      
      _logger.i('Sending request to Stability AI');
      
      // Send request
      final stopwatch = Stopwatch()..start();
      final streamedResponse = await request.send().timeout(
        Duration(seconds: AppConfig.generateMusicTimeoutSeconds),
      );
      final response = await http.Response.fromStream(streamedResponse);
      stopwatch.stop();
      
      _logger.i('Received response in ${stopwatch.elapsed.inSeconds} seconds');
      _logger.i('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        _logger.i('Audio generation successful!');
        _logger.i('Content-Type: ${response.headers['content-type']}');
        _logger.i('Received ${response.bodyBytes.length} bytes of data');
        
        // Generate a unique filename
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filename = 'stability_audio_$timestamp.$outputFormat';
        String? localPath;
        
        // Save to local file if requested
        if (saveLocally) {
          localPath = await _saveAudioToFile(response.bodyBytes, filename);
          _logger.i('Saved audio to: $localPath');
        }
        
        // Create response object with metadata
        final result = {
          'id': 'stability_$timestamp',
          'title': _extractTitleFromPrompt(prompt),
          'prompt': prompt,
          'audio_url': localPath ?? '',
          'status': 'complete',
          'created_at': DateTime.now().toIso8601String(),
          'credits_used': estimatedCost
        };
        
        return result;
      } else {
        // Try to parse error response
        String errorMessage = 'Status code: ${response.statusCode}';
        try {
          final errorResponse = json.decode(response.body);
          errorMessage = errorResponse['message'] ?? errorMessage;
          _logger.e('API error: $errorMessage');
          _logger.e('Full error response: ${response.body}');
        } catch (_) {
          _logger.e('Error response not in JSON format: ${response.body}');
        }
        
        throw Exception('Failed to generate audio: $errorMessage');
      }
    } catch (e) {
      _logger.e('Error generating music: $e');
      throw e; // Re-throw for proper handling in UI
    }
  }
  
  // Helper to save audio file locally
  Future<String> _saveAudioToFile(Uint8List bytes, String filename) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${directory.path}/audio');
      
      // Create directory if it doesn't exist
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }
      
      final filePath = '${audioDir.path}/$filename';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      return filePath;
    } catch (e) {
      _logger.e('Error saving audio file: $e');
      throw e;
    }
  }
  
  // Helper to extract title from prompt
  String _extractTitleFromPrompt(String prompt) {
    // Take first sentence or first 30 chars
    final firstLine = prompt.split('\n').first.trim();
    if (firstLine.length <= 40) {
      return firstLine;
    }
    
    // If first line is too long, use first 30 chars
    return '${prompt.substring(0, min(30, prompt.length))}...';
  }
  
  // Helper function for min
  int min(int a, int b) => a < b ? a : b;
  
  void dispose() {
    _client.close();
  }
} 