import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class DeepSeekApiService {
  final http.Client _client = http.Client();
  final Logger _logger = Logger();
  
  final String apiKey;
  final String baseUrl;
  
  DeepSeekApiService({
    required this.apiKey,
    this.baseUrl = "https://api.deepseek.com/v1/chat/completions",
  }) {
    _logger.i('DeepSeekApiService: Initialization complete');
  }
  
  // Test API connection
  Future<bool> testConnection() async {
    _logger.i('Testing DeepSeek API connection');
    
    try {
      // Send a simple test request
      final response = await _client.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'model': 'deepseek-chat',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a helpful assistant.'
            },
            {
              'role': 'user',
              'content': 'Hello'
            }
          ],
          'max_tokens': 50
        }),
      ).timeout(const Duration(seconds: 10));
      
      _logger.i('API test response: ${response.statusCode}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = json.decode(response.body);
        final content = responseData['choices'][0]['message']['content'];
        _logger.i('Response content: $content');
        return true;
      } else {
        _logger.e('API error: ${response.statusCode}');
        _logger.e('Error content: ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.e('API connection test failed: $e');
      return false;
    }
  }
  
  // Simple chat completion method
  Future<String?> simpleChatCompletion(String prompt) async {
    try {
      final response = await _client.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'model': 'deepseek-chat',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a helpful assistant.'
            },
            {
              'role': 'user',
              'content': prompt
            }
          ],
          'max_tokens': 300,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = json.decode(response.body);
        return responseData['choices'][0]['message']['content'];
      } else {
        _logger.e('Chat completion error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.e('Chat completion failed: $e');
      return null;
    }
  }
  
  // Generate music prompt
  Future<String> generateMusicPrompt({
    required String weatherDescription,
    required double temperature,
    required int humidity,
    required double windSpeed,
    String? cityName,
    String? vibeName,
    String? genreName,
    String? sceneName,
  }) async {
    _logger.i('Starting to generate music prompt');
    _logger.i('Weather: $weatherDescription, Temperature: $temperature°C, Humidity: $humidity%, Wind Speed: $windSpeed m/s');
    _logger.i('City: ${cityName ?? "Unknown"}, Vibe: ${vibeName ?? "Not selected"}, Genre: ${genreName ?? "Not selected"}, Scene: ${sceneName ?? "Not selected"}');
    
    try {
      // Build system prompt
      final systemPrompt = '''
You are a professional music prompt engineer, skilled at transforming environmental data and music preferences into high-quality music generation prompts.
Your task is to create a detailed, creative, and expressive prompt for generating music based on weather data and user preferences.

You should consider the following factors:
1. How weather conditions (temperature, humidity, wind speed, weather description) affect music mood and atmosphere
2. User's selected music vibe and genre
3. Location information (if provided)
4. The specific music usage scenario/scene (if provided) - tailor the music to be perfect for this scenario

Ensure your prompt is:
- Specific and vivid
- Includes appropriate music terminology (rhythm, melody, harmony, etc.)
- Moderate length (about 100-150 words)
- Stylistically consistent
- Suitable for AI music generation systems
- Optimized for the specified scenario (e.g., meditation music should be calming, focus music should minimize distractions)

The output format should be a coherent paragraph without titles or sections. Don't explain your creative process, just provide the final prompt text.
''';

      // Build user prompt
      String userPrompt = '''
Please create a prompt for music generation based on the following information:

Weather condition: $weatherDescription
Temperature: ${temperature.toStringAsFixed(1)}°C
Humidity: $humidity%
Wind speed: $windSpeed m/s
''';

      if (cityName != null && cityName.isNotEmpty) {
        userPrompt += 'Location: $cityName\n';
      }
      
      if (vibeName != null && vibeName.isNotEmpty) {
        userPrompt += 'Music vibe: $vibeName\n';
      }
      
      if (genreName != null && genreName.isNotEmpty) {
        userPrompt += 'Music genre: $genreName\n';
      }

      if (sceneName != null && sceneName.isNotEmpty) {
        userPrompt += 'Music usage scenario: $sceneName\n';
        
        switch(sceneName.toLowerCase()) {
          case 'meditation':
            userPrompt += 'Note: This music will be used for meditation sessions. Create a peaceful, calming composition that helps with mindfulness and relaxation.\n';
            break;
          case 'deep work':
            userPrompt += 'Note: This music will be used for focused deep work. Create a non-distracting composition that enhances concentration without being intrusive.\n';
            break;
          case 'relaxation':
            userPrompt += 'Note: This music will be used for relaxation. Create a gentle, soothing composition that helps relieve stress and anxiety.\n';
            break;
          case 'sleep':
            userPrompt += 'Note: This music will be used for aiding sleep. Create a very gentle, slow-paced composition with minimal dynamics and gradual transitions.\n';
            break;
          case 'exercise':
            userPrompt += 'Note: This music will be used during exercise. Create an energetic, rhythmic composition that maintains motivation and energy levels.\n';
            break;
          case 'study':
            userPrompt += 'Note: This music will be used for studying. Create a balanced composition that maintains alertness while not distracting from cognitive tasks.\n';
            break;
          case 'creativity':
            userPrompt += 'Note: This music will be used to enhance creativity. Create an inspiring composition that evokes imagination and creative thinking.\n';
            break;
        }
      }
      
      userPrompt += '\nPlease create a concise and powerful music generation prompt, output the final text directly without any explanation or formatting.';

      // Send request
      final response = await _client.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'model': 'deepseek-chat',
          'messages': [
            {
              'role': 'system',
              'content': systemPrompt
            },
            {
              'role': 'user',
              'content': userPrompt
            }
          ],
          'max_tokens': 300,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = json.decode(response.body);
        final generatedPrompt = responseData['choices'][0]['message']['content'];
        _logger.i('Successfully generated music prompt');
        _logger.i('Generated prompt: $generatedPrompt');
        return generatedPrompt;
      } else {
        _logger.e('Music prompt generation error: ${response.statusCode}');
        _logger.e('Error content: ${response.body}');
        
        // Return fallback prompt
        return _generateFallbackPrompt(
          weatherDescription: weatherDescription,
          temperature: temperature,
          vibeName: vibeName,
          genreName: genreName,
          cityName: cityName,
          sceneName: sceneName,
        );
      }
    } catch (e) {
      _logger.e('Music prompt generation failed: $e');
      
      // Return fallback prompt
      return _generateFallbackPrompt(
        weatherDescription: weatherDescription,
        temperature: temperature,
        vibeName: vibeName,
        genreName: genreName,
        cityName: cityName,
        sceneName: sceneName,
      );
    }
  }

  // 增强的 fallback 提示生成方法
  String _generateFallbackPrompt({
    required String weatherDescription,
    required double temperature,
    String? vibeName,
    String? genreName,
    String? cityName,
    String? sceneName,
  }) {
    _logger.i('Using fallback method to generate music prompt');
    
    String mood = 'calm';
    // 根据天气描述推断情绪
    if (weatherDescription.contains('雨') || weatherDescription.contains('rain')) {
      mood = 'melancholic';
    } else if (weatherDescription.contains('晴') || weatherDescription.contains('clear')) {
      mood = 'bright';
    } else if (weatherDescription.contains('云') || weatherDescription.contains('cloud')) {
      mood = 'contemplative';
    } else if (weatherDescription.contains('雪') || weatherDescription.contains('snow')) {
      mood = 'dreamy';
    } else if (weatherDescription.contains('雾') || weatherDescription.contains('fog') || weatherDescription.contains('mist')) {
      mood = 'mystical';
    } else if (weatherDescription.contains('风') || weatherDescription.contains('wind')) {
      mood = 'dynamic';
    }
    
    // 根据温度调整情绪
    String tempMood = '';
    if (temperature < 0) {
      tempMood = 'cold and stark';
    } else if (temperature < 10) {
      tempMood = 'cool and refreshing';
    } else if (temperature < 20) {
      tempMood = 'mild and pleasant';
    } else if (temperature < 30) {
      tempMood = 'warm and relaxing';
    } else {
      tempMood = 'hot and intense';
    }
    
    String prompt = 'Create a $mood, $tempMood piece of music, ';
    
    if (vibeName != null && vibeName.isNotEmpty) {
      prompt += 'with a $vibeName atmosphere, ';
    }
    
    if (genreName != null && genreName.isNotEmpty) {
      prompt += 'in the style of $genreName, ';
    }
    
    if (sceneName != null && sceneName.isNotEmpty) {
      String sceneDescription = '';
      
      switch(sceneName.toLowerCase()) {
        case 'meditation':
          sceneDescription = 'suitable for meditation and mindfulness practices';
          break;
        case 'deep work':
          sceneDescription = 'perfect for focused deep work and concentration';
          break;
        case 'relaxation':
          sceneDescription = 'ideal for relaxation and unwinding';
          break;
        case 'sleep':
          sceneDescription = 'gentle enough to aid falling asleep and maintaining sleep';
          break;
        case 'exercise':
          sceneDescription = 'energetic and motivating for physical activities';
          break;
        case 'study':
          sceneDescription = 'balanced for studying and learning';
          break;
        case 'creativity':
          sceneDescription = 'inspiring for creative thinking and artistic activities';
          break;
        default:
          sceneDescription = 'suitable for $sceneName';
      }
      
      prompt += 'that is $sceneDescription, ';
    }
    
    prompt += 'inspired by the $weatherDescription weather in ${cityName ?? "the city"}, with a temperature of ${temperature.toStringAsFixed(1)}°C. ';
    prompt += 'The music should reflect the feelings and emotions evoked by this weather';
    
    if (sceneName != null && sceneName.isNotEmpty) {
      prompt += ' while being perfectly suited for ${sceneName.toLowerCase()}';
    }
    
    prompt += '.';
    
    _logger.i('Fallback prompt: $prompt');
    return prompt;
  }
  
  void dispose() {
    _client.close();
  }
} 